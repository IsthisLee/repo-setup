# repo-setup

용도에 맞게 git 저장소를 세팅합니다. **기억할 것은 커맨드 하나뿐입니다.**

진입점이 저장소를 실측하고, 해당하는 것만 골라, 좁은 스킬을 순서대로 부르고, **무엇을 했고 무엇을 왜
건너뛰었는지** 보고합니다. 다루는 것은 git 과 GitHub 에 속하는 것뿐이고, 린터나 빌드 설정 같은 언어별
도구 체인은 다루지 않습니다.

## 첫 실행

세팅할 저장소에서 용도를 적어 부릅니다.

```
/repo-setup:repo-setup 공개 오픈소스 라이브러리
```

용도를 적지 않으면 실측 결과를 보인 뒤 물어봅니다. 지금 판의 Claude Code 에서는 진입점이 좁은 스킬을
직접 부르지 못합니다([알려진 문제](docs/wiki/setup-flow.md#한계와-알려진-문제)). 그때는
`/repo-setup:repo-privacy` 처럼 좁은 스킬을 직접 부릅니다.

## 설치

두 경로가 있고 같은 저장소를 씁니다.

**Claude Code** 는 플러그인으로 설치합니다. 커맨드가 `/repo-setup:repo-setup` 처럼 이름 공간을 갖습니다.

```
/plugin marketplace add IsthisLee/repo-setup
/plugin install repo-setup
```

설치한 뒤에는 `claude plugin details repo-setup` 으로 확인합니다.

**그 밖의 에이전트**는 [`skills` CLI](https://github.com/vercel-labs/skills) 로 설치합니다. Codex, Cursor,
OpenCode 를 포함해 78개 이상을 지원합니다.

```bash
npx skills@latest add IsthisLee/repo-setup          # 이 프로젝트에만
npx skills@latest add IsthisLee/repo-setup -g       # 전역
npx skills@latest add IsthisLee/repo-setup --list   # 설치하지 않고 목록만
npx skills@latest add IsthisLee/repo-setup -a codex -a cursor   # 특정 에이전트만
```

### 설치한 뒤에 알아 둘 것

아래는 이 저장소를 원격에서 새로 클론해 **가짜 홈으로 격리한 환경**에서 `skills` CLI 1.7.0 으로
직접 확인한 결과입니다(2026-09-18).

| 설치 형태 | 실물이 놓이는 곳 | 에이전트 폴더 |
|---|---|---|
| 프로젝트 범위, 에이전트 미지정 | `./.agents/skills/<이름>/` | `.claude/skills/<이름>` 심링크 |
| 전역 `-g`, 에이전트 둘 지정 | `~/.agents/skills/<이름>/` | `~/.claude/skills/<이름>` 심링크 |
| 전역 `-g -a claude-code` 하나만 | `~/.claude/skills/<이름>/` 에 실물 복사 | 심링크를 만들지 않습니다 |
| 전역 `-g -a codex` | `~/.agents/skills/<이름>/` 에 실물 복사 | `~/.codex/skills/` 는 만들어지지 않습니다 |

설치한 자리에 `skills-lock.json` 이 함께 생깁니다.

**비공개 저장소를 받을 때는 받는 쪽에 접근 권한이 있는 git 인증이 있어야 합니다.** CLI 는 그 저장소
URL 에 이미 설정된 인증(git credential helper, GitHub CLI, SSH 순)을 씁니다. 이 저장소가 비공개였을 때
인증이 없는 홈에서 돌리면 `Failed to clone ... fatal: unable to get password from user` 를 내고
`Installation failed` 로 멈췄습니다. 조용히 빈 상태로 끝나지 않았고, `credential.helper` 하나만 있어도
받아졌습니다. 이 저장소는 2026-09-22 에 공개로 바뀌었습니다.

**`-y` 를 주면 감지 여부와 무관하게 아주 많은 에이전트에 설치합니다.** 격리 환경에서 재 보니 57개였고,
프로젝트에 `.agents/skills/` 와 `.claude/skills/` 말고 `agent/skills/` 까지 생겼습니다. 폴더를
늘리고 싶지 않으면 `-a` 로 대상을 좁힙니다.

`~/.claude/skills/` 심링크가 만들어지지 않아 Claude Code 에서 스킬이 보이지 않는다는 이슈가
열려 있습니다([vercel-labs/skills#851](https://github.com/vercel-labs/skills/issues/851), 확인일
2026-09-18, 상태 OPEN). **1.7.0 에서는 위 네 형태 모두 Claude Code 가 읽는 자리에 스킬이
놓였습니다.** 이슈가 적은 재현 형태(`-g -a claude-code`)도 그랬습니다.

## 목적 다섯

| 목적 | 하는 일 |
|---|---|
| [개인 정보 가드](docs/wiki/privacy.md) | 홈 경로·이메일·사내 식별자가 커밋되는 것을 커밋 시점에 막습니다 |
| [라이선스](docs/wiki/license.md) | 라이선스를 정하고 `LICENSE` 와 매니페스트가 같은 말을 하게 합니다 |
| [테스트 워크플로](docs/wiki/ci.md) | 테스트가 푸시마다 돌게 하고 실제로 한 번 돌려 확인합니다 |
| [호스트 보안 층](docs/wiki/secure.md) | 호스트의 보안 기능을 켜고 액션을 SHA 로 고정합니다 |
| [협업 준비](docs/wiki/contrib.md) | 기여 안내와 신고처, 서식, 리뷰 담당을 놓고 기본 브랜치를 보호합니다 |

## 문서

- [wiki](docs/wiki/README.md): 구현된 기능이 무엇을 하고 어떻게 동작하는지 설명합니다. 진입점의 흐름과
  이 저장소를 고치는 방법도 여기에 있습니다.
- [ADR](docs/adr/README.md): 왜 그렇게 만들었는지와 버린 대안을 설명합니다.

## 라이선스

MIT
