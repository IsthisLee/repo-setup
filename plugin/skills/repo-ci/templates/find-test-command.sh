#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 이 저장소의 테스트 명령을 실측해 표준 출력으로 알린다. 필요한 것은 bash 와 git 뿐이다.
#
# CI 는 테스트가 있을 때만 의미가 있다. 빈 CI 는 아무것도 검사하지 않으면서 통과 표시만
# 주고, 그 표시를 브랜치 보호의 필수 검사로 걸면 보호가 껍데기가 된다. 그래서 「테스트가
# 있는가」를 사람 눈이 아니라 이 스크립트가 판정한다.
#
# 종료 코드: 0 찾음(명령을 표준 출력으로) · 1 못 찾음 · 2 git 저장소가 아니다
# 무엇을 보고 골랐는지는 표준 오류로 알린다. 출력을 파이프로 받아 쓸 수 있게 나눠 둔다.
set -u

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf '%s\n' "find-test-command: git 저장소가 아니다." >&2; exit 2; }
cd "$root" || exit 2

say() { printf '%s\n' "find-test-command: $1" >&2; }

# 1) 저장소가 스스로 적어 둔 명령이 남의 관례보다 앞선다.
if [ -f .check.toml ]; then
  v=$(grep -E '^[[:space:]]*test_command[[:space:]]*=' .check.toml | head -1 | sed -E 's/.*"([^"]*)".*/\1/')
  if [ -n "$v" ]; then say ".check.toml 의 test_command 를 쓴다."; printf '%s\n' "$v"; exit 0; fi
fi

# 2) package.json 의 scripts.test.
#    npm init 이 넣는 기본값은 테스트가 아니다. 그것을 테스트로 보면 빈 CI 가 만들어진다.
if [ -f package.json ]; then
  v=$(tr -d '\n' < package.json \
      | grep -oE '"test"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -1 \
      | sed -E 's/^"test"[[:space:]]*:[[:space:]]*"//; s/"$//')
  case "$v" in
    "" ) : ;;
    *"no test specified"* ) say "package.json 의 scripts.test 가 npm 의 기본 자리표시자다. 테스트로 보지 않는다." ;;
    * ) say "package.json 의 scripts.test 를 쓴다(${v})."; printf '%s\n' "npm test"; exit 0 ;;
  esac
fi

# 3) Makefile 의 test 대상. testdata 처럼 이름이 비슷한 것에 속지 않도록 정확히 맞춘다.
if [ -f Makefile ] && grep -qE '^test:([[:space:]]|$)' Makefile; then
  say "Makefile 의 test 대상을 쓴다."; printf '%s\n' "make test"; exit 0
fi

# 4) 언어별 관례.
if [ -f pyproject.toml ] && grep -qE '^\[tool\.pytest' pyproject.toml; then
  say "pyproject.toml 의 pytest 설정을 보고 고른다."; printf '%s\n' "pytest"; exit 0
fi
if [ -f Cargo.toml ]; then
  say "Cargo.toml 이 있어 cargo test 를 쓴다."; printf '%s\n' "cargo test"; exit 0
fi
if [ -f go.mod ]; then
  say "go.mod 가 있어 go test 를 쓴다."; printf '%s\n' "go test ./..."; exit 0
fi

say "테스트 명령을 찾지 못했다. 테스트가 없는 저장소에 CI 를 만들지 마라. 테스트가 먼저다."
exit 1
