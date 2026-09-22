#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# setup.sh 단위 테스트. 모델을 부르지 않는다.
# core.hooksPath 는 값을 하나만 가진다. 덮어쓰면 앞의 것이 사라지고, 그 저장소가 쓰던
# 훅이 조용히 죽는다. husky·lefthook 을 쓰는 저장소에서 실제로 그렇게 됐다(V55).
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
unset NGG_STATE NGG_INNER NGG_JUDGE NGG_PROFILE
export NGG_LANG=ko
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }

# 훅 폴더와 setup.sh 를 갖춘 새 git 저장소를 만든다.
mkrepo() {
  local d="$1" hooks="${2:-.githooks}"
  mkdir -p "$d"; git init -q "$d"
  git -C "$d" config user.name t; git -C "$d" config user.email t@example.invalid
  mkdir -p "$d/$hooks"; printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$d/$hooks/pre-commit"
  chmod +x "$d/$hooks/pre-commit"
  cp "$ROOT/plugin/skills/repo-privacy/templates/setup.sh" "$d/setup.sh"; chmod +x "$d/setup.sh"
}

# 1. 기준선: 설정이 비어 있으면 건다
R1="$T/fresh"; mkrepo "$R1"
out=$(cd "$R1" && ./setup.sh 2>&1); check 0 $? "빈 설정 → exit 0"
check ".githooks" "$(git -C "$R1" config core.hooksPath)" "빈 설정 → hooksPath 를 건다"

# 2. 멱등: 같은 값이 이미 있으면 그대로 통과한다
out=$(cd "$R1" && ./setup.sh 2>&1); check 0 $? "같은 값 → exit 0 (멱등)"
check ".githooks" "$(git -C "$R1" config core.hooksPath)" "같은 값 → 그대로 둔다"

# 3. 남의 값이 있으면 덮지 않고 멈춘다. 이게 이 파일의 존재 이유다.
R2="$T/taken"; mkrepo "$R2"
git -C "$R2" config core.hooksPath .husky/_
out=$(cd "$R2" && ./setup.sh 2>&1); r=$?
check 1 "$r" "남의 hooksPath → exit 1 (조용히 덮지 않는다)"
check ".husky/_" "$(git -C "$R2" config core.hooksPath)" "남의 hooksPath → 값을 건드리지 않는다"
printf '%s' "$out" | grep -q '.husky/_'; check 0 $? "차단 메시지에 기존 값을 보인다"
printf '%s' "$out" | grep -q 'pre-commit'; check 0 $? "차단 메시지에 공존하는 법을 보인다"
printf '%s' "$out" | grep -q '\-\-force'; check 0 $? "차단 메시지에 덮어쓰는 법을 보인다"

# 4. --force 는 사람이 의도해서 줄 때만 덮는다
out=$(cd "$R2" && ./setup.sh --force 2>&1); check 0 $? "--force → exit 0"
check ".githooks" "$(git -C "$R2" config core.hooksPath)" "--force → 덮는다"

# 5. 훅 폴더가 없으면 멈춘다
R3="$T/nohooks"; mkdir -p "$R3"; git init -q "$R3"
cp "$ROOT/plugin/skills/repo-privacy/templates/setup.sh" "$R3/setup.sh"; chmod +x "$R3/setup.sh"
out=$(cd "$R3" && ./setup.sh 2>&1); r=$?; check 1 "$r" "훅 폴더 없음 → exit 1"

# 6. git 저장소가 아니면 멈춘다
R4="$T/notgit"; mkdir -p "$R4"; cp "$ROOT/plugin/skills/repo-privacy/templates/setup.sh" "$R4/setup.sh"; chmod +x "$R4/setup.sh"
out=$(cd "$R4" && ./setup.sh 2>&1); r=$?; check 1 "$r" "git 저장소 아님 → exit 1"

# 7. 모르는 인자는 조용히 무시하지 않는다
R5="$T/badarg"; mkrepo "$R5"
out=$(cd "$R5" && ./setup.sh --nope 2>&1); r=$?; check 1 "$r" "모르는 인자 → exit 1"

# 8. .git/hooks 에 놓인 훅도 덮지 않는다. core.hooksPath 가 비어 있으면 git 은 그 자리를 보는데,
#    core.hooksPath 를 걸면 더는 보지 않으므로 거기 있던 훅이 조용히 죽는다.
R6="$T/legacy"; mkrepo "$R6"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$R6/.git/hooks/pre-commit"; chmod +x "$R6/.git/hooks/pre-commit"
out=$(cd "$R6" && ./setup.sh 2>&1); r=$?
check 1 "$r" ".git/hooks 에 훅이 있음 → exit 1 (조용히 끄지 않는다)"
check "" "$(git -C "$R6" config core.hooksPath)" ".git/hooks 에 훅이 있음 → hooksPath 를 걸지 않는다"
printf '%s' "$out" | grep -q '\.git/hooks.*pre-commit'; check 0 $? "차단 메시지에 찾은 훅을 보인다"
printf '%s' "$out" | grep -q 'githooks/pre-commit || exit 1'; check 0 $? "차단 메시지에 공존하는 법을 보인다"
printf '%s' "$out" | grep -q '\-\-force'; check 0 $? "차단 메시지에 덮어쓰는 법을 보인다"
R7="$T/legacy-noexec"; mkrepo "$R7"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$R7/.git/hooks/pre-commit"; chmod -x "$R7/.git/hooks/pre-commit"
(cd "$R7" && ./setup.sh >/dev/null 2>&1); check 0 $? "실행 비트 없는 .git/hooks 훅 → exit 0 (git 도 돌리지 않는다)"
out=$(cd "$R6" && ./setup.sh --force 2>&1); check 0 $? ".git/hooks 훅 + --force → exit 0"
check ".githooks" "$(git -C "$R6" config core.hooksPath)" ".git/hooks 훅 + --force → 건다"
printf '%s' "$out" | grep -q '돌지 않는다'; check 0 $? "--force 뒤에 돌지 않게 된 훅을 알린다"
out=$(cd "$R6" && ./setup.sh 2>&1); check 0 $? "이미 .githooks 이고 .git/hooks 에 훅 → exit 0 (멱등)"
printf '%s' "$out" | grep -q '돌지 않는다'; check 0 $? "이미 덮인 저장소에서 돌지 않는 훅을 알린다"
R8="$T/wt-main"; mkrepo "$R8"
git -C "$R8" add -A; git -C "$R8" -c commit.gpgsign=false commit -q -m init
git -C "$R8" worktree add -q "$T/wt-side" 2>/dev/null
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$R8/.git/hooks/pre-commit"; chmod +x "$R8/.git/hooks/pre-commit"
# cd 가 실패해도 1 이 나오므로 종료 코드만으로는 모자란다. 차단 문구까지 본다.
out=$(cd "$T/wt-side" && ./setup.sh 2>&1); r=$?
check "1 1" "$r $(printf '%s' "$out" | grep -c '이미 훅이 있다')" "링크된 워크트리 → 공통 폴더의 훅을 찾아 exit 1"

echo; echo "실패 ${fail}건"; exit "$fail"
