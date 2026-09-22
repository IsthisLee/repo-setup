#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# script/setup 단위 테스트. 모델을 부르지 않는다.
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

# 훅 폴더와 script/setup 을 갖춘 새 git 저장소를 만든다.
mkrepo() {
  local d="$1" hooks="${2:-.githooks}"
  mkdir -p "$d"; git init -q "$d"
  git -C "$d" config user.name t; git -C "$d" config user.email t@example.invalid
  mkdir -p "$d/$hooks"; printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$d/$hooks/pre-commit"
  chmod +x "$d/$hooks/pre-commit"
  mkdir -p "$d/script"; cp "$ROOT/plugin/skills/repo-setup/privacy/templates/setup" "$d/script/setup"; chmod +x "$d/script/setup"
}

# 1. 기준선: 설정이 비어 있으면 건다
R1="$T/fresh"; mkrepo "$R1"
out=$(cd "$R1" && script/setup 2>&1); check 0 $? "빈 설정 → exit 0"
check ".githooks" "$(git -C "$R1" config core.hooksPath)" "빈 설정 → hooksPath 를 건다"

# 2. 멱등: 같은 값이 이미 있으면 그대로 통과한다
out=$(cd "$R1" && script/setup 2>&1); check 0 $? "같은 값 → exit 0 (멱등)"
check ".githooks" "$(git -C "$R1" config core.hooksPath)" "같은 값 → 그대로 둔다"

# 3. 남의 값이 있으면 덮지 않고 멈춘다. 이게 이 파일의 존재 이유다.
R2="$T/taken"; mkrepo "$R2"
git -C "$R2" config core.hooksPath .husky/_
out=$(cd "$R2" && script/setup 2>&1); r=$?
check 1 "$r" "남의 hooksPath → exit 1 (조용히 덮지 않는다)"
check ".husky/_" "$(git -C "$R2" config core.hooksPath)" "남의 hooksPath → 값을 건드리지 않는다"
printf '%s' "$out" | grep -q '.husky/_'; check 0 $? "차단 메시지에 기존 값을 보인다"
printf '%s' "$out" | grep -q 'pre-commit'; check 0 $? "차단 메시지에 공존하는 법을 보인다"
printf '%s' "$out" | grep -q '\-\-force'; check 0 $? "차단 메시지에 덮어쓰는 법을 보인다"

# 4. --force 는 사람이 의도해서 줄 때만 덮는다
out=$(cd "$R2" && script/setup --force 2>&1); check 0 $? "--force → exit 0"
check ".githooks" "$(git -C "$R2" config core.hooksPath)" "--force → 덮는다"

# 5. 훅 폴더가 없으면 멈춘다
R3="$T/nohooks"; mkdir -p "$R3"; git init -q "$R3"
mkdir -p "$R3/script"; cp "$ROOT/plugin/skills/repo-setup/privacy/templates/setup" "$R3/script/setup"; chmod +x "$R3/script/setup"
out=$(cd "$R3" && script/setup 2>&1); r=$?; check 1 "$r" "훅 폴더 없음 → exit 1"

# 6. git 저장소가 아니면 멈춘다
R4="$T/notgit"; mkdir -p "$R4"; mkdir -p "$R4/script"; cp "$ROOT/plugin/skills/repo-setup/privacy/templates/setup" "$R4/script/setup"; chmod +x "$R4/script/setup"
out=$(cd "$R4" && script/setup 2>&1); r=$?; check 1 "$r" "git 저장소 아님 → exit 1"

# 7. 모르는 인자는 조용히 무시하지 않는다
R5="$T/badarg"; mkrepo "$R5"
out=$(cd "$R5" && script/setup --nope 2>&1); r=$?; check 1 "$r" "모르는 인자 → exit 1"

# 8. .git/hooks 에 놓인 훅도 덮지 않는다. core.hooksPath 가 비어 있으면 git 은 그 자리를 보는데,
#    core.hooksPath 를 걸면 더는 보지 않으므로 거기 있던 훅이 조용히 죽는다.
R6="$T/legacy"; mkrepo "$R6"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$R6/.git/hooks/pre-commit"; chmod +x "$R6/.git/hooks/pre-commit"
out=$(cd "$R6" && script/setup 2>&1); r=$?
check 1 "$r" ".git/hooks 에 훅이 있음 → exit 1 (조용히 끄지 않는다)"
check "" "$(git -C "$R6" config core.hooksPath)" ".git/hooks 에 훅이 있음 → hooksPath 를 걸지 않는다"
printf '%s' "$out" | grep -q '\.git/hooks.*pre-commit'; check 0 $? "차단 메시지에 찾은 훅을 보인다"
printf '%s' "$out" | grep -q 'githooks/pre-commit || exit 1'; check 0 $? "차단 메시지에 공존하는 법을 보인다"
printf '%s' "$out" | grep -q '\-\-force'; check 0 $? "차단 메시지에 덮어쓰는 법을 보인다"
R7="$T/legacy-noexec"; mkrepo "$R7"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$R7/.git/hooks/pre-commit"; chmod -x "$R7/.git/hooks/pre-commit"
(cd "$R7" && script/setup >/dev/null 2>&1); check 0 $? "실행 비트 없는 .git/hooks 훅 → exit 0 (git 도 돌리지 않는다)"
out=$(cd "$R6" && script/setup --force 2>&1); check 0 $? ".git/hooks 훅 + --force → exit 0"
check ".githooks" "$(git -C "$R6" config core.hooksPath)" ".git/hooks 훅 + --force → 건다"
printf '%s' "$out" | grep -q '돌지 않는다'; check 0 $? "--force 뒤에 돌지 않게 된 훅을 알린다"
out=$(cd "$R6" && script/setup 2>&1); check 0 $? "이미 .githooks 이고 .git/hooks 에 훅 → exit 0 (멱등)"
printf '%s' "$out" | grep -q '돌지 않는다'; check 0 $? "이미 덮인 저장소에서 돌지 않는 훅을 알린다"
R8="$T/wt-main"; mkrepo "$R8"
git -C "$R8" add -A; git -C "$R8" -c commit.gpgsign=false commit -q -m init
git -C "$R8" worktree add -q "$T/wt-side" 2>/dev/null
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$R8/.git/hooks/pre-commit"; chmod +x "$R8/.git/hooks/pre-commit"
# cd 가 실패해도 1 이 나오므로 종료 코드만으로는 모자란다. 차단 문구까지 본다.
out=$(cd "$T/wt-side" && script/setup 2>&1); r=$?
check "1 1" "$r $(printf '%s' "$out" | grep -c '이미 훅이 있다')" "링크된 워크트리 → 공통 폴더의 훅을 찾아 exit 1"

