#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# find-test-command.sh 단위 테스트. 모델을 부르지 않는다.
# CI 는 테스트가 있을 때만 의미가 있다. 빈 CI 는 아무것도 검사하지 않으면서 통과 표시만
# 주고, 그 표시를 브랜치 보호의 필수 검사로 걸면 보호가 껍데기가 된다.
# 그래서 「테스트 명령이 있는가」를 사람 눈이 아니라 이 스크립트가 판정한다.
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/plugin/skills/repo-ci/templates/find-test-command.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }

mkrepo() { local d="$T/$1"; mkdir -p "$d"; git init -q "$d"; printf '%s' "$d"; }
code() { (cd "$1" && bash "$S" >/dev/null 2>&1; echo $?); }
out()  { (cd "$1" && bash "$S" 2>/dev/null); }
err()  { (cd "$1" && bash "$S" >/dev/null) 2>&1; }

# ── 없을 때 ────────────────────────────────────────────────────────────────
d=$(mkrepo empty)
check 1 "$(code "$d")" "테스트 명령이 없으면 1로 끝낸다"
case "$(err "$d")" in *"찾지 못했다"*) r=yes ;; *) r=no ;; esac
check yes "$r" "찾지 못했다고 말한다"

d="$T/notgit"; mkdir -p "$d"
check 2 "$(code "$d")" "git 저장소가 아니면 2로 끝낸다"

# ── 자리표시자를 테스트로 보지 않는다 ──────────────────────────────────────
# npm init 이 넣는 기본값이다. 이것을 테스트로 보면 빈 CI 가 만들어진다.
d=$(mkrepo npmstub)
printf '{"scripts":{"test":"echo \\"Error: no test specified\\" && exit 1"}}\n' > "$d/package.json"
check 1 "$(code "$d")" "npm 의 기본 자리표시자는 테스트가 아니다"

# ── 종류별로 찾는다 ────────────────────────────────────────────────────────
d=$(mkrepo node); printf '{"scripts":{"test":"vitest run"}}\n' > "$d/package.json"
check "npm test" "$(out "$d")" "package.json 의 scripts.test 를 찾는다"

d=$(mkrepo mk); printf 'test:\n\t@echo hi\n' > "$d/Makefile"
check "make test" "$(out "$d")" "Makefile 의 test 대상을 찾는다"

d=$(mkrepo py); printf '[tool.pytest.ini_options]\ntestpaths = ["tests"]\n' > "$d/pyproject.toml"
check "pytest" "$(out "$d")" "pyproject.toml 의 pytest 설정을 찾는다"

d=$(mkrepo rust); printf '[package]\nname = "x"\n' > "$d/Cargo.toml"
check "cargo test" "$(out "$d")" "Cargo.toml 이 있으면 cargo test 다"

d=$(mkrepo go); printf 'module example.com/x\n' > "$d/go.mod"
check "go test ./..." "$(out "$d")" "go.mod 가 있으면 go test 다"

d=$(mkrepo cfg); printf 'test_command = "tests/all.sh"\n' > "$d/.check.toml"
check "tests/all.sh" "$(out "$d")" ".check.toml 의 test_command 를 그대로 쓴다"

# ── 우선순위 ───────────────────────────────────────────────────────────────
# 저장소가 스스로 적어 둔 명령이 남의 관례보다 앞선다.
d=$(mkrepo both); printf 'test_command = "tests/all.sh"\n' > "$d/.check.toml"
printf '{"scripts":{"test":"vitest run"}}\n' > "$d/package.json"
check "tests/all.sh" "$(out "$d")" ".check.toml 이 package.json 보다 앞선다"

d=$(mkrepo nodemk); printf '{"scripts":{"test":"vitest run"}}\n' > "$d/package.json"
printf 'test:\n\t@echo hi\n' > "$d/Makefile"
check "npm test" "$(out "$d")" "package.json 이 Makefile 보다 앞선다"

# ── 무엇을 보고 골랐는지 밝힌다 ────────────────────────────────────────────
d=$(mkrepo why); printf '{"scripts":{"test":"vitest run"}}\n' > "$d/package.json"
case "$(err "$d")" in *package.json*) r=yes ;; *) r=no ;; esac
check yes "$r" "어느 파일을 보고 골랐는지 알린다"

# ── Makefile 의 비슷한 이름에 속지 않는다 ──────────────────────────────────
d=$(mkrepo faketgt); printf 'testdata:\n\t@echo hi\n' > "$d/Makefile"
check 1 "$(code "$d")" "testdata 대상을 test 로 보지 않는다"

echo
# ── 워크플로 골격 ──────────────────────────────────────────────────────────
# 워크플로는 돌려 보기 전에는 틀린 것이 드러나지 않는다. 구조만이라도 못박아 둔다.
W="$ROOT/plugin/skills/repo-ci/templates/tests.yml"
has() { grep -qE "$1" "$W" && echo yes || echo no; }

check yes "$([ -f "$W" ] && echo yes || echo no)" "워크플로 골격이 있다"
check yes "$(has '^permissions:')" "permissions 를 명시한다"
check no  "$(grep -qE ':[[:space:]]*write' "$W" && echo yes || echo no)" "쓰기 권한을 주지 않는다"
check yes "$(has 'fail-fast:[[:space:]]*false')" "한 대가 실패해도 나머지를 본다"
check yes "$(has '__TEST_COMMAND__')" "테스트 명령 자리표시자가 있다"
check yes "$(has '__DEFAULT_BRANCH__')" "기본 브랜치 자리표시자가 있다"

# 자리표시자를 다 바꾸면 남는 것이 없어야 한다. 하나라도 남으면 워크플로가 조용히 죽는다.
left=$(sed -e 's/__DEFAULT_BRANCH__/main/g' -e 's|__TEST_COMMAND__|make test|g' \
           -e '/__SETUP_STEPS__/d' "$W" | grep -cE '__[A-Z_]+__' || true)
check 0 "$left" "아는 자리표시자를 바꾸면 남는 것이 없다"

echo
if [ "$fail" -eq 0 ]; then echo "실패 0건"; else echo "실패 ${fail}건"; fi
exit "$fail"
