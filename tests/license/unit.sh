#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# check-license.sh 단위 테스트. 모델을 부르지 않는다.
# 라이선스 선언은 두 곳에 흩어진다. LICENSE 파일의 본문과 매니페스트의 license 필드다.
# 둘이 어긋나면 배포물과 문서가 다른 말을 하는데, 사람 눈에는 잘 띄지 않는다.
# 탐지 규칙의 머리글은 GitHub 라이선스 API 의 전문을 읽어 정했다(2026-09-22).
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/plugin/skills/repo-setup/license/scripts/check-license.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }

# mkrepo <이름> → 빈 git 저장소를 만들고 경로를 돌려준다
mkrepo() { local d="$T/$1"; mkdir -p "$d"; git init -q "$d"; printf '%s' "$d"; }
code() { (cd "$1" && bash "$S" >/dev/null 2>&1; echo $?); }
out()  { (cd "$1" && bash "$S" 2>&1); }

# 전문 전체가 필요하지 않다. 검사기는 머리 30줄만 본다.
mit()    { printf 'MIT License\n\nCopyright (c) 2026 Someone\n' > "$1/LICENSE"; }
apache() { printf '                                 Apache License\n                           Version 2.0, January 2004\n' > "$1/LICENSE"; }
gpl3()   { printf '                    GNU GENERAL PUBLIC LICENSE\n                       Version 3, 29 June 2007\n' > "$1/LICENSE"; }
agpl3()  { printf '                    GNU AFFERO GENERAL PUBLIC LICENSE\n                       Version 3, 19 November 2007\n' > "$1/LICENSE"; }
lgpl3()  { printf '                   GNU LESSER GENERAL PUBLIC LICENSE\n                       Version 3, 29 June 2007\n' > "$1/LICENSE"; }

# ── 파일이 없거나 알아볼 수 없을 때 ────────────────────────────────────────
d=$(mkrepo nofile)
check 1 "$(code "$d")" "LICENSE 가 없으면 실패한다"
case "$(out "$d")" in *"LICENSE"*) r=yes ;; *) r=no ;; esac
check yes "$r" "없다는 사실을 문장으로 알린다"

d=$(mkrepo unknown); printf 'Do whatever you want.\n' > "$d/LICENSE"
check 1 "$(code "$d")" "알아볼 수 없는 본문이면 실패한다"
case "$(out "$d")" in *"알아보지 못했다"*) r=yes ;; *) r=no ;; esac
check yes "$r" "짐작해서 이름을 붙이지 않는다"

# mkrepo 는 git init 을 하므로 여기서는 쓰지 않는다. 저장소 밖에서 돌려야 한다.
d="$T/notgit"; mkdir -p "$d"
check 2 "$(code "$d")" "git 저장소가 아니면 2로 끝낸다"

# ── 매니페스트가 없을 때 ───────────────────────────────────────────────────
d=$(mkrepo lonely); mit "$d"
check 0 "$(code "$d")" "매니페스트가 없으면 대조할 것이 없어 통과한다"

# ── 일치와 불일치 ──────────────────────────────────────────────────────────
d=$(mkrepo match); mit "$d"; printf '{"license": "MIT"}\n' > "$d/package.json"
check 0 "$(code "$d")" "파일과 package.json 이 같으면 통과한다"

d=$(mkrepo clash); mit "$d"; printf '{"license": "Apache-2.0"}\n' > "$d/package.json"
check 1 "$(code "$d")" "파일과 package.json 이 다르면 실패한다"
case "$(out "$d")" in *MIT*Apache-2.0*|*Apache-2.0*MIT*) r=yes ;; *) r=no ;; esac
check yes "$r" "어긋난 두 값을 함께 보인다"

# ── 매니페스트 종류 ────────────────────────────────────────────────────────
d=$(mkrepo py); mit "$d"; printf 'license = "MIT"\n' > "$d/pyproject.toml"
check 0 "$(code "$d")" "pyproject.toml 의 license 를 읽는다"

d=$(mkrepo rust); mit "$d"; printf 'license = "Apache-2.0"\n' > "$d/Cargo.toml"
check 1 "$(code "$d")" "Cargo.toml 의 어긋남을 잡는다"

