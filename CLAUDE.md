# repo-setup

용도에 맞게 git 저장소를 세팅하는 커맨드 모음이다. 진입점 `auto` 하나가 실측해 해당하는 것만 고르고 좁은 스킬을 부른다.
좁은 스킬은 지금 `privacy`(개인 정보 가드) 하나다.

## 검사 명령

- `tests/guard/unit.sh` — 훅 12건. 패턴 출처 셋이 합쳐지는지, 팀 패턴 파일이 자기 자신을 막지 않는지 본다.
- `tests/setup/unit.sh` — 활성화 스크립트 14건. 남이 잡은 `core.hooksPath` 를 덮지 않는지 본다.
- `tests/invariants.sh` — 매니페스트, 폴더명과 `name` 일치, 스킬 수, `auto` 의 스킬 표 대조, 템플릿 인용 대조, 실행 비트, 홈 경로 10건.  **합계 36건.**
- `shellcheck -x -s bash templates/* setup.sh .githooks/* tests/*.sh tests/*/*.sh`

## 규칙

- **훅이나 `setup.sh` 를 고치면 테스트를 먼저 쓴다.** RED 를 보고 나서 구현한다.
- **정본은 `templates/` 다.** 스킬은 그 내용을 품고 있고, 어긋나면 `tests/invariants.sh` 가 잡는다.
  템플릿을 고쳤으면 스킬의 인용도 다시 박는다.
- 저장소 루트의 `.githooks/pre-commit` 과 `setup.sh` 는 **이 저장소 자신에게 건 가드**다.
  `templates/` 에서 복사한 사본이라 내용이 같다. `git config core.hooksPath .githooks` 로 켠다.
- **커밋에 개인 정보를 넣지 않는다.** 이 저장소가 다루는 주제가 그것이다.
- **좁은 스킬을 더하거나 빼면 `auto` 의 표와 `tests/invariants.sh` 의 스킬 수를 함께 고친다.**
  표와 실제가 어긋나면 없는 것을 부르거나 있는 것을 모르게 되고, 둘 다 조용히 일어난다.
- 커밋 메시지는 `type(scope): 요약` 형식이고 본문에 무엇을 왜 바꿨는지 적는다.

## 구조

**저장소는 두 층이다.** `plugin/` 만 사용자에게 실린다. 공식 마켓플레이스와 did-you-check 이 같은 방식이다
(`source: "./plugin"`). 플러그인 설치는 폴더를 통째로 복사하고 제외 방법이 없다.
**테스트·템플릿·문서를 `plugin/` 안에 두지 않는다.**

- `templates/pre-commit` · `templates/setup.sh` — 대상 저장소에 복사할 원본. 테스트가 이것을 본다.
- `plugin/skills/auto/SKILL.md` — 진입점. 실측하고 고르고 좁은 스킬을 부르고 보고한다. **세팅을 직접 하지 않는다.**
- `plugin/skills/privacy/SKILL.md` — 좁은 스킬. 템플릿 둘을 본문에 품는다.
- `tests/` — 위 검사 명령.

## 주의

- **중괄호 없는 변수 뒤에 한글을 붙이지 않는다.** `"$n개"` 는 bash 가 `n개` 를 변수 이름으로 읽고
  `set -u` 아래서 죽는다. `${n}개` 로 쓴다.
- **팀 패턴 파일은 내용 검사에서 뺀다.** 막으려는 문자열을 자신이 품고 있어서, 빼지 않으면
  그 파일 자신을 커밋하지 못해 팀에 전달할 방법이 없어진다.
