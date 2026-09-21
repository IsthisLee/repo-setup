#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# check-contrib.sh 단위 테스트. 모델을 부르지 않는다.
# GitHub 은 협업 파일을 한 곳에서만 찾지 않는다. 루트와 .github/ 를 모두 보고,
# CODEOWNERS 는 docs/ 까지 본다. 한 곳만 보면 이미 있는 파일을 없다고 보고하게 된다.
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/plugin/skills/repo-contrib/templates/check-contrib.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }

mkrepo() { local d="$T/$1"; mkdir -p "$d"; git init -q "$d"; printf '%s' "$d"; }
put() { mkdir -p "$(dirname "$1/$2")"; printf 'x\n' > "$1/$2"; }
code() { local d="$1"; shift; (cd "$d" && bash "$S" "$@" >/dev/null 2>&1; echo $?); }
err()  { local d="$1"; shift; (cd "$d" && bash "$S" "$@" >/dev/null) 2>&1; }

# ── 저장소 상태 ────────────────────────────────────────────────────────────
d="$T/notgit"; mkdir -p "$d"
check 2 "$(code "$d")" "git 저장소가 아니면 2로 끝낸다"

d=$(mkrepo bare)
check 1 "$(code "$d")" "아무것도 없으면 1로 끝낸다"
case "$(err "$d")" in *CONTRIBUTING*SECURITY*|*SECURITY*CONTRIBUTING*) r=yes ;; *) r=no ;; esac
check yes "$r" "빠진 것의 이름을 보인다"

# ── 위치를 여럿 본다 ───────────────────────────────────────────────────────
d=$(mkrepo croot); put "$d" CONTRIBUTING.md
check 0 "$(code "$d" contributing)" "루트의 CONTRIBUTING.md 를 찾는다"

d=$(mkrepo cdot); put "$d" .github/CONTRIBUTING.md
check 0 "$(code "$d" contributing)" ".github/ 의 CONTRIBUTING.md 도 찾는다"

d=$(mkrepo sroot); put "$d" SECURITY.md
check 0 "$(code "$d" security)" "루트의 SECURITY.md 를 찾는다"

d=$(mkrepo sdot); put "$d" .github/SECURITY.md
check 0 "$(code "$d" security)" ".github/ 의 SECURITY.md 도 찾는다"

for loc in CODEOWNERS .github/CODEOWNERS docs/CODEOWNERS; do
  d=$(mkrepo "co$(printf '%s' "$loc" | tr -d './')"); put "$d" "$loc"
  check 0 "$(code "$d" codeowners)" "${loc} 를 찾는다"
done

# ── 이슈 템플릿은 폴더가 아니라 내용이 있어야 한다 ─────────────────────────
d=$(mkrepo emptytpl); mkdir -p "$d/.github/ISSUE_TEMPLATE"
check 1 "$(code "$d" issue)" "빈 ISSUE_TEMPLATE 폴더는 있는 것으로 보지 않는다"

d=$(mkrepo fulltpl); put "$d" .github/ISSUE_TEMPLATE/bug_report.md
check 0 "$(code "$d" issue)" "ISSUE_TEMPLATE 에 파일이 있으면 찾는다"

# ── PR 템플릿의 두 표기 ────────────────────────────────────────────────────
d=$(mkrepo prupper); put "$d" .github/PULL_REQUEST_TEMPLATE.md
check 0 "$(code "$d" pr)" "대문자 PULL_REQUEST_TEMPLATE.md 를 찾는다"

d=$(mkrepo prlower); put "$d" .github/pull_request_template.md
check 0 "$(code "$d" pr)" "소문자 pull_request_template.md 도 찾는다"

# ── 인자 ───────────────────────────────────────────────────────────────────
d=$(mkrepo only); put "$d" CONTRIBUTING.md
check 0 "$(code "$d" contributing)" "인자를 주면 그것만 본다"
check 1 "$(code "$d")" "인자가 없으면 다섯을 모두 본다"
check 2 "$(code "$d" nosuchthing)" "모르는 항목을 주면 2로 끝낸다"

# ── 다 갖췄을 때 ───────────────────────────────────────────────────────────
d=$(mkrepo full)
put "$d" CONTRIBUTING.md; put "$d" SECURITY.md; put "$d" .github/CODEOWNERS
put "$d" .github/ISSUE_TEMPLATE/bug_report.md; put "$d" .github/pull_request_template.md
check 0 "$(code "$d")" "다섯이 모두 있으면 통과한다"

# ── 함께 싣는 골격 ─────────────────────────────────────────────────────────
TP="$ROOT/plugin/skills/repo-contrib/templates"
for f in CONTRIBUTING.md SECURITY.md pull_request_template.md CODEOWNERS; do
  check yes "$([ -f "$TP/$f" ] && echo yes || echo no)" "${f} 골격이 있다"
done
check yes "$([ -f "$TP/ISSUE_TEMPLATE/bug_report.md" ] && echo yes || echo no)" "이슈 골격이 있다"
# 연락처와 명령은 저장소마다 다르다. 채우지 않고 두면 거짓 안내가 남는다.
check yes "$(grep -qE '__[A-Z_]+__' "$TP/SECURITY.md" 2>/dev/null && echo yes || echo no)" "SECURITY 골격이 자리표시자를 쓴다"
check yes "$(grep -qE '__[A-Z_]+__' "$TP/CONTRIBUTING.md" 2>/dev/null && echo yes || echo no)" "CONTRIBUTING 골격이 자리표시자를 쓴다"

echo
if [ "$fail" -eq 0 ]; then echo "실패 0건"; else echo "실패 ${fail}건"; fi
exit "$fail"
