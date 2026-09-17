#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 이 저장소가 스스로 지켜야 하는 불변식. 조용히 어긋나는 것들이라 사람이 눈으로 볼 수 없다.
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
R="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
ok()  { echo "✅ $1"; }
bad() { echo "❌ $1"; fail=$((fail+1)); }

for f in "$R/.claude-plugin/marketplace.json" "$R/plugin/.claude-plugin/plugin.json"; do
  if python3 -c 'import json,sys;json.load(open(sys.argv[1]))' "$f"; then ok "$(basename "$f"): 올바른 JSON"
  else bad "$(basename "$f"): JSON 파싱 실패"; fi
done

v1=$(python3 -c 'import json;print(json.load(open("'"$R"'/plugin/.claude-plugin/plugin.json"))["version"])' 2>/dev/null)
v2=$(python3 -c 'import json;print(json.load(open("'"$R"'/.claude-plugin/marketplace.json"))["plugins"][0]["version"])' 2>/dev/null)
if [ -n "$v1" ] && [ "$v1" = "$v2" ]; then ok "버전이 두 매니페스트에서 같다($v1)"; else bad "버전이 다르다($v1 vs $v2)"; fi

# 스킬이 품은 템플릿이 실제 파일과 어긋나면 옮겨 간 사람이 낡은 것을 쓴다.
if python3 - "$R" <<'TPL'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
skill = (root / "plugin/skills/repo-privacy/SKILL.md").read_text(encoding="utf-8")
for name in ("pre-commit", "setup.sh"):
    body = (root / "templates" / name).read_text(encoding="utf-8").rstrip("\n")
    assert body in skill, f"스킬의 {name} 인용이 templates/{name} 과 다르다"
TPL
then ok "스킬의 템플릿 인용이 templates/ 와 같다"
else bad "스킬의 템플릿 인용이 낡았다. templates/ 로 다시 맞춰라"; fi

# 폴더명과 name 이 어긋나면 커맨드가 뜨지 않는다.
n=$(sed -n 's/^name: //p' "$R/plugin/skills/repo-privacy/SKILL.md" | head -1)
if [ "$n" = repo-privacy ]; then ok "스킬 폴더명과 name 이 같다"; else bad "스킬 name 이 폴더명과 다르다($n)"; fi

# 템플릿에 실행 비트가 없으면 깐 사람이 첫 줄에서 멈춘다.
for t in pre-commit setup.sh; do
  if [ -x "$R/templates/$t" ]; then ok "templates/${t} 에 실행 비트가 있다"; else bad "templates/${t} 에 실행 비트가 없다"; fi
done

# 개인 패턴이 저장소에 새어 들어가면 안 된다. 이 저장소가 다루는 주제가 바로 그것이다.
if git -C "$R" ls-files 2>/dev/null | grep -q .; then
  leak=$(git -C "$R" grep -lE '/Users/[A-Za-z]|/home/[A-Za-z]' -- . 2>/dev/null | grep -v '^templates/' | grep -v '^tests/' || true)
  if [ -z "$leak" ]; then ok "추적 파일에 홈 경로가 없다"
  else bad "홈 경로가 든 파일이 있다"; printf '%s\n' "$leak" | sed 's/^/    /'; fi
else
  ok "추적 파일이 아직 없어 홈 경로 검사를 건너뛴다"
fi

echo
if [ "$fail" -eq 0 ]; then echo "전부 통과"; else echo "실패 ${fail}건"; fi
exit "$fail"
