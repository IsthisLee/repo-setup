#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 이 저장소가 스스로 지켜야 하는 불변식. 조용히 어긋나는 것들이라 사람이 눈으로 볼 수 없다.
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
R="$(cd "$(dirname "$0")/.." && pwd)"
SK="$R/plugin/skills/repo-setup"
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

# 스킬은 repo-setup 하나이고 목적은 그 안의 폴더다. 스킬을 다시 나누면 진입점이
# disable-model-invocation 이 걸린 스킬을 부를 수 없는 문제가 되살아난다.
n_sk=$(find "$R/plugin/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
if [ "$n_sk" = 1 ] && [ -f "$SK/SKILL.md" ]; then ok "스킬이 repo-setup 하나다"
else bad "스킬이 repo-setup 하나가 아니다(${n_sk}개). 목적은 repo-setup 안의 폴더로 둔다"; fi

# 진입점이 고를 목적 목록과 실제 폴더가 어긋나면, 없는 것을 읽으려 하거나 있는 것을 모른다.
# 둘 다 조용히 일어난다. 진입점 표의 첫 칸과 목적 폴더를 대조하고, 폴더마다 절차 문서가 있는지 본다.
if python3 - "$SK" <<'ROUTE'
import pathlib, re, sys
sk = pathlib.Path(sys.argv[1])
body = (sk / "SKILL.md").read_text(encoding="utf-8")
listed = set(re.findall(r"^\| `([a-z][a-z0-9-]*)` \|", body, re.M))
actual = {d.name for d in sk.iterdir() if d.is_dir()}
assert listed, "진입점 본문에 목적 표가 없다"
assert listed == actual, f"진입점이 적은 목적 {sorted(listed)} 와 실제 폴더 {sorted(actual)} 가 다르다"
missing = sorted(d for d in actual if not (sk / d / "PROCEDURE.md").is_file())
assert not missing, "PROCEDURE.md 가 없는 목적: " + ", ".join(missing)
ROUTE
then ok "진입점의 목적 표가 목적 폴더와 같고 폴더마다 PROCEDURE.md 가 있다"
else bad "진입점의 목적 표가 실제와 다르거나 PROCEDURE.md 가 빠졌다"; fi

# 진입점은 목적을 고르기 전에 절차 문서의 카드에 실측값을 채워 보인다. 칸이 빠지면 사람이 그것을
# 모른 채 동의하고, 카드가 길어지면 읽히지 않는다. 카드는 절차 문서의 첫 절이고 일곱 칸을 이 순서로 둔다.
if python3 - "$SK" <<'CARD'
import pathlib, re, sys
sk = pathlib.Path(sys.argv[1])
labels = ["무엇", "이유", "바뀌는 것", "겪는 일", "감수할 것", "되돌리기", "건너뛰면"]
bad = []
for proc in sorted(sk.glob("*/PROCEDURE.md")):
    name = proc.parent.name
    text = proc.read_text(encoding="utf-8")
    sections = re.findall(r"^## (.+)$", text, re.M)
    if not sections or sections[0] != "카드":
        bad.append(f"{name}(첫 절이 「카드」가 아니다)"); continue
    body = text.split("\n## 카드\n", 1)[1].split("\n## ", 1)[0]
    m = re.search(r"^```text\n(.*?)^```$", body, re.M | re.S)
    if not m:
        bad.append(f"{name}(카드 코드 블록이 없다)"); continue
    lines = m.group(1).rstrip("\n").split("\n")
    found = [re.match(r"^(\d)\. ([^:]+):", l) for l in lines]
    got = [(f.group(1), f.group(2)) for f in found if f]
    want = [(str(i + 1), l) for i, l in enumerate(labels)]
    if got != want:
        bad.append(f"{name}(칸이 {[g[1] for g in got]})")
    if len(lines) > 16:
        bad.append(f"{name}(카드가 {len(lines)}줄)")
assert not bad, "카드가 규칙과 다르다: " + ", ".join(bad)
CARD
then ok "절차 문서마다 첫 절이 일곱 칸을 갖춘 16줄 이하의 카드다"
else bad "절차 문서의 카드가 빠졌거나 칸이 다르다"; fi

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
# PROCEDURE.md 는 스킬로 불리지 않고 읽히기만 하므로 어느 에이전트에서도 치환되지 않는다.
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
        bad.append(f"{d.name}/SKILL.md(폴백 없음)")
    for proc in sorted(d.glob("*/PROCEDURE.md")):
        if token in proc.read_text(encoding="utf-8"):
            bad.append(f"{d.name}/{proc.parent.name}/PROCEDURE.md(치환되지 않는 자리표시자)")
assert not bad, "자리표시자가 치환되지 않는 곳: " + ", ".join(bad)
ARGS
then ok "자리표시자는 폴백이 있는 SKILL.md 에만 있다"
else bad "자리표시자가 치환되지 않는 에이전트나 문서에서 깨진다"; fi

# npx skills 는 스킬 폴더만 복사한다. 부모 폴더나 이 저장소의 docs/ 를 가리키면 깐 쪽에서 파일을
# 못 찾고, 그 사실이 설치 시점에는 드러나지 않는다. docs/ 는 대상 저장소의 docs/ 와 구별하려고
# 이 저장소에만 있는 하위 폴더 이름으로 본다.
if python3 - "$R" <<'SELF'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
bad = []
for f in sorted((root / "plugin/skills").rglob("*.md")):
    text = f.read_text(encoding="utf-8")
    rel = f.relative_to(root / "plugin/skills")
    if "../" in text:
        bad.append(f"{rel}(../)")
    if re.search(r"docs/(adr|wiki|decisions)", text):
        bad.append(f"{rel}(이 저장소의 docs/)")
assert not bad, "스킬 폴더 밖을 가리키는 문서: " + ", ".join(bad)
SELF
then ok "스킬 문서가 자기 폴더 밖을 가리키지 않는다"
else bad "스킬 문서가 폴더 밖을 가리킨다. 깐 쪽에서는 그 파일이 없다"; fi

# 절차 문서가 스크립트나 템플릿을 이름으로 가리키는데 그 파일이 없으면, 그 단계에서야 멈춘다.
# 경로는 스킬 폴더 기준 <목적>/(scripts|templates)/… 로 적는다.
if python3 - "$SK" <<'REFS'
import pathlib, re, sys
sk = pathlib.Path(sys.argv[1])
purposes = "|".join(sorted(d.name for d in sk.iterdir() if d.is_dir()))
pat = re.compile(rf"(?<![\w.-])((?:{purposes})/(?:scripts|templates)/[\w./-]*\w)")
bad = []
docs = [sk / "SKILL.md", *sorted(sk.glob("*/PROCEDURE.md"))]
for doc in docs:
    for p in pat.findall(doc.read_text(encoding="utf-8")):
        if not (sk / p).exists():
            bad.append(f"{doc.relative_to(sk)}: {p}")
assert not bad, "가리키는 파일이 없다: " + ", ".join(bad)
n = sum(len(pat.findall(d.read_text(encoding="utf-8"))) for d in docs)
assert n, "절차 문서가 스크립트나 템플릿을 하나도 가리키지 않는다. 경로 형식이 바뀌었는지 봐라"
REFS
then ok "절차 문서가 가리키는 스크립트와 템플릿이 모두 있다"
else bad "절차 문서가 없는 파일을 가리킨다"; fi

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

# 스크립트와 훅 템플릿에 실행 비트가 없으면 깐 사람이 첫 줄에서 멈춘다.
# npx skills 는 스킬 폴더를 통째로 가져가며 실행 비트를 보존한다(CLI 1.7.0, 2026-09-22 실측).
TPL="$SK/privacy/templates"
noexec=""
for f in "$SK"/*/scripts/*.sh "$TPL/pre-commit" "$TPL/setup"; do
  [ -x "$f" ] || noexec="$noexec ${f#"$SK"/}"
done
if [ -z "$noexec" ]; then ok "스크립트와 훅 템플릿에 실행 비트가 있다"
else bad "실행 비트가 없거나 파일이 없다:$noexec"; fi

# 저장소 루트의 가드는 템플릿의 사본이다. 어긋나면 이 저장소가 배포하는 것과
# 스스로 쓰는 것이 달라지고, 그 사실이 겉으로 드러나지 않는다.
for pair in ".githooks/pre-commit:pre-commit" "script/setup:setup"; do
  copy="${pair%%:*}"; src="${pair##*:}"
  if [ -f "$R/$copy" ] && diff -q "$R/$copy" "$TPL/$src" >/dev/null 2>&1; then ok "${copy} 가 템플릿과 같다"
  else bad "${copy} 가 템플릿과 다르다. 템플릿에서 다시 복사해라"; fi
done

# 템플릿을 본문에 다시 인용하면 정본이 둘이 되어 한쪽이 낡는다.
# 파일로 두는 편이 부르는 비용도 낮다.
if python3 - "$SK" <<'QUOTE'
import pathlib, sys
sk = pathlib.Path(sys.argv[1])
body = "\n".join(p.read_text(encoding="utf-8") for p in [sk / "SKILL.md", *sorted(sk.glob("*/PROCEDURE.md"))])
bad = []
for t in sorted(sk.glob("*/templates/**/*")) + sorted(sk.glob("*/scripts/*")):
    if not t.is_file():
        continue
    head = "\n".join(t.read_text(encoding="utf-8").splitlines()[:8])
    if head and head in body:
        bad.append(str(t.relative_to(sk)))
assert not bad, "본문이 템플릿을 그대로 인용한다: " + ", ".join(bad)
QUOTE
then ok "스킬 본문이 템플릿을 다시 인용하지 않는다"
else bad "템플릿이 본문과 파일 둘로 나뉘었다. 본문의 인용을 지워라"; fi

# 훅 템플릿에 특정 저장소의 폴더 이름이 박히면 남의 저장소에서 무의미한 줄이 된다.
case_line=$(grep -n '\.private/\*)' "$TPL/pre-commit" | head -1 | cut -d: -f2- | tr -d ' ')
if [ "$case_line" = ".private/*)" ]; then ok "훅 템플릿의 경로 목록이 저장소를 가리지 않는다"
else bad "훅 템플릿의 기본 경로 목록이 '.private/*' 하나가 아니다: ${case_line}"; fi

# 문서는 README(무엇·설치), docs/wiki(구현된 기능), docs/adr(이유)로 나뉜다.
# 목적을 더하고 wiki 페이지를 빠뜨리거나 목차에 올리지 않으면, 그 기능의 설명이 조용히 사라진다.
# 목적 이름은 목적 폴더에서 읽는다. 목록을 여기에 적으면 목적을 더할 때 이 검사도 낡는다.
if python3 - "$R" <<'WIKI'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
wiki = root / "docs/wiki"
purposes = {d.name for d in (root / "plugin/skills/repo-setup").iterdir() if d.is_dir()}
missing = sorted(p for p in purposes if not (wiki / f"{p}.md").is_file())
assert not missing, "wiki 페이지가 없는 목적: " + ", ".join(missing)
index = (wiki / "README.md").read_text(encoding="utf-8")
linked = set(re.findall(r"\]\(([^)#\s]+\.md)\)", index))
pages = {p.name for p in wiki.glob("*.md") if p.name != "README.md"}
unlisted = sorted(pages - linked)
assert not unlisted, "docs/wiki/README.md 가 가리키지 않는 페이지: " + ", ".join(unlisted)
WIKI
then ok "목적마다 wiki 페이지가 있고 목차가 모든 페이지를 가리킨다"
else bad "wiki 페이지가 빠졌거나 목차에 없다"; fi

# wiki 는 구현된 것을 설명하므로 파일을 옮기면 경로가 먼저 낡는다. 낡은 경로는 링크가 아니라
# 백틱 안의 글자라서 아무것도 깨지지 않는다. 글롭은 하나라도 맞으면 있는 것으로 본다.
# .githooks/ 와 .github/ 는 보지 않는다. 대상 저장소에 놓일 경로(.githooks/team-patterns 등)와
# 글자만으로 갈리지 않아서, 보면 맞는 설명이 실패한다.
if python3 - "$R" <<'WPATH'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
bad = []
for page in sorted((root / "docs/wiki").glob("*.md")):
    for p in re.findall(r"`((?:plugin|tests|docs)/[^`\s<>{}]*)`", page.read_text(encoding="utf-8")):
        found = any(root.glob(p.rstrip("/"))) if "*" in p else (root / p).exists()
        if not found:
            bad.append(f"{page.name}: {p}")
assert not bad, "wiki 가 가리키는 경로가 없다: " + ", ".join(bad)
WPATH
then ok "wiki 가 적은 저장소 경로가 모두 있다"
else bad "wiki 에 없는 경로가 적혀 있다. 옮긴 파일의 새 경로로 고쳐라"; fi

# wiki 는 이유를 쓰지 않고 ADR 을 링크한다. 링크가 끊기면 이유가 사라진 설명만 남는다.
if python3 - "$R" <<'WADR'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
adr = root / "docs/adr"
bad = []
for page in sorted((root / "docs/wiki").glob("*.md")):
    text = page.read_text(encoding="utf-8")
    for link in re.findall(r"\]\((\.\./adr/[^)#\s]+)\)", text):
        if not (page.parent / link).resolve().is_file():
            bad.append(f"{page.name}: {link}")
    for num in re.findall(r"ADR (\d{4})", text):
        if not list(adr.glob(f"{num}-*.md")):
            bad.append(f"{page.name}: ADR {num}")
assert not bad, "wiki 가 가리키는 ADR 이 없다: " + ", ".join(bad)
WADR
then ok "wiki 가 가리키는 ADR 이 모두 있다"
else bad "wiki 가 없는 ADR 을 가리킨다"; fi

# ADR 은 번호를 다시 쓰지 않고 지우지도 않는다. 목록에서 빠진 ADR 은 아무도 찾지 못한다.
if python3 - "$R" <<'ADRIDX'
import pathlib, re, sys
adr = pathlib.Path(sys.argv[1]) / "docs/adr"
files = sorted(p.name for p in adr.glob("*.md") if p.name != "README.md")
assert files, "docs/adr/ 에 ADR 이 없다"
badname = [f for f in files if not re.fullmatch(r"\d{4}-[a-z0-9]+(?:-[a-z0-9]+)*\.md", f)]
assert not badname, "이름이 NNNN-<영어-kebab-slug>.md 가 아닌 ADR: " + ", ".join(badname)
nums = [f[:4] for f in files]
assert len(nums) == len(set(nums)), "번호가 겹치는 ADR 이 있다: " + ", ".join(files)
linked = set(re.findall(r"\]\(([^)#\s]+\.md)\)", (adr / "README.md").read_text(encoding="utf-8")))
unlisted = [f for f in files if f not in linked]
assert not unlisted, "docs/adr/README.md 가 가리키지 않는 ADR: " + ", ".join(unlisted)
ADRIDX
then ok "ADR 이름이 형식에 맞고 목록이 모든 ADR 을 가리킨다"
else bad "ADR 이름이 형식과 다르거나 목록에서 빠진 ADR 이 있다"; fi

# 개인 패턴이 저장소에 새어 들어가면 안 된다. 이 저장소가 다루는 주제가 바로 그것이다.
# 훅 템플릿과 테스트는 막을 패턴과 탐침을 담고 있어서 뺀다.
if git -C "$R" ls-files 2>/dev/null | grep -q .; then
  leak=$(git -C "$R" grep -lE '/Users/[A-Za-z]|/home/[A-Za-z]' -- . 2>/dev/null | grep -v '^plugin/skills/repo-setup/[a-z]*/templates/' | grep -v '^tests/' || true)
  if [ -z "$leak" ]; then ok "추적 파일에 홈 경로가 없다"
  else bad "홈 경로가 든 파일이 있다"; printf '%s\n' "$leak" | sed 's/^/    /'; fi
else
  ok "추적 파일이 아직 없어 홈 경로 검사를 건너뛴다"
fi

echo
if [ "$fail" -eq 0 ]; then echo "전부 통과"; else echo "실패 ${fail}건"; fi
exit "$fail"
