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
if [ "$n_sk" = 5 ]; then ok "스킬이 다섯이다(repo-setup + 좁은 스킬 넷)"
else bad "스킬이 다섯이 아니다(${n_sk}개). 문서와 이 숫자를 함께 고쳐라"; fi

# 진입점이 부를 좁은 스킬 목록과 실제 폴더가 어긋나면, 없는 것을 부르거나 있는 것을 모른다.
# 둘 다 조용히 일어난다. repo-setup 본문의 표에 적힌 이름과 실제 폴더를 대조한다.
if python3 - "$R" <<'ROUTE'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
body = (root / "plugin/skills/repo-setup/SKILL.md").read_text(encoding="utf-8")
listed = set(re.findall(r"^\| `([a-z][a-z0-9-]*)` \|", body, re.M))
actual = {d.name for d in (root / "plugin/skills").iterdir() if d.is_dir()} - {"repo-setup"}
assert listed, "repo-setup 본문에 좁은 스킬 표가 없다"
assert listed == actual, f"repo-setup 이 적은 목록 {sorted(listed)} 와 실제 스킬 {sorted(actual)} 이 다르다"
ROUTE
then ok "repo-setup 이 적은 좁은 스킬 목록이 실제와 같다"
else bad "repo-setup 의 좁은 스킬 표가 실제와 다르다. 표를 고쳐라"; fi

# npx skills 는 마켓플레이스의 source 아래 skills/ 를 탐색 경로에 더한다(CLI 1.7.0 의
# getPluginSkillPaths). 스킬을 그 밖으로 옮기면 Claude Code 에서는 계속 동작하면서
# 다른 에이전트에서만 조용히 사라진다.
if python3 - "$R" <<'DISC'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
man = json.loads((root / ".claude-plugin/marketplace.json").read_text(encoding="utf-8"))
found = []
for p in man.get("plugins", []):
    src = p.get("source", "")
    assert not src.startswith("/") and ".." not in src, f"source 가 상대 경로가 아니다: {src!r}"
    d = root / src / "skills"
    assert d.is_dir(), f"{src}/skills 가 없다. npx skills 는 이 경로를 본다"
    found += [x.name for x in d.iterdir() if (x / "SKILL.md").is_file()]
assert found, "마켓플레이스의 source 아래 skills/ 에 스킬이 없다"
DISC
then ok "npx skills 가 매니페스트로 찾는 경로에 스킬이 있다"
else bad "npx skills 가 스킬을 못 찾는 배치다. 마켓플레이스 source 아래 skills/ 로 되돌려라"; fi

# disable-model-invocation 을 모르는 에이전트에게는 description 이 스킬을 고르는 유일한 신호다.
# 한국어만 적으면 그 에이전트에서는 깔려 있어도 선택되지 않는다.
if python3 - "$R" <<'DESC'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
bad = []
for d in sorted((root / "plugin/skills").iterdir()):
    if not d.is_dir():
        continue
    m = re.search(r"^description: (.+)$", (d / "SKILL.md").read_text(encoding="utf-8"), re.M)
    if not m:
        bad.append(f"{d.name}(description 없음)")
        continue
    desc = m.group(1)
    if not re.search(r"[가-힣]", desc):
        bad.append(f"{d.name}(한국어 없음)")
    if re.search(r"[가-힣]", desc[:40]):
        bad.append(f"{d.name}(영어 문장으로 시작하지 않음)")
assert not bad, "영어와 한국어를 함께 적지 않은 스킬: " + ", ".join(bad)
DESC
then ok "모든 스킬의 description 이 영어와 한국어를 함께 적는다"
else bad "description 이 영어와 한국어를 함께 적지 않는다"; fi

# Claude Code 는 인자 자리표시자를 치환하지만 다른 에이전트는 치환하지 않아 글자가 그대로 남는다.
# 폴백 문장이 없으면 그 에이전트에서 스킬이 자리표시자를 값으로 착각한다.
# 폴백 문장 안에 자리표시자를 다시 쓰면 그것까지 치환되므로 '달러 기호' 로 풀어 가리킨다.
if python3 - "$R" <<'ARGS'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
token = "$" + "ARGUMENTS"
bad = []
for d in sorted((root / "plugin/skills").iterdir()):
    if not d.is_dir():
        continue
    body = (d / "SKILL.md").read_text(encoding="utf-8")
    if token in body and "달러 기호" not in body:
        bad.append(d.name)
assert not bad, "자리표시자를 쓰면서 치환 실패 폴백이 없는 스킬: " + ", ".join(bad)
ARGS
then ok "자리표시자를 쓰는 스킬에 치환 실패 폴백이 있다"
else bad "자리표시자가 치환되지 않는 에이전트에서 깨진다. 폴백 문장을 넣어라"; fi

# npx skills 는 스킬 폴더만 복사한다. 부모 폴더를 가리키면 깐 쪽에서 파일을 못 찾고,
# 그 사실이 설치 시점에는 드러나지 않는다.
if python3 - "$R" <<'SELF'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
bad = [d.name for d in sorted((root / "plugin/skills").iterdir())
       if d.is_dir() and "../" in (d / "SKILL.md").read_text(encoding="utf-8")]
