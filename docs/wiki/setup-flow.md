# 진입점 흐름 (setup-flow)

스킬 `repo-setup` 이 맡는다. 실측 명령, 고르는 조건, 호출 순서는 `plugin/skills/repo-setup/SKILL.md` 에 있다.

## 하는 일

진입점이 저장소를 실측하고, 해당하는 목적만 골라, 그 목적의 절차를 순서대로 따르고, **무엇을 했고
무엇을 왜 건너뛰었는지** 보고한다. 절차 문서에 없는 세팅은 하지 않는다.

## 동작

네 축을 실측한다. **추측하지 않는다.** 여기에 기본 브랜치, 작업 트리 상태, 활동량(열린 PR 수, 최근 30일
커밋 수, 기존 워크플로 수)을 더 잰다.

| 축 | 무엇이 갈리나 |
|---|---|
| 공개 / 비공개 | 공개면 홈 경로·이메일이 실제 위험. 비공개면 자격증명 쪽이 우선 |
| 개인 / 팀 | **팀이면 파일 변경은 확인을 받은 뒤 PR 로 올리고, GitHub 설정은 계획만 보인다** |
| 호스트 | GitHub · GitLab · Bitbucket · 없음. 서버 층 명령이 갈린다 |
| 기존 도구 | 이미 깔린 훅 관리자와 설정. 덮어쓰지 않고 얹는다 |

판별이 안 되면 **팀 저장소이고 공개라고 간주한다.** 모르는 쪽에서 안전한 선택이다.

목록에 없는 세팅이 필요하면 즉흥으로 만들지 않고 그 사실을 보고한다. 근거도 테스트도 없는 세팅이
들어가는 것보다 낫다.

### 목적과 절차 문서

목적 다섯 개는 스킬 `repo-setup` 안의 폴더다(`plugin/skills/repo-setup/privacy/` 등). 진입점은 고른 목적의
`PROCEDURE.md` 를 읽어 그 단계를 따르고, 절차 문서가 가리키는 `scripts/` 의 스크립트는 스킬 폴더에서 그대로
실행하며 `templates/` 의 파일은 대상 저장소로 복사한다. `/repo-setup:repo-setup license` 처럼 목적 이름
하나를 인자로 주면 그 목적만 돈다. 이때도 공통 실측은 한다.

### 확인 흐름

확인은 두 번 받는다.

1. 실측 결과를 보이고, 목적마다 설명 카드를 보인 뒤 적용할 목적을 고르게 한다. 카드는 무엇, 이유, 바뀌는
   것, 겪는 일, 감수할 것, 되돌리기, 건너뛰면의 일곱 칸이고, 문구는 각 목적의 `PROCEDURE.md` 「카드」 절에
   있다. 진입점은 `{…}` 자리를 실측값으로 채운다. 고르는 조건에 맞지 않는 목적은 이유와 함께 기본으로
   빠져 있다. Claude Code 에서는 로컬 층(`privacy`, `license`, `ci`)과 GitHub 층(`secure`, `contrib`)의 두
   질문으로 묻는다.
2. 고른 목적 안에서 새 파일 쓰기, 기존 파일 고치기, 푸시와 PR, GitHub 설정 바꾸기, 로컬 테스트 실행마다
   무엇을 하는지 보이고 다시 확인받는다.

### 변경 전달

1. 작업 트리에 커밋하지 않은 추적 파일의 변경이 있으면 시작하지 않고 멈춘다.
2. 기본 브랜치의 최신 상태에서 `repo-setup/<날짜>` 브랜치를 만든다. 같은 이름이 있으면 `-2`, `-3` 을 붙인다.
3. 목적마다 커밋 한 개를 만든다. 기존 워크플로를 고치는 변경은 따로 커밋한다.
4. 푸시 직전에 브랜치, 커밋 목록, 이 PR 에서 도는 워크플로, 리뷰 요청이 갈 사람, 병합 뒤 할 일을 보이고
   확인받은 뒤 PR 한 개를 연다. 권한이 `READ`·`TRIAGE` 이거나 푸시가 거절되면 `git format-patch` 로 만든
   패치 파일을 남긴다.
5. 파일과 무관한 GitHub 설정은 확인을 받은 뒤 바로 바꾼다. 브랜치 보호는 세팅 PR 이 병합된 뒤
   `/repo-setup:repo-setup contrib` 를 다시 불러 건다.

### 부르는 방식

**Claude Code 와 그 밖의 에이전트는 호출 방식이 다르다.** 스킬 `repo-setup` 은
`disable-model-invocation: true` 를 달고 있어서 Claude Code 에서는 **사용자만** 부를 수 있다. 다른
에이전트는 이 키를 모르므로 모델이 `description` 을 읽고 스스로 고를 수 있다. 그래서 `description`
에 영어와 한국어를 함께 적었다. 이 차이는 이쪽에서 없앨 수 없다.

## 바꾸는 것

- 대상 저장소에 세팅 브랜치 `repo-setup/<날짜>` 와 PR 한 개가 생긴다. 기본 브랜치에는 직접 커밋하지 않는다.
- 그 밖에 바꾸는 것은 고른 목적의 절차가 정하고, 각 목적 페이지에 있다.

## 한계와 알려진 문제

- 실제 저장소에서 `/repo-setup` 을 처음부터 끝까지 돌려 보는 종단 검증은 아직 하지 않았다. 지금은
  테스트와 불변식이 파일과 경로, 카드의 형식을 지킨다.
- 팀 저장소의 판별과 패치로 물러나는 흐름은 실제 조직 저장소에서 돌려 보지 않았다.
- 카드의 문구 가운데 각 목적의 알려진 문제(예: `contrib` 의 필수 검사 이름)는 그 목적을 고치는 PR 에서 바뀐다.

## 관련 파일

- `plugin/skills/repo-setup/SKILL.md`
- `plugin/skills/repo-setup/privacy/PROCEDURE.md` 등 목적마다의 절차 문서(맨 앞이 「카드」 절)
- `tests/invariants.sh` (진입점의 목적 표와 목적 폴더, 절차 문서의 카드 형식을 대조한다)

## 관련 ADR

- [0006. 한 스킬에 목적별 폴더를 둔다](../adr/0006-single-skill-with-purpose-folders.md)
- [0003. 겹치는 파일과 설정의 소유를 정한다](../adr/0003-ownership-of-overlapping-files.md)
- [0005. 팀 저장소의 공유 자산은 제안만 한다](../adr/0005-team-repos-propose-only.md)
- [0007. 설명 카드로 두 번 확인받고 변경은 브랜치와 PR 로 올린다](../adr/0007-confirm-with-cards-and-deliver-by-pr.md)
- [0011. 팀 저장소에도 파일 변경은 확인 후 PR 로 올리고, 푸시할 수 없으면 패치로 물러난다](../adr/0011-team-repos-file-changes-by-pr.md)

## 확인한 외부 사실

1. **공식 문서**, Claude Code [Skills](https://code.claude.com/docs/en/skills), 2026-09-22 확인.
   "To keep Claude from invoking it through the Skill tool, set `disable-model-invocation: true`."
   (번역: Claude 가 Skill 도구로 그 스킬을 부르지 못하게 하려면 `disable-model-invocation: true` 를 둔다.)
   같은 문서의 표에서 이 설정의 "Claude can invoke" 칸은 "No" 다.
