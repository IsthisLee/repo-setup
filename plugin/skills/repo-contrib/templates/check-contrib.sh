#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 협업 파일이 GitHub 이 실제로 찾는 자리에 있는지 본다. 필요한 것은 bash 와 git 뿐이다.
#
# GitHub 은 이 파일들을 한 곳에서만 찾지 않는다. 루트와 .github/ 를 모두 보고,
# CODEOWNERS 는 docs/ 까지 본다. 한 곳만 보면 이미 있는 파일을 없다고 보고하게 되고,
# 그 보고를 믿고 덮어쓰면 남이 쓴 문서가 사라진다.
#
# 사용법: check-contrib.sh [항목...]
#   항목을 적지 않으면 다섯을 모두 본다.
#   항목: contributing · security · codeowners · issue · pr
#
# 종료 코드: 0 다 있다 · 1 빠진 것이 있다 · 2 git 저장소가 아니거나 모르는 항목이다
set -u

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf '%s\n' "check-contrib: git 저장소가 아니다." >&2; exit 2; }
cd "$root" || exit 2

# 항목마다 GitHub 이 실제로 보는 자리를 그대로 적는다.
# 이름으로 함수를 불러 나누면 shellcheck 가 쓰임을 못 보고, 사람도 어디서 불리는지 못 찾는다.
present() {
  case "$1" in
    contributing) [ -f CONTRIBUTING.md ] || [ -f .github/CONTRIBUTING.md ] || [ -f docs/CONTRIBUTING.md ] ;;
    security)     [ -f SECURITY.md ]     || [ -f .github/SECURITY.md ]     || [ -f docs/SECURITY.md ] ;;
    codeowners)   [ -f CODEOWNERS ]      || [ -f .github/CODEOWNERS ]      || [ -f docs/CODEOWNERS ] ;;
    pr)           [ -f .github/PULL_REQUEST_TEMPLATE.md ] || [ -f .github/pull_request_template.md ] \
                    || [ -f PULL_REQUEST_TEMPLATE.md ] || [ -f pull_request_template.md ] ;;
    # 폴더만 있고 비어 있으면 아무 템플릿도 뜨지 않는다. 있는 것으로 보지 않는다.
    issue)        [ -d .github/ISSUE_TEMPLATE ] \
                    && [ -n "$(find .github/ISSUE_TEMPLATE -maxdepth 1 -type f -print -quit 2>/dev/null)" ] ;;
    *)            return 9 ;;
  esac
}

label() {
  case "$1" in
    contributing) printf '%s' "CONTRIBUTING (기여 방법)" ;;
    security)     printf '%s' "SECURITY.md (취약점 신고처)" ;;
    codeowners)   printf '%s' "CODEOWNERS (리뷰 담당)" ;;
    issue)        printf '%s' ".github/ISSUE_TEMPLATE/ (이슈 서식)" ;;
    pr)           printf '%s' "PULL_REQUEST_TEMPLATE (PR 서식)" ;;
  esac
}

items="$*"
[ -n "$items" ] || items="contributing security codeowners issue pr"

rc=0
found=""
for it in $items; do
  if present "$it"; then
    found="${found} ${it}"
  elif [ "$?" -eq 9 ]; then
    printf '%s\n' "check-contrib: 모르는 항목 '${it}'. 쓸 수 있는 것은 contributing · security · codeowners · issue · pr 다." >&2
    exit 2
  else
    printf '%s\n' "check-contrib: $(label "$it") 가 없다." >&2
    rc=1
  fi
done

if [ "$rc" -eq 0 ]; then
  printf '%s\n' "check-contrib: 다 있다:${found}"
fi
exit "$rc"