d=$(mkrepo plug); mit "$d"; mkdir -p "$d/.claude-plugin"
printf '{"name":"x","license":"MIT"}\n' > "$d/.claude-plugin/plugin.json"
check 0 "$(code "$d")" ".claude-plugin/plugin.json 의 license 를 읽는다"

d=$(mkrepo many); mit "$d"; printf '{"license": "MIT"}\n' > "$d/package.json"
printf 'license = "GPL-3.0"\n' > "$d/Cargo.toml"
check 1 "$(code "$d")" "매니페스트 하나만 어긋나도 실패한다"

# ── 파일 이름과 탐지 규칙 ──────────────────────────────────────────────────
d=$(mkrepo mdname); printf 'MIT License\n' > "$d/LICENSE.md"; printf '{"license": "MIT"}\n' > "$d/package.json"
check 0 "$(code "$d")" "LICENSE.md 도 찾는다"

d=$(mkrepo apa); apache "$d"; printf '{"license": "Apache-2.0"}\n' > "$d/package.json"
check 0 "$(code "$d")" "Apache-2.0 을 알아본다"

d=$(mkrepo g3); gpl3 "$d"; printf '{"license": "GPL-3.0"}\n' > "$d/package.json"
check 0 "$(code "$d")" "GPL-3.0 을 알아본다"

d=$(mkrepo a3); agpl3 "$d"; printf '{"license": "AGPL-3.0"}\n' > "$d/package.json"
check 0 "$(code "$d")" "AGPL-3.0 을 GPL-3.0 으로 오인하지 않는다"

d=$(mkrepo l3); lgpl3 "$d"; printf '{"license": "LGPL-3.0"}\n' > "$d/package.json"
check 0 "$(code "$d")" "LGPL-3.0 을 GPL-3.0 으로 오인하지 않는다"

# ── SPDX 표기 흔들림 ───────────────────────────────────────────────────────
# GPL 계열은 -only 와 -or-later 를 붙여 쓰는 곳이 많다. 그것을 어긋남으로 보면
# 거짓 경보가 나고, 거짓 경보가 한 번 나면 사람이 이 검사를 꺼 버린다.
d=$(mkrepo later); gpl3 "$d"; printf '{"license": "GPL-3.0-or-later"}\n' > "$d/package.json"
check 0 "$(code "$d")" "GPL-3.0-or-later 를 같은 것으로 본다"

d=$(mkrepo onlyv); gpl3 "$d"; printf '{"license": "GPL-3.0-only"}\n' > "$d/package.json"
check 0 "$(code "$d")" "GPL-3.0-only 를 같은 것으로 본다"

d=$(mkrepo lower); mit "$d"; printf '{"license": "mit"}\n' > "$d/package.json"
check 0 "$(code "$d")" "대소문자가 달라도 같은 것으로 본다"

d=$(mkrepo show); mit "$d"; printf '{"license": "MIT"}\n' > "$d/package.json"
case "$(out "$d")" in *MIT*) r=yes ;; *) r=no ;; esac
check yes "$r" "통과할 때 무엇으로 판별했는지 보인다"

echo
# ── 중첩된 매니페스트 ──────────────────────────────────────────────────────
# 두 층 플러그인 저장소는 매니페스트가 루트가 아니라 한 단계 아래에 있다.
# 고정 경로 목록을 쓰면 그것을 통째로 놓치고, 놓친 사실이 겉으로 드러나지 않는다.
d=$(mkrepo nested); mit "$d"; mkdir -p "$d/plugin/.claude-plugin"
printf '{"license": "Apache-2.0"}\n' > "$d/plugin/.claude-plugin/plugin.json"
check 1 "$(code "$d")" "한 단계 아래의 plugin.json 도 본다"

# 남의 패키지까지 보면 거짓 경보가 쏟아진다.
d=$(mkrepo deps); mit "$d"; printf '{"license": "MIT"}\n' > "$d/package.json"
mkdir -p "$d/node_modules/foo"; printf '{"license": "GPL-3.0"}\n' > "$d/node_modules/foo/package.json"
check 0 "$(code "$d")" "node_modules 안은 보지 않는다"

echo
if [ "$fail" -eq 0 ]; then echo "실패 0건"; else echo "실패 ${fail}건"; fi
exit "$fail"
