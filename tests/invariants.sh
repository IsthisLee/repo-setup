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

# privacy 스킬이 품은 템플릿이 실제 파일과 어긋나면 옮겨 간 사람이 낡은 것을 쓴다.
# 템플릿을 품는 스킬은 privacy 뿐이라 이 검사는 거기에만 건다.
if python3 - "$R" <<'TPL'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
skill = (root / "plugin/skills/privacy/SKILL.md").read_text(encoding="utf-8")
for name in ("pre-commit", "setup.sh"):
    body = (root / "templates" / name).read_text(encoding="utf-8").rstrip("\n")
    assert body in skill, f"privacy 스킬의 {name} 인용이 templates/{name} 과 다르다"
TPL
then ok "privacy 스킬의 템플릿 인용이 templates/ 와 같다"
else bad "privacy 스킬의 템플릿 인용이 낡았다. templates/ 로 다시 맞춰라"; fi

# 폴더명과 name 이 어긋나면 그 커맨드가 뜨지 않는다. 스킬 하나를 이름으로 못박으면
# 새 스킬이 검사 없이 들어오므로 전부 순회한다.
mismatch=""
for d in "$R"/plugin/skills/*/; do
  [ -f "$d/SKILL.md" ] || { mismatch="$mismatch $(basename "$d")(SKILL.md 없음)"; continue; }
  want=$(basename "$d")
  got=$(sed -n 's/^name: //p' "$d/SKILL.md" | head -1)
  [ "$want" = "$got" ] || mismatch="$mismatch ${want}(name=${got})"
done
if [ -z "$mismatch" ]; then ok "스킬 폴더명과 name 이 전부 같다"
else bad "폴더명과 name 이 어긋난 스킬이 있다:$mismatch"; fi

# 스킬 수는 조용히 낡는다. 문서가 적은 숫자와 실제가 어긋나면 사람이 못 본다.
n_sk=$(find "$R/plugin/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
if [ "$n_sk" = 2 ]; then ok "스킬이 둘이다(auto + privacy)"
else bad "스킬이 둘이 아니다(${n_sk}개). 문서와 이 숫자를 함께 고쳐라"; fi

# 진입점이 부를 좁은 스킬 목록과 실제 폴더가 어긋나면, 없는 것을 부르거나 있는 것을 모른다.
# 둘 다 조용히 일어난다. auto 본문의 표에 적힌 이름과 실제 폴더를 대조한다.
if python3 - "$R" <<'ROUTE'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
body = (root / "plugin/skills/auto/SKILL.md").read_text(encoding="utf-8")
listed = set(re.findall(r"^\| `([a-z][a-z0-9-]*)` \|", body, re.M))
actual = {d.name for d in (root / "plugin/skills").iterdir() if d.is_dir()} - {"auto"}
assert listed, "auto 본문에 좁은 스킬 표가 없다"
assert listed == actual, f"auto 가 적은 목록 {sorted(listed)} 와 실제 스킬 {sorted(actual)} 이 다르다"
ROUTE
then ok "auto 가 적은 좁은 스킬 목록이 실제와 같다"
else bad "auto 의 좁은 스킬 표가 실제와 다르다. 표를 고쳐라"; fi

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