assert not bad, "부모 폴더를 가리키는 스킬: " + ", ".join(bad)
SELF
then ok "스킬 본문이 자기 폴더 밖을 가리키지 않는다"
else bad "스킬이 부모 폴더를 가리킨다. 깐 쪽에서는 그 파일이 없다"; fi

# 매니페스트 둘의 description 은 같은 문장을 복제한 것이라 한쪽만 고치면 조용히 어긋난다.
# 설명이 스킬을 열거하면 스킬을 더할 때마다 낡는다. 낡은 문장은
# `claude plugin details` 에만 드러나서 아무도 보지 않는다. 그래서 이름을 아예 금한다.
if python3 - "$R" <<'MAN'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
mk = json.loads((root / ".claude-plugin/marketplace.json").read_text(encoding="utf-8"))
pl = json.loads((root / "plugin/.claude-plugin/plugin.json").read_text(encoding="utf-8"))
names = {d.name for d in (root / "plugin/skills").iterdir() if d.is_dir()}
descs = [("marketplace.plugins[0]", mk["plugins"][0]["description"]),
         ("marketplace", mk["description"]),
         ("plugin.json", pl["description"])]
first = descs[0][1]
for where, d in descs[1:]:
    assert d == first, f"{where} 의 description 이 marketplace.plugins[0] 과 다르다"
for where, d in descs:
    for n in sorted(names):
        assert n not in d, f"{where} 가 스킬 이름 '{n}' 을 적었다. 열거하는 문장은 반드시 낡는다"
MAN
then ok "매니페스트 description 이 서로 같고 스킬을 열거하지 않는다"
else bad "매니페스트 description 이 어긋났거나 스킬을 열거한다"; fi

# 템플릿에 실행 비트가 없으면 깐 사람이 첫 줄에서 멈춘다.
# npx skills 는 스킬 폴더를 통째로 가져가며 실행 비트를 보존한다(CLI 1.7.0, 2026-09-22 실측).
TPL="$R/plugin/skills/repo-privacy/templates"
for t in pre-commit setup.sh; do
  if [ -x "$TPL/$t" ]; then ok "스킬의 templates/${t} 에 실행 비트가 있다"
  else bad "스킬의 templates/${t} 가 없거나 실행 비트가 없다"; fi
done

# 저장소 루트의 가드는 템플릿의 사본이다. 어긋나면 이 저장소가 배포하는 것과
# 스스로 쓰는 것이 달라지고, 그 사실이 겉으로 드러나지 않는다.
for pair in ".githooks/pre-commit:pre-commit" "setup.sh:setup.sh"; do
  copy="${pair%%:*}"; src="${pair##*:}"
  if [ -f "$R/$copy" ] && diff -q "$R/$copy" "$TPL/$src" >/dev/null 2>&1; then ok "${copy} 가 템플릿과 같다"
  else bad "${copy} 가 템플릿과 다르다. 템플릿에서 다시 복사해라"; fi
done

# 템플릿을 본문에 다시 인용하면 정본이 둘이 되어 한쪽이 낡는다.
# 파일로 두는 편이 부르는 비용도 낮다.
if python3 - "$R" <<'QUOTE'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
bad = []
for d in sorted((root / "plugin/skills").iterdir()):
    if not d.is_dir() or not (d / "templates").is_dir():
        continue
    body = (d / "SKILL.md").read_text(encoding="utf-8")
    for t in sorted((d / "templates").iterdir()):
        if not t.is_file():
            continue
        head = "\n".join(t.read_text(encoding="utf-8").splitlines()[:8])
        if head and head in body:
            bad.append(f"{d.name}/{t.name}")
assert not bad, "본문이 템플릿을 그대로 인용한다: " + ", ".join(bad)
QUOTE
then ok "스킬 본문이 템플릿을 다시 인용하지 않는다"
else bad "템플릿이 본문과 파일 둘로 나뉘었다. 본문의 인용을 지워라"; fi

# 훅 템플릿에 특정 저장소의 폴더 이름이 박히면 남의 저장소에서 무의미한 줄이 된다.
case_line=$(grep -n '\.private/\*)' "$TPL/pre-commit" | head -1 | cut -d: -f2- | tr -d ' ')
if [ "$case_line" = ".private/*)" ]; then ok "훅 템플릿의 경로 목록이 저장소를 가리지 않는다"
else bad "훅 템플릿의 기본 경로 목록이 '.private/*' 하나가 아니다: ${case_line}"; fi

# 개인 패턴이 저장소에 새어 들어가면 안 된다. 이 저장소가 다루는 주제가 바로 그것이다.
if git -C "$R" ls-files 2>/dev/null | grep -q .; then
  leak=$(git -C "$R" grep -lE '/Users/[A-Za-z]|/home/[A-Za-z]' -- . 2>/dev/null | grep -v '^plugin/skills/[a-z-]*/templates/' | grep -v '^tests/' || true)
  if [ -z "$leak" ]; then ok "추적 파일에 홈 경로가 없다"
  else bad "홈 경로가 든 파일이 있다"; printf '%s\n' "$leak" | sed 's/^/    /'; fi
else
  ok "추적 파일이 아직 없어 홈 경로 검사를 건너뛴다"
fi

echo
if [ "$fail" -eq 0 ]; then echo "전부 통과"; else echo "실패 ${fail}건"; fi
exit "$fail"
