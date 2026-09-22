#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# check-workflow-security.sh 단위 테스트. 모델을 부르지 않는다.
# 워크플로는 남의 코드를 내 자격증명과 함께 돌린다. 태그는 옮길 수 있으므로
# 같은 태그가 어제와 다른 코드를 가리킬 수 있고, 그 사실이 diff 에 남지 않는다.
# 토큰 권한도 명시하지 않으면 저장소 기본값을 따라가 쓰기가 붙을 수 있다.
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/plugin/skills/repo-setup/secure/scripts/check-workflow-security.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }

mkrepo() { local d="$T/$1"; mkdir -p "$d/.github/workflows"; git init -q "$d"; printf '%s' "$d"; }
code() { (cd "$1" && bash "$S" >/dev/null 2>&1; echo $?); }
err()  { (cd "$1" && bash "$S" >/dev/null) 2>&1; }

# wf <저장소> <파일명> <uses 줄> [권한 블록]
wf() {
  local d="$1" n="$2" uses="$3" perm="${4:-permissions:
  contents: read}"
  cat > "$d/.github/workflows/$n" <<YML
name: W
on: [push]
${perm}
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - ${uses}
YML
}

SHA=3d3c42e5aac5ba805825da76410c181273ba90b1

# ── 저장소 상태 ────────────────────────────────────────────────────────────
d="$T/notgit"; mkdir -p "$d"
check 2 "$(code "$d")" "git 저장소가 아니면 2로 끝낸다"

d=$(mkrepo none)
check 0 "$(code "$d")" "워크플로가 없으면 볼 것이 없어 통과한다"
case "$(err "$d")" in *"워크플로가 없다"*) r=yes ;; *) r=no ;; esac
check yes "$r" "없다는 사실을 말한다"

# ── 고정 여부 ──────────────────────────────────────────────────────────────
d=$(mkrepo pinned); wf "$d" t.yml "uses: actions/checkout@${SHA}"
check 0 "$(code "$d")" "SHA 로 고정돼 있으면 통과한다"

d=$(mkrepo pinnedcmt); wf "$d" t.yml "uses: actions/checkout@${SHA}  # v5.0.0"
check 0 "$(code "$d")" "SHA 뒤에 태그를 주석으로 단 형태도 고정으로 본다"

d=$(mkrepo tagref); wf "$d" t.yml "uses: actions/checkout@v5"
check 1 "$(code "$d")" "태그 참조는 고정이 아니다"

d=$(mkrepo branchref); wf "$d" t.yml "uses: actions/checkout@main"
check 1 "$(code "$d")" "브랜치 참조는 고정이 아니다"

d=$(mkrepo shortsha); wf "$d" t.yml "uses: actions/checkout@3d3c42e"
check 1 "$(code "$d")" "짧은 SHA 는 고정으로 보지 않는다"

# ── 건너뛰는 것 ────────────────────────────────────────────────────────────
d=$(mkrepo localact); wf "$d" t.yml "uses: ./.github/actions/mine"
check 0 "$(code "$d")" "같은 저장소 안의 액션은 고정 대상이 아니다"

d=$(mkrepo dockeract); wf "$d" t.yml "uses: docker://alpine:3.20"
check 0 "$(code "$d")" "docker 참조는 고정 대상이 아니다"

d=$(mkrepo commented); wf "$d" t.yml "run: echo hi"
printf '      # uses: actions/checkout@v5\n' >> "$d/.github/workflows/t.yml"
check 0 "$(code "$d")" "주석 안의 uses 는 보지 않는다"

# ── 권한 ───────────────────────────────────────────────────────────────────
d=$(mkrepo noperm); wf "$d" t.yml "uses: actions/checkout@${SHA}" "# 권한 없음"
check 1 "$(code "$d")" "permissions 가 없으면 실패한다"

d=$(mkrepo writeall); wf "$d" t.yml "uses: actions/checkout@${SHA}" "permissions: write-all"
check 1 "$(code "$d")" "write-all 은 실패한다"

# ── 여러 파일과 확장자 ─────────────────────────────────────────────────────
d=$(mkrepo two); wf "$d" a.yml "uses: actions/checkout@${SHA}"; wf "$d" b.yml "uses: actions/checkout@v5"
check 1 "$(code "$d")" "하나만 어긋나도 실패한다"

d=$(mkrepo yamlext); wf "$d" t.yaml "uses: actions/checkout@v5"
check 1 "$(code "$d")" ".yaml 확장자도 본다"

# ── 보고 ───────────────────────────────────────────────────────────────────
d=$(mkrepo report); wf "$d" t.yml "uses: actions/checkout@v5"
case "$(err "$d")" in *t.yml*actions/checkout*|*actions/checkout*t.yml*) r=yes ;; *) r=no ;; esac
check yes "$r" "어느 파일의 어느 액션인지 보인다"

echo
# ── 함께 싣는 골격 ─────────────────────────────────────────────────────────
TP="$ROOT/plugin/skills/repo-setup/secure/templates"
hasf() { grep -qE "$2" "$TP/$1" 2>/dev/null && echo yes || echo no; }

check yes "$([ -f "$TP/dependabot.yml" ] && echo yes || echo no)" "dependabot 골격이 있다"
check yes "$(hasf dependabot.yml '^version:[[:space:]]*2')" "dependabot 골격이 version 2 다"
check yes "$(hasf dependabot.yml 'package-ecosystem:[[:space:]]*"?github-actions')" "액션 판올림을 켠다"
# init 과 analyze 는 판이 같아야 한다. 나뉘어 올라오면 한쪽만 올라가 분석이 깨진다.
check yes "$(hasf dependabot.yml 'codeql-action')" "함께 올려야 하는 액션을 묶는다"

check yes "$([ -f "$TP/codeql.yml" ] && echo yes || echo no)" "코드 스캐닝 골격이 있다"
check yes "$(hasf codeql.yml 'security-events:[[:space:]]*write')" "결과를 올릴 권한만 준다"
check yes "$(hasf codeql.yml 'fail-fast:[[:space:]]*false')" "한 언어가 실패해도 나머지를 올린다"
check yes "$(hasf codeql.yml '__LANGUAGES__')" "언어 목록이 자리표시자다"
# 이 스킬이 고정을 맡으므로 스스로 놓는 파일이 태그 참조를 남기면 앞뒤가 맞지 않는다.
check no  "$(grep -qE 'uses:.*@v[0-9]' "$TP/codeql.yml" 2>/dev/null && echo yes || echo no)" "골격 자신이 태그 참조를 쓰지 않는다"

echo
if [ "$fail" -eq 0 ]; then echo "실패 0건"; else echo "실패 ${fail}건"; fi
exit "$fail"
