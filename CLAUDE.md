# repo-setup

용도에 맞게 git 저장소를 세팅하는 커맨드다. 스킬은 `repo-setup` 하나이고, 실측해 해당하는 목적만 골라 그 목적의
절차 문서를 따른다. 목적은 `privacy`(개인 정보 가드), `license`(라이선스), `ci`(테스트 워크플로),
`secure`(호스트 보안 층), `contrib`(협업 준비) 다섯이고, 각각 `plugin/skills/repo-setup/<목적>/` 폴더다.
구현된 기능의 설명은 `docs/wiki/` 에, 각 목적의 경계와 설계 결정의 이유는 `docs/adr/` 에 있다.

## 검사 명령

- `tests/guard/unit.sh` — 훅 27건. 패턴 출처 세 곳이 합쳐지는지, 팀 패턴 파일이 자기 자신을 막지 않는지,
  한글·공백 이름과 스테이징한 뒤 지운 파일도 검사하는지, 읽지 못하는 패턴이 가드를 끄지 않는지 본다.
- `tests/setup/unit.sh` — 활성화 스크립트 37건. 남이 잡은 `core.hooksPath` 와 `.git/hooks` 의 훅을 덮지 않는지,
  `--verify` 가 커밋을 만들지 않고 가드가 막는지를 가려내는지 본다.
- `tests/license/unit.sh` — 라이선스 대조기 24건. 알아보지 못한 본문에 이름을 붙이지 않는지 본다.
- `tests/contrib/unit.sh` — 협업 파일 검사기와 골격 다섯 개 25건. GitHub 이 보는 자리를 모두
  훑는지, 빈 ISSUE_TEMPLATE 폴더를 있는 것으로 보지 않는지 본다.
- `tests/secure/unit.sh` — 워크플로 보안 검사기와 골격 두 개 25건. 태그 참조를 고정으로 보지
  않는지, 스스로 놓는 골격이 태그를 쓰지 않는지 본다.
- `tests/ci/unit.sh` — 테스트 명령 실측기와 워크플로 골격 21건. `npm` 의 기본 자리표시자를
  테스트로 보지 않는지, 골격이 쓰기 권한을 주지 않는지 본다.
- `tests/invariants.sh` — 매니페스트, 폴더명과 `name` 일치, 스킬 수 1, 진입점의 목적 표와 목적 폴더·
  `PROCEDURE.md` 대조, 절차 문서의 카드 형식, `npx skills` 탐색 경로, `description` 병기, 자리표시자, 스킬 폴더 밖 참조,
  절차 문서가 가리키는 파일, 매니페스트 description 대조, 실행 비트, 사본 일치, 템플릿 인용 대조,
  wiki 페이지와 목차, wiki 의 경로와 ADR 링크, ADR 목록, 홈 경로 23건.  **합계 182건.**
- `shellcheck -x -s bash plugin/skills/repo-setup/*/scripts/*.sh plugin/skills/repo-setup/privacy/templates/setup script/setup .githooks/* tests/*.sh tests/*/*.sh`
- `.github/workflows/test.yml` 이 PR 과 main 푸시마다 위 테스트와 shellcheck 를 ubuntu 와 macOS 에서
  돌린다. 테스트 목록은 `.check.toml` 의 `test_command` 를 읽으므로 따로 고치지 않는다.
  **shellcheck 줄을 고치면 워크플로의 같은 줄도 고친다.**

## 규칙

- **훅이나 `script/setup` 을 고치면 테스트를 먼저 쓴다.** RED 를 보고 나서 구현한다.
- **정본은 목적 폴더의 `templates/` 와 `scripts/` 다.** `templates/` 는 대상 저장소로 복사하는 파일이고
  `scripts/` 는 스킬 폴더에서 그대로 실행하는 파일이다. `npx skills` 가 스킬 폴더를 통째로 가져가므로 그
  안에 두면 깐 쪽까지 따라간다. **`SKILL.md` 나 `PROCEDURE.md` 에 옮겨 적지 않는다.** 정본이 둘이 되면 한쪽이 낡고,
  `tests/invariants.sh` 가 그 인용을 잡는다.
- 저장소 루트의 `.githooks/pre-commit` 과 `script/setup` 은 **이 저장소 자신에게 건 가드**다.
  `privacy/templates/` 에서 복사한 사본이라 내용이 같고, `tests/invariants.sh` 가 어긋남을 잡는다. `git config core.hooksPath .githooks` 로 켠다.
- **커밋에 개인 정보를 넣지 않는다.** 이 저장소가 다루는 주제가 그것이다.
- **목적을 더하거나 빼면 진입점 `SKILL.md` 의 목적 표, 목적 폴더와 그 `PROCEDURE.md`, `docs/wiki/<목적>.md`
  를 함께 고친다.** 표와 실제가 어긋나면 없는 것을 읽으려 하거나 있는 것을 모르게 되고, 둘 다 조용히
  일어난다. `tests/invariants.sh` 가 세 곳의 일치를 본다.
- **스킬을 다시 나누지 않는다.** 스킬은 `repo-setup` 하나다. 목적을 스킬로 나누면 `disable-model-invocation`
  이 진입점의 호출을 막는다(`docs/adr/0006-single-skill-with-purpose-folders.md`).
