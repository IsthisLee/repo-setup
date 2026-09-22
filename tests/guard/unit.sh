#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# .githooks/pre-commit 단위 테스트. 모델을 부르지 않는다.
# 패턴 출처가 셋이다. 팀 공용(커밋됨) · 개인 공용(기계마다) · 저장소별(커밋 안 됨).
# 팀 공용은 커밋되므로 팀원 전부에게 적용된다. 대신 그 파일 자신이 막으려는 문자열을
# 품고 있어서, 내용 검사에서 빼지 않으면 자기 자신을 커밋하지 못한다.
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
unset NGG_STATE NGG_INNER NGG_JUDGE NGG_PROFILE GIT_GUARD_PATTERNS
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }

mkrepo() {
  local d="$1"
  mkdir -p "$d"; git init -q "$d"
  git -C "$d" config user.name t; git -C "$d" config user.email t@example.invalid
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/.githooks"; cp "$ROOT/plugin/skills/repo-privacy/templates/pre-commit" "$d/.githooks/"
  chmod +x "$d/.githooks/pre-commit"
  git -C "$d" config core.hooksPath .githooks
  printf '%s\n' '.private/' > "$d/.gitignore"
}

# try <저장소> <파일> <내용> → 커밋되면 ok, 막히면 block
try() {
  local d="$1" f="$2" body="$3"
  mkdir -p "$(dirname "$d/$f")"; printf '%s\n' "$body" > "$d/$f"
  git -C "$d" add -f "$f" >/dev/null 2>&1
  if (cd "$d" && env GIT_GUARD_PATTERNS=/nonexistent HOME=/nonexistent git commit -q -m t >/dev/null 2>&1); then echo ok; else echo block; fi
  git -C "$d" reset -q HEAD -- "$f" 2>/dev/null || true; rm -f "$d/$f"
}

R="$T/repo"; mkrepo "$R"

# 1. 기준선
check ok    "$(try "$R" a.txt 'hello world')"           "평범한 파일 → 통과"
# 이 파일 자신이 가드에 걸리지 않도록 홈 경로를 실행 시점에 조립한다. 소스에 통째로 적으면
# 이 저장소의 pre-commit 이 테스트 파일을 막는다. 검사 대상 문자열은 조립 뒤 동일하다.
home_probe="/Users""/someone/x"
check block "$(try "$R" b.txt "see $home_probe")"       "홈 경로 → 차단"
check block "$(try "$R" .private/x.md 'clean')"          ".private/ 경로 → 차단"

# 2. 팀 패턴 파일이 없을 때는 아무 영향이 없다
check ok    "$(try "$R" c.txt 'corp.internal')"          "팀 패턴 없음 → 사내 도메인도 통과"

# 3. 팀 패턴 파일을 두면 팀원 전부에게 적용된다. 커밋되는 파일이라 전달된다.
printf '%s\n' '# 팀 공용 패턴' 'corp\.internal' 'acme-client' > "$R/.githooks/team-patterns"
check block "$(try "$R" d.txt 'host is corp.internal')"  "팀 패턴 → 사내 도메인 차단"
check block "$(try "$R" e.txt 'for acme-client')"        "팀 패턴 → 고객사 이름 차단"
check ok    "$(try "$R" f.txt 'nothing sensitive')"      "팀 패턴에 없는 값 → 통과"

# 4. 팀 패턴 파일 자신은 커밋할 수 있어야 한다. 아니면 팀에 전달할 방법이 없다.
git -C "$R" add -f .githooks/team-patterns >/dev/null 2>&1
if (cd "$R" && env GIT_GUARD_PATTERNS=/nonexistent HOME=/nonexistent git commit -q -m team >/dev/null 2>&1); then r=ok; else r=block; fi
check ok "$r" "팀 패턴 파일 자신은 커밋된다(자기 차단 없음)"

# 5. 주석과 빈 줄은 패턴으로 읽지 않는다
printf '%s\n' '# corp-comment-only' '' 'zzz-real' > "$R/.githooks/team-patterns"
check ok    "$(try "$R" g.txt 'corp-comment-only')"      "주석 줄은 패턴이 아니다"
check block "$(try "$R" h.txt 'zzz-real')"               "주석 아래 실제 패턴은 적용된다"

# 6. 개인 공용 파일과 팀 파일이 함께 적용된다
P="$T/personal"; printf '%s\n' 'my-private-thing' > "$P"
printf '%s\n' 'team-thing' > "$R/.githooks/team-patterns"
t1() { local f="$1" body="$2"
  printf '%s\n' "$body" > "$R/$f"; git -C "$R" add -f "$f" >/dev/null 2>&1
  if (cd "$R" && env GIT_GUARD_PATTERNS="$P" HOME=/nonexistent git commit -q -m t >/dev/null 2>&1); then echo ok; else echo block; fi
  git -C "$R" reset -q HEAD -- "$f" 2>/dev/null || true; rm -f "$R/$f"; }
check block "$(t1 i.txt 'team-thing')"                   "둘 다 있을 때 팀 패턴 적용"
check block "$(t1 j.txt 'my-private-thing')"             "둘 다 있을 때 개인 패턴 적용"

# 7. 이름이 어떻게 생겼든, 작업 트리에 남아 있든 말든 스테이징된 내용을 검사한다.
#    이름을 단어로 쪼개거나 작업 트리에서 파일을 찾으면 한글·공백 이름과 지운 파일이 빠져나간다.
N="$T/names"; mkrepo "$N"; git -C "$N" commit -q --allow-empty -m base
check block "$(try "$N" '한글.txt' "see $home_probe")"          "한글 파일명 → 차단"
check block "$(try "$N" 'my file.txt' "see $home_probe")"       "공백이 든 파일명 → 차단"
check block "$(try "$N" "$(printf 'a\nb.txt')" "see $home_probe")" "줄바꿈이 든 파일명 → 차단"
check block "$(try "$N" '.private/회의록.md' 'clean')"          ".private/ 아래 한글 파일명 → 차단"
check ok    "$(try "$N" '깨끗한 메모.txt' 'hello')"             "깨끗한 한글·공백 파일명 → 통과(읽지 못해 막은 것이 아니다)"
commit_n() { if (cd "$N" && env GIT_GUARD_PATTERNS=/nonexistent HOME=/nonexistent git commit -q -m t >/dev/null 2>&1); then echo ok; else echo block; fi; }
printf '%s\n' "see $home_probe" > "$N/gone.txt"; git -C "$N" add gone.txt; rm "$N/gone.txt"
check block "$(commit_n)"                                     "스테이징한 뒤 작업 트리에서 지운 파일 → 차단"
git -C "$N" reset -q HEAD -- gone.txt 2>/dev/null || true
ln -s "$home_probe" "$N/link"; git -C "$N" add link
check block "$(commit_n)"                                     "홈 경로를 가리키는 심볼릭 링크 → 차단"
git -C "$N" reset -q HEAD -- link 2>/dev/null || true; rm -f "$N/link"
git -C "$N" update-index --add --cacheinfo "160000,$(git -C "$N" rev-parse HEAD),sub"
check ok    "$(commit_n)"                                     "서브모듈 항목은 내용이 없다 → 통과"

echo; echo "실패 ${fail}건"; exit "$fail"
