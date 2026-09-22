#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 워크플로가 남의 액션을 고정해서 쓰는지, 토큰 권한을 최소로 적었는지 본다.
# 필요한 것은 bash 와 git 뿐이다.
#
# 워크플로는 남의 코드를 내 자격증명과 함께 돌린다. 태그는 옮길 수 있으므로 같은 태그가
# 어제와 다른 코드를 가리킬 수 있고, **그 사실이 diff 에 남지 않는다.** 그래서 40자 SHA 로
# 고정한다. 토큰 권한도 적지 않으면 저장소 기본값을 따라가 쓰기가 붙을 수 있다.
#
# 종료 코드: 0 문제 없음 · 1 문제 있음 · 2 git 저장소가 아니다
# 문제는 표준 오류로, 요약은 표준 출력으로 낸다.
set -u

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf '%s\n' "check-workflow-security: git 저장소가 아니다." >&2; exit 2; }
cd "$root" || exit 2

files=$(find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)
if [ -z "$files" ]; then
  printf '%s\n' "check-workflow-security: .github/workflows 에 워크플로가 없다. 볼 것이 없다." >&2
  exit 0
fi

rc=0
n_pinned=0
for f in $files; do
  # 1) 최상위 permissions 를 적었는가. 없으면 저장소 기본값을 따라간다.
  if ! grep -qE '^permissions:' "$f"; then
    printf '%s\n' "check-workflow-security: ${f} 에 최상위 permissions 가 없다. 저장소 기본값을 따라간다." >&2
    rc=1
  fi
  if grep -qE '^permissions:[[:space:]]*write-all' "$f"; then
    printf '%s\n' "check-workflow-security: ${f} 가 write-all 을 준다. 필요한 것만 적어라." >&2
    rc=1
  fi

  # 2) uses 의 참조가 40자 SHA 인가.
  #    주석 줄은 보지 않는다. 같은 저장소 안의 액션(./)과 docker:// 는 고정 대상이 아니다.
  while IFS= read -r line; do
    case "$line" in
      *"#"*"uses:"*) continue ;;
    esac
    ref=$(printf '%s' "$line" | sed -E 's/.*uses:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//')
    case "$ref" in
      ./*|docker://*|"") continue ;;
    esac
    what=${ref%@*}
    ver=${ref##*@}
    if printf '%s' "$ver" | grep -qE '^[0-9a-f]{40}$'; then
      n_pinned=$((n_pinned+1))
    else
      printf '%s\n' "check-workflow-security: ${f} 의 ${what} 가 ${ver} 로 적혀 있다. 40자 SHA 로 고정해라." >&2
      rc=1
    fi
  done <<USES
$(grep -nE '^[[:space:]]*-?[[:space:]]*uses:' "$f" | sed 's/^[0-9]*://')
USES
done

if [ "$rc" -eq 0 ]; then
  printf '%s\n' "check-workflow-security: 워크플로 $(printf '%s\n' "$files" | wc -l | tr -d ' ')개, 고정된 액션 ${n_pinned}개. 문제 없다."
fi
exit "$rc"