- **스킬은 `plugin/skills/` 에 둔다.** `npx skills` 는 `.claude-plugin/marketplace.json` 의
  `plugins[].source` 를 풀어 그 아래 `skills/` 를 탐색 경로에 더한다(CLI 1.7.0 의
  `getPluginSkillPaths`, 확인일 2026-09-22). 스킬을 그 밖으로 옮기면 Claude Code 에서는 계속
  동작하면서 **다른 에이전트에서만 조용히 사라진다.** `tests/invariants.sh` 가 이 계약을 지킨다.
- **스킬 본문은 자기 폴더만으로 완결되어야 한다.** `npx skills` 는 스킬 폴더만 복사하므로 부모
  폴더를 가리키면 깐 쪽에서 그 파일이 없다. 절차 문서, 스크립트, 템플릿을 모두 스킬 폴더 안에 두는
  이유가 이것이다.
- **설명 카드의 문구는 각 `PROCEDURE.md` 의 첫 절 「카드」에만 둔다.** 진입점 `SKILL.md` 는 칸과 채우는
  규칙만 갖고 문구를 옮겨 적지 않는다. 칸은 무엇, 이유, 바뀌는 것, 겪는 일, 감수할 것, 되돌리기, 건너뛰면
  일곱 개이고 카드는 16줄 이하다. `tests/invariants.sh` 가 이 형식을 본다. 카드에 홈 경로를 글자 그대로
  적지 않는다(가드에 걸린다). 「홈 폴더 아래 runner」처럼 풀어 쓴다.
- **`PROCEDURE.md` 에 인자 자리표시자를 쓰지 않는다.** 절차 문서는 스킬로 불리지 않고 읽히기만 해서
  어느 에이전트에서도 치환되지 않는다. 대상은 「대상 저장소」로 적는다.
- **`description` 에 영어와 한국어를 함께 적는다.** Claude Code 밖의 에이전트는
  `disable-model-invocation` 을 모르므로 `description` 이 스킬을 고르는 유일한 신호다. 본문은
  한국어로 쓰고 「내가 쓰는 언어로 답한다」 줄에 맡긴다.
- **스킬 이름을 바꾸면 매니페스트의 `description` 도 고친다.** 두 매니페스트가 같은 문장을
  복제하고 있어서 한쪽만 고치면 조용히 어긋나고, 낡은 이름은 `claude plugin details` 에만
  드러난다. `tests/invariants.sh` 가 두 매니페스트의 일치와 괄호 안 스킬 이름을 본다.
- 커밋 메시지는 `type(scope): 요약` 형식이고 본문에 무엇을 왜 바꿨는지 적는다.

## 구조

**저장소는 두 층이다.** `plugin/` 만 사용자에게 실린다. 공식 마켓플레이스와 did-you-check 이 같은 방식이다
(`source: "./plugin"`). 플러그인 설치는 폴더를 통째로 복사하고 제외 방법이 없다.
**테스트·템플릿·문서를 `plugin/` 안에 두지 않는다.**

- `plugin/skills/repo-setup/SKILL.md` — 유일한 스킬이자 진입점. 실측하고 목적을 고르고 절차 문서를 따르고
  보고한다. **절차 문서에 없는 세팅은 하지 않는다.**
- `plugin/skills/repo-setup/<목적>/PROCEDURE.md` — 목적마다의 절차.
- `plugin/skills/repo-setup/privacy/templates/` — 훅과 설정 스크립트. 대상 저장소의 `.githooks/pre-commit` 과
  `script/setup` 이 된다. 이 저장소 루트의 사본도 여기서 온다.
- `plugin/skills/repo-setup/license/scripts/` — 선언 대조기.
- `plugin/skills/repo-setup/ci/scripts/` · `templates/` — 테스트 명령 실측기와 워크플로 골격.
- `plugin/skills/repo-setup/secure/scripts/` · `templates/` — 워크플로 보안 검사기와 골격 두 개.
- `plugin/skills/repo-setup/contrib/scripts/` · `templates/` — 협업 파일 검사기와 문서 골격 다섯 개.
- `script/setup` — 이 저장소의 가드를 켠다. `privacy/templates/setup` 의 사본이다.
- `tests/` — 위 검사 명령.
- `docs/wiki/` — 구현된 기능이 무엇을 하고 어떻게 동작하는지. 기능을 바꾸는 PR 은 그 기능의 페이지를
  같은 PR 에서 고친다. 이유는 쓰지 않고 ADR 을 링크한다.
- `docs/adr/` — 설계 결정마다 파일 한 개(`NNNN-<영어-kebab-slug>.md`). 왜 그렇게 정했는지만 적고,
  선택 조건이나 순서 같은 실행 규칙은 `SKILL.md` 에만 둔다. 뒤집힌 결정은 지우지 않고 상태를 바꾼다.

## 주의

- **중괄호 없는 변수 뒤에 한글을 붙이지 않는다.** `"$n개"` 는 bash 가 `n개` 를 변수 이름으로 읽고
  `set -u` 아래서 죽는다. `${n}개` 로 쓴다.
- **팀 패턴 파일은 내용 검사에서 뺀다.** 막으려는 문자열을 자신이 품고 있어서, 빼지 않으면
  그 파일 자신을 커밋하지 못해 팀에 전달할 방법이 없어진다.
