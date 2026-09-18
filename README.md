# repo-setup

용도에 맞게 git 저장소를 세팅한다. **기억할 것은 커맨드 하나뿐이다.**

```
/repo-setup:repo-setup 공개 오픈소스 라이브러리
```

진입점이 저장소를 실측하고, 해당하는 것만 골라, 좁은 스킬을 순서대로 부르고, **무엇을 했고 무엇을 왜
건너뛰었는지** 보고한다.

## 설치

두 경로가 있고 같은 저장소를 쓴다.

**Claude Code** 는 플러그인으로 깐다. 커맨드가 `/repo-setup:repo-setup` 처럼 이름 공간을 갖는다.

```
/plugin marketplace add IsthisLee/repo-setup
/plugin install repo-setup
```

**그 밖의 에이전트**는 [`skills` CLI](https://github.com/vercel-labs/skills) 로 깐다. Codex, Cursor,
OpenCode 를 포함해 78개 이상을 지원한다.

```bash
npx skills@latest add IsthisLee/repo-setup          # 이 프로젝트에만
npx skills@latest add IsthisLee/repo-setup -g       # 전역
npx skills@latest add IsthisLee/repo-setup --list   # 깔지 않고 목록만
npx skills@latest add IsthisLee/repo-setup -a codex -a cursor   # 특정 에이전트만
```

비공개 저장소도 같은 명령으로 받는다. CLI 가 그 저장소 URL 에 이미 설정된 인증(git credential
helper, GitHub CLI, SSH 순)을 쓴다.

깔린 뒤 Claude Code 쪽은 `claude plugin details repo-setup` 으로 확인한다. 스킬 둘이
`Skills (2)  repo-privacy, repo-setup` 으로 잡히고 항상 켜져 있는 비용이 약 294 토큰이다.

### 깔린 뒤에 알아 둘 것

아래는 이 저장소를 원격에서 새로 클론해 **가짜 홈으로 격리한 환경**에서 `skills` CLI 1.7.0 으로
직접 확인한 결과다(2026-09-18).

| 설치 형태 | 실물이 놓이는 곳 | 에이전트 폴더 |
|---|---|---|
| 프로젝트 범위, 에이전트 미지정 | `./.agents/skills/<이름>/` | `.claude/skills/<이름>` 심링크 |
| 전역 `-g`, 에이전트 둘 지정 | `~/.agents/skills/<이름>/` | `~/.claude/skills/<이름>` 심링크 |
| 전역 `-g -a claude-code` 하나만 | `~/.claude/skills/<이름>/` 에 실물 복사 | 심링크를 만들지 않는다 |
| 전역 `-g -a codex` | `~/.agents/skills/<이름>/` 에 실물 복사 | `~/.codex/skills/` 는 만들어지지 않는다 |

설치한 자리에 `skills-lock.json` 이 함께 생긴다.

**이 저장소는 비공개이므로 받는 쪽에 접근 권한이 있는 git 인증이 있어야 한다.** 인증이 없는 홈에서
돌리면 `Failed to clone ... fatal: unable to get password from user` 를 내고 `Installation failed`
로 멈춘다. 조용히 빈 상태로 끝나지 않는다. `credential.helper` 하나만 있어도 받아진다.

**`-y` 를 주면 감지 여부와 무관하게 아주 많은 에이전트에 깐다.** 격리 환경에서 재 보니 57개였고,
프로젝트에 `.agents/skills/` 와 `.claude/skills/` 말고 `agent/skills/` 까지 생겼다. 폴더를
늘리고 싶지 않으면 `-a` 로 대상을 좁혀라.

`~/.claude/skills/` 심링크가 만들어지지 않아 Claude Code 에서 스킬이 보이지 않는다는 이슈가
열려 있다([vercel-labs/skills#851](https://github.com/vercel-labs/skills/issues/851), 확인일
2026-09-18, 상태 OPEN). **1.7.0 에서는 위 네 형태 모두 Claude Code 가 읽는 자리에 스킬이
놓였다.** 이슈가 적은 재현 형태(`-g -a claude-code`)도 그랬다.

**Claude Code 와 그 밖의 에이전트는 호출 방식이 다르다.** 두 스킬 모두
`disable-model-invocation: true` 를 달고 있어서 Claude Code 에서는 **사용자만** 부를 수 있다. 다른
에이전트는 이 키를 모르므로 모델이 `description` 을 읽고 스스로 고를 수 있다. 그래서 `description`
에 영어와 한국어를 함께 적었다. 이 차이는 이쪽에서 없앨 수 없다.

## 왜 이렇게 나눴나

저장소 세팅은 항목이 많다. 라이선스, `.gitignore`, CI, 브랜치 보호, secret scanning, 커밋 훅.
그런데 **대부분은 그 저장소에 해당하지 않는다.** 개인 실험 저장소에 CODEOWNERS 를 넣을 일이 없다.

- **통합 스킬 하나**로 만들면 해당하지 않는 것까지 억지로 적용되고, 항목마다 검증 방법이 달라
  테스트가 뒤섞인다.
- **좁은 스킬만 흩어** 두면 사용자가 이름을 전부 외워야 하고, 빠진 것이 조용히 생긴다.

그래서 **좁은 스킬은 좁게 두어 각자 테스트로 지키고, 진입점은 하나만 둔다.** 진입점이 공통 실측을
한 번 해서 물려주므로 좁은 스킬마다 같은 측정을 반복하지 않는다.

## 진입점: `repo-setup`

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

## 좁은 스킬

| 스킬 | 하는 일 |
|---|---|
| [`repo-privacy`](#repo-privacy-개인-정보-가드) | 홈 경로·이메일·사내 식별자가 커밋되는 것을 커밋 시점에 막는다 |

---

## `repo-privacy`: 개인 정보 가드

`bash` 와 `git` 만 있으면 되고 언어를 가리지 않는다.

### 왜

훅 파일을 커밋해 두어도 그것만으로는 아무 일도 일어나지 않는다. git 은 훅을 `$GIT_DIR/hooks` 에서 찾고,
그 위치를 바꾸는 `core.hooksPath` 는 `.git/config` 에 저장되어 **클론과 함께 전달되지 않는다.**
그래서 새 클론과 새 워크트리에서는 가드가 꺼진 상태이고, **막히는 일이 없으므로 아무도 눈치채지 못한다.**

에이전트가 커밋하는 환경에서 이 문제가 커졌다. 에이전트는 절대 경로를 문서에 그대로 옮겨 적고,
워크트리를 자주 만들며, 막히면 `--no-verify` 를 붙여 볼 생각을 한다.

### 무엇을 막는가

스테이징된 내용만 검사한다. 두 축이다.

1. **경로** — 내부 문서 폴더가 스테이징되면 막는다. 저장소마다 다르므로 훅의 `case` 문을 고쳐 쓴다.
2. **내용** — 홈 경로(`/Users/<이름>`, `/home/<이름>`)는 훅에 박혀 있고, 나머지는 패턴 파일에서 읽는다.

### 패턴을 어디에 두나

| 두는 곳 | 커밋되나 | 팀에 전달되나 | 무엇을 적나 |
|---|---|---|---|
| `.githooks/team-patterns` | **된다** | **된다** | 사내 도메인, 고객사 이름처럼 팀이 함께 막아야 하는 값 |
| `~/.config/git-guard/patterns` | 안 됨 | 안 됨 | 내 개인 패턴. 이 기계의 모든 저장소에 적용된다 |
| `.private/guard-patterns` | 안 됨 | 안 됨 | 그 저장소에만 해당하고 남에게 보일 수 없는 값 |

셋을 합쳐서 적용한다. 셋 다 없으면 홈 경로만 막는다.

**`team-patterns` 에 자격증명은 넣지 않는다.** 커밋되는 파일이고, 저장소가 공개로 바뀌면 그 목록도 공개된다.
도메인이나 이름 같은 식별자만 적는다. 나머지 둘은 막으려는 값이 평문으로 들어 있으므로 **절대 커밋하지 않는다.**

### 다른 훅 관리자와 함께 쓰기

`core.hooksPath` 는 값을 하나만 가진다. husky 나 lefthook 이 이미 잡고 있으면 `setup.sh` 가 **덮지 않고
멈춘다.** 덮으면 그쪽 훅이 조용히 죽기 때문이다. 그때는 그쪽 관리자의 `pre-commit` 에 한 줄을 넣으면 둘 다 돈다.

```bash
"$(git rev-parse --show-toplevel)"/.githooks/pre-commit || exit 1
```

### 손으로 깔기

`templates/` 의 두 파일을 대상 저장소 루트에 복사하고 `./setup.sh` 를 돌린다.

### 한계

- **이미 푸시된 것은 되돌리지 못한다.** 값이 이미 나갔으면 지우려 하기보다 발급처에서 폐기하는 것이 확실하다.
- **`--no-verify` 로 우회된다.** 의도한 탈출구이고, 사람이 판단해 쓰는 자리다.
- **패턴에 적은 것만 막는다.** 목록에 없는 값은 지나간다.
- **`./setup.sh` 를 돌리지 않은 기계에서는 꺼진 상태다.** git 의 설계이고 husky 로도 달라지지 않는다.

---

## 검사

```bash
tests/guard/unit.sh && tests/setup/unit.sh && tests/invariants.sh
```

## 라이선스

MIT