# 9. --verify 는 커밋을 만들지 않고 가드가 실제로 막는지 증명한다. 임시 인덱스에 탐침만 올려
#    git 이 부를 pre-commit 을 돌리므로, 사용자의 인덱스·작업 트리·히스토리는 그대로다.
mkguard() {
  mkrepo "$1"; cp "$ROOT/plugin/skills/repo-setup/privacy/templates/pre-commit" "$1/.githooks/pre-commit"
  git -C "$1" config core.hooksPath .githooks
}
verify() { (cd "$1" && env GIT_GUARD_PATTERNS=/nonexistent HOME=/nonexistent script/setup --verify 2>&1); }
state() { printf '%s|' "$(git -C "$1" rev-parse -q --verify HEAD)" "$(git -C "$1" rev-list --all --count)" \
  "$(git -C "$1" diff --cached --name-only)" "$(git -C "$1" status --porcelain)" "$(git -C "$1" config core.hooksPath)"; }
# 이 파일 자신이 가드에 걸리지 않도록 홈 경로를 실행 시점에 조립한다.
hp="/Users""/someone/x"
V1="$T/verify-on"; mkguard "$V1"
git -C "$V1" add -A; git -C "$V1" -c commit.gpgsign=false commit -q --no-verify -m init
printf '%s\n' "see $hp" > "$V1/staged.txt"; git -C "$V1" add staged.txt
printf '%s\n' 'wip' > "$V1/unstaged.txt"
before=$(state "$V1"); out=$(verify "$V1"); r=$?; after=$(state "$V1")
check 0 "$r" "가드가 걸린 저장소 → --verify exit 0"
check "$before" "$after" "--verify 뒤에 HEAD·커밋 수·인덱스·작업 트리·설정이 그대로다"
printf '%s' "$out" | grep -q 'staged.txt'; check 1 $? "--verify 출력에 사용자가 스테이징한 파일이 나오지 않는다"
V2="$T/verify-unborn"; mkguard "$V2"
verify "$V2" >/dev/null; check 0 $? "태어나지 않은 브랜치 → --verify exit 0"
V3="$T/verify-fake"; mkrepo "$V3"; git -C "$V3" config core.hooksPath .githooks
out=$(verify "$V3"); r=$?
check "1 1" "$r $(printf '%s' "$out" | grep -c '막지 않았다')" "아무것도 막지 않는 훅 → --verify exit 1"
V4="$T/verify-other"; mkrepo "$V4"; git -C "$V4" config core.hooksPath .githooks
printf '%s\n' '#!/usr/bin/env bash' 'echo "lint failed"' 'exit 1' > "$V4/.githooks/pre-commit"
out=$(verify "$V4"); r=$?
check "1 1" "$r $(printf '%s' "$out" | grep -c '가드가 막은 것이 아니다')" "다른 이유로 실패하는 훅 → --verify exit 1"
V5="$T/verify-off"; mkguard "$V5"; git -C "$V5" config --unset core.hooksPath
out=$(verify "$V5"); r=$?
check "1 1" "$r $(printf '%s' "$out" | grep -c 'pre-commit 이 없거나')" "git 이 부를 훅이 없음 → --verify exit 1"
check "" "$(git -C "$V5" config core.hooksPath)" "--verify 는 core.hooksPath 를 걸지 않는다"
V6="$T/verify-badpat"; mkguard "$V6"; mkdir -p "$V6/.private"
printf '%s\n' 'secret-value(' > "$V6/.private/guard-patterns"
out=$(verify "$V6"); r=$?
check "1 1" "$r $(printf '%s' "$out" | grep -c '읽지 못하는 줄')" "잘못된 패턴 줄 → --verify exit 1"
printf '%s' "$out" | grep -q 'secret-value'; check 1 $? "--verify 출력에 패턴 값이 나오지 않는다"
V7="$T/verify-coexist"; mkguard "$V7"; git -C "$V7" config core.hooksPath .husky/_
mkdir -p "$V7/.husky/_"
printf '%s\n' '#!/usr/bin/env bash' "\"\$(git rev-parse --show-toplevel)\"/.githooks/pre-commit || exit 1" > "$V7/.husky/_/pre-commit"
chmod +x "$V7/.husky/_/pre-commit"
verify "$V7" >/dev/null; check 0 $? "공존: 다른 관리자의 훅이 가드를 부름 → --verify exit 0"

echo; echo "실패 ${fail}건"; exit "$fail"
