# 0006. 한 스킬에 목적별 폴더를 둔다

- 상태: 승인 (2026-09-22)

## 맥락

[0002](0002-five-narrow-skills-by-purpose.md) 는 목적마다 좁은 스킬을 하나씩 두고, 진입점 `repo-setup` 이
그 스킬들을 순서대로 부르게 했다. 여섯 스킬은 모두 `disable-model-invocation: true` 를 달았다. 라이선스를
박거나 GitHub 설정을 바꾸는 것처럼 부작용이 있는 일을 모델이 스스로 시작하지 않게 하려는 것이었다.

그런데 이 설정은 사용자가 아닌 모델이 Skill 도구로 부르는 것까지 막는다. Claude Code 의
[Skills](https://code.claude.com/docs/en/skills) 문서(2026-09-22 확인)는 이렇게 적는다.

> "To keep Claude from invoking it through the Skill tool, set `disable-model-invocation: true`."
>
> 번역: Claude 가 Skill 도구로 그 스킬을 부르지 못하게 하려면 `disable-model-invocation: true` 를 둔다.

그래서 진입점의 「좁은 스킬을 호출한다」 단계는 Claude Code 에서 동작하지 않았다. 또 좁은 스킬마다
`templates/` 한 폴더에 대상 저장소로 복사할 파일과 스킬 폴더에서 실행할 스크립트가 섞여 있어서, 스크립트를
대상 저장소 루트에서 `bash templates/x.sh` 로 돌리라는 틀린 안내가 본문에 들어갔다.

## 결정

스킬로는 `repo-setup` 만 남기고 `disable-model-invocation: true` 를 유지한다. 다섯 목적은 그 스킬 폴더
안의 폴더가 되고, 폴더마다 절차 문서 `PROCEDURE.md` 를 둔다. 진입점은 고른 목적의 절차 문서를 읽어 따른다.
목적 폴더 안에서는 대상 저장소로 복사하는 파일을 `templates/` 에, 스킬 폴더에서 그대로 실행하는 파일을
`scripts/` 에 둔다.

## 결과

- 진입점이 Skill 도구를 거치지 않으므로 `disable-model-invocation: true` 가 흐름을 막지 않는다. 부작용이
  있는 일을 사용자만 시작할 수 있다는 점은 그대로다.
- 0002 의 나머지는 유지된다. 목적 다섯 개, 목적마다 검증 방법이 하나라는 기준, 진입점이 하나라는 점이 그대로다.
  바뀌는 것은 목적이 스킬이 아니라 폴더라는 점이다.
- 목적 이름으로 따로 부르던 커맨드(`/repo-setup:repo-privacy` 등)가 사라진다. 한 목적만 돌리려면 진입점에
  목적 이름을 인자로 준다. 이전 판에서 쓰던 커맨드가 없어지므로 호환성이 깨지고, 판 번호를 0.2.0 으로
  올린다.
- 절차 문서는 스킬로 불리지 않고 읽히기만 하므로 인자 자리표시자가 치환되지 않는다. 절차 문서에는
  자리표시자를 쓰지 않는다.
- `npx skills` 로 설치하면 스킬이 한 개 깔린다. 목적 폴더는 스킬 폴더와 함께 복사된다.
- 앞선 ADR 이 적은 스킬 이름은 이 결정 뒤로 같은 이름의 목적을 가리킨다. `repo-privacy` 는 `privacy`,
  `repo-license` 는 `license`, `repo-ci` 는 `ci`, `repo-secure` 는 `secure`, `repo-contrib` 은 `contrib` 이다.
