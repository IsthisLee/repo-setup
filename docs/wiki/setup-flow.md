# 진입점 흐름 (setup-flow)

스킬 `repo-setup` 이 맡는다. 실측 명령, 고르는 조건, 호출 순서는 `plugin/skills/repo-setup/SKILL.md` 에 있다.

## 하는 일

진입점이 저장소를 실측하고, 해당하는 것만 골라, 좁은 스킬을 순서대로 부르고, **무엇을 했고 무엇을 왜
건너뛰었는지** 보고한다. 세팅을 직접 하지 않는다.

## 동작

네 축을 실측한다. **추측하지 않는다.**

| 축 | 무엇이 갈리나 |
|---|---|
| 공개 / 비공개 | 공개면 홈 경로·이메일이 실제 위험. 비공개면 자격증명 쪽이 우선 |
| 개인 / 팀 | **팀이면 공유 자산을 고치지 않고 제안만 한다** |
| 호스트 | GitHub · GitLab · Bitbucket · 없음. 서버 층 명령이 갈린다 |
| 기존 도구 | 이미 깔린 훅 관리자와 설정. 덮어쓰지 않고 얹는다 |

판별이 안 되면 **팀 저장소이고 공개라고 간주한다.** 모르는 쪽에서 안전한 선택이다.

목록에 없는 세팅이 필요하면 즉흥으로 만들지 않고 그 사실을 보고한다. 근거도 테스트도 없는 세팅이
들어가는 것보다 낫다.

### 부르는 방식

**Claude Code 와 그 밖의 에이전트는 호출 방식이 다르다.** 스킬 여섯이 모두
`disable-model-invocation: true` 를 달고 있어서 Claude Code 에서는 **사용자만** 부를 수 있다. 다른
에이전트는 이 키를 모르므로 모델이 `description` 을 읽고 스스로 고를 수 있다. 그래서 `description`
에 영어와 한국어를 함께 적었다. 이 차이는 이쪽에서 없앨 수 없다.

## 바꾸는 것

진입점은 파일과 설정을 직접 바꾸지 않는다. 바꾸는 것은 진입점이 부르는 좁은 스킬의 몫이고, 각
목적 페이지에 있다.

## 한계와 알려진 문제

- **Claude Code 에서는 진입점이 좁은 스킬을 부르지 못한다.** 좁은 스킬 다섯이 모두
  `disable-model-invocation: true` 이고, 이 설정은 Skill 도구로 부르는 것까지 막는다(아래 확인한
  외부 사실). 그래서 진입점 본문의 「좁은 스킬을 호출한다」 단계는 Claude Code 에서 동작하지 않는다.

## 관련 파일

- `plugin/skills/repo-setup/SKILL.md`
- `tests/invariants.sh` (진입점의 스킬 표와 실제 스킬 폴더를 대조한다)

## 관련 ADR

- [0002. 목적별로 좁은 스킬 다섯을 둔다](../adr/0002-five-narrow-skills-by-purpose.md)
- [0003. 겹치는 파일과 설정의 소유를 정한다](../adr/0003-ownership-of-overlapping-files.md)
- [0005. 팀 저장소의 공유 자산은 제안만 한다](../adr/0005-team-repos-propose-only.md)

## 확인한 외부 사실

1. **공식 문서**, Claude Code [Skills](https://code.claude.com/docs/en/skills), 2026-09-22 확인.
   "To keep Claude from invoking it through the Skill tool, set `disable-model-invocation: true`."
   (번역: Claude 가 Skill 도구로 그 스킬을 부르지 못하게 하려면 `disable-model-invocation: true` 를 둔다.)
   같은 문서의 표에서 이 설정의 "Claude can invoke" 칸은 "No" 다.
