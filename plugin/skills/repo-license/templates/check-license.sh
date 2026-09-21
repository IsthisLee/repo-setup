#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 라이선스 선언이 서로 맞는지 본다. 필요한 것은 bash 와 git 뿐이다.
#
# 선언은 두 곳에 흩어진다. LICENSE 파일의 본문과 매니페스트의 license 필드다.
# 둘이 어긋나면 배포물과 문서가 다른 말을 하는데, 사람 눈에는 잘 띄지 않는다.
#
# 종료 코드: 0 맞다 · 1 어긋났거나 알아보지 못했다 · 2 git 저장소가 아니다
#
# 탐지 규칙의 머리글은 GitHub 라이선스 API 의 전문에서 가져왔다(2026-09-22 확인).
# 모르는 본문에는 이름을 붙이지 않는다. 틀린 이름이 붙으면 아무도 다시 보지 않는다.
#
# 아는 한계: pyproject.toml 의 license = {text = "MIT"} 형태는 읽지 못하고 건너뛴다.
set -u

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf '%s\n' "check-license: git 저장소가 아니다." >&2; exit 2; }
cd "$root" || exit 2

file=""
for f in LICENSE LICENSE.md LICENSE.txt COPYING COPYING.md; do
  [ -f "$f" ] && { file="$f"; break; }
done
[ -n "$file" ] || {
  printf '%s\n' "check-license: LICENSE 파일이 없다. 찾은 이름은 LICENSE · LICENSE.md · LICENSE.txt · COPYING 이다." >&2
  exit 1; }

head30=$(head -30 "$file")

# AFFERO 와 LESSER 를 먼저 본다. 셋이 'GENERAL PUBLIC LICENSE' 를 공유하므로
# 구별되는 낱말까지 넣어 맞추고, 순서로 한 번 더 막는다.
spdx=""
case "$head30" in
  *"GNU AFFERO GENERAL PUBLIC LICENSE"*)
    case "$head30" in *"Version 3"*) spdx="AGPL-3.0" ;; esac ;;
  *"GNU LESSER GENERAL PUBLIC LICENSE"*)
    case "$head30" in *"Version 3"*) spdx="LGPL-3.0" ;; *"Version 2.1"*) spdx="LGPL-2.1" ;; esac ;;
  *"GNU GENERAL PUBLIC LICENSE"*)
    case "$head30" in *"Version 3"*) spdx="GPL-3.0" ;; *"Version 2"*) spdx="GPL-2.0" ;; esac ;;
  *"Apache License"*)
    case "$head30" in *"Version 2.0"*) spdx="Apache-2.0" ;; esac ;;
  *"MIT License"*)                        spdx="MIT" ;;
  *"BSD 3-Clause License"*)               spdx="BSD-3-Clause" ;;
  *"BSD 2-Clause License"*)               spdx="BSD-2-Clause" ;;
  *"Mozilla Public License Version 2.0"*) spdx="MPL-2.0" ;;
  *"ISC License"*)                        spdx="ISC" ;;
  *"CC0 1.0 Universal"*)                  spdx="CC0-1.0" ;;
  *"This is free and unencumbered software released into the public domain"*) spdx="Unlicense" ;;
esac
[ -n "$spdx" ] || {
  printf '%s\n' "check-license: ${file} 의 라이선스를 알아보지 못했다. 짐작해서 이름을 붙이지 않는다." >&2
  exit 1; }

# SPDX 표기는 흔들린다. GPL 계열의 -only 와 -or-later, 대소문자가 그렇다.
# 그것을 어긋남으로 보면 거짓 경보가 나고, 한 번 나면 사람이 이 검사를 꺼 버린다.
norm() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/-(only|or-later)$//'
}
want=$(norm "$spdx")

# 매니페스트는 루트에만 있지 않다. 두 층 플러그인 저장소는 한 단계 아래에 둔다.
# 고정 경로 목록을 쓰면 그것을 통째로 놓치고, 놓친 사실이 겉으로 드러나지 않는다.
# 대신 남의 패키지까지 보면 거짓 경보가 쏟아지므로 의존성 폴더는 잘라낸다.
manifests=$(find . -maxdepth 3 \
  \( -name .git -o -name node_modules -o -name vendor -o -name .venv -o -name target \) -prune -o \
  -type f \( -name package.json -o -name pyproject.toml -o -name Cargo.toml \
             -o -name composer.json -o -name plugin.json -o -name marketplace.json \) -print \
  | sed 's|^\./||' | sort)

rc=0
seen=""
for m in $manifests; do
  [ -f "$m" ] || continue
  vals=$(grep -oE '"license"[[:space:]]*:[[:space:]]*"[^"]*"|^[[:space:]]*license[[:space:]]*=[[:space:]]*"[^"]*"' "$m" \
         | sed -E 's/.*"([^"]*)"$/\1/')
  [ -n "$vals" ] || continue
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    seen="${seen} ${m}=${v}"
    if [ "$(norm "$v")" != "$want" ]; then
      printf '%s\n' "check-license: ${file} 는 ${spdx} 인데 ${m} 는 ${v} 라고 적혀 있다." >&2
      rc=1
    fi
  done <<VALS
$vals
VALS
done

if [ "$rc" -eq 0 ]; then
  if [ -n "$seen" ]; then
    printf '%s\n' "check-license: ${file} → ${spdx}. 매니페스트도 같다:${seen}"
  else
    printf '%s\n' "check-license: ${file} → ${spdx}. license 필드를 둔 매니페스트가 없어 대조할 것이 없다."
  fi
fi
exit "$rc"
