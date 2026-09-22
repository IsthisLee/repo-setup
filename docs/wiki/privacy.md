# 개인 정보 가드 (privacy)

진입점 `repo-setup` 의 목적 `privacy` 다. 세팅 절차는 `plugin/skills/repo-setup/privacy/PROCEDURE.md` 에 있다.

## 하는 일

홈 경로·이메일·사내 식별자가 커밋되는 것을 커밋 시점에 막는다. `bash` 와 `git` 만 있으면 되고 언어를
가리지 않는다.

훅 파일을 커밋해 두어도 그것만으로는 아무 일도 일어나지 않는다. git 은 훅을 `$GIT_DIR/hooks` 에서 찾고,
그 위치를 바꾸는 `core.hooksPath` 는 `.git/config` 에 저장되어 **클론과 함께 전달되지 않는다.**
그래서 새 클론과 새 워크트리에서는 가드가 꺼진 상태이고, **막히는 일이 없으므로 아무도 눈치채지 못한다.**

에이전트가 커밋하는 환경에서 이 문제가 커졌다. 에이전트는 절대 경로를 문서에 그대로 옮겨 적고,
워크트리를 자주 만들며, 막히면 `--no-verify` 를 붙여 볼 생각을 한다.

## 동작

스테이징된 내용만 검사한다. 두 축이다.

1. **경로** — 내부 문서 폴더가 스테이징되면 막는다. 저장소마다 다르므로 훅의 `case` 문을 고쳐 쓴다.
2. **내용** — 홈 경로(`/Users/<이름>`, `/home/<이름>`)는 훅에 박혀 있고, 나머지는 패턴 파일에서 읽는다.

### 패턴 출처

| 두는 곳 | 커밋되나 | 팀에 전달되나 | 무엇을 적나 |
|---|---|---|---|
| `.githooks/team-patterns` | **된다** | **된다** | 사내 도메인, 고객사 이름처럼 팀이 함께 막아야 하는 값 |
| `~/.config/git-guard/patterns` | 안 됨 | 안 됨 | 내 개인 패턴. 이 기계의 모든 저장소에 적용된다 |
| `.private/guard-patterns` | 안 됨 | 안 됨 | 그 저장소에만 해당하고 남에게 보일 수 없는 값 |

셋을 합쳐서 적용한다. 셋 다 없으면 홈 경로만 막는다.

**`team-patterns` 에 자격증명은 넣지 않는다.** 커밋되는 파일이고, 저장소가 공개로 바뀌면 그 목록도 공개된다.
도메인이나 이름 같은 식별자만 적는다. 나머지 두 파일은 막으려는 값이 평문으로 들어 있으므로 **절대 커밋하지 않는다.**

### 다른 훅 관리자와 함께 쓰기

`core.hooksPath` 는 값을 하나만 가지고, 그 값을 걸면 git 이 `.git/hooks` 를 더는 보지 않는다. 그래서
husky 처럼 `core.hooksPath` 를 잡은 관리자가 있거나 `.git/hooks` 에 이미 훅이 있으면 `script/setup` 이 **덮지 않고
멈춘다.** 덮으면 그쪽 훅이 조용히 죽기 때문이다. 그때는 그쪽 훅이 이 한 줄을 부르게 하면 둘 다 돈다.

```bash
"$(git rev-parse --show-toplevel)"/.githooks/pre-commit || exit 1
```

### 손으로 깔기

`plugin/skills/repo-setup/privacy/templates/` 의 두 파일을 대상 저장소의 `.githooks/pre-commit` 과
`script/setup` 으로 복사하고 `script/setup` 을 돌린다. 그다음 `script/setup --verify` 로 실제로 막히는지 확인한다. 이 명령은 커밋을 만들지 않고 설정도 바꾸지 않는다.

## 바꾸는 것

- 대상 저장소에 파일 두 개를 놓는다. `.githooks/pre-commit` 과 `script/setup` 이고, 원본은
  `plugin/skills/repo-setup/privacy/templates/` 에 있다.
- `script/setup` 이 그 클론의 `.git/config` 에 `core.hooksPath` 를 `.githooks` 로 쓴다. 이 값은 다른
  사람에게 전달되지 않는다.
- `.gitignore` 에 `.private/` 한 줄을 더한다.
- `script/setup --init-patterns` 는 `~/.config/git-guard/patterns` 견본을 만든다(없을 때만).
- 팀 저장소에서도 `.gitignore` 와 규칙 문서의 변경은 확인을 받은 뒤 세팅 PR 로 올리고, 병합은 팀이 정한다.
  저장소 보안 설정은 바꾸지 않는다.

## 한계와 알려진 문제

- **이미 푸시된 것은 되돌리지 못한다.** 값이 이미 나갔으면 지우려 하기보다 발급처에서 폐기하는 것이 확실하다.
- **`--no-verify` 로 우회된다.** 의도한 탈출구이고, 사람이 판단해 쓰는 자리다.
- **패턴에 적은 것만 막는다.** 목록에 없는 값은 지나간다.
- **`script/setup` 을 돌리지 않은 기계에서는 꺼진 상태다.** git 의 설계이고 husky 로도 달라지지 않는다.

## 관련 파일

- `plugin/skills/repo-setup/privacy/PROCEDURE.md`
- `plugin/skills/repo-setup/privacy/templates/pre-commit`
- `plugin/skills/repo-setup/privacy/templates/setup`
- `tests/guard/unit.sh`, `tests/setup/unit.sh`

## 관련 ADR

- [0001. 저장소 층만 다룬다](../adr/0001-repository-layer-only.md)
- [0003. 겹치는 파일과 설정의 소유를 정한다](../adr/0003-ownership-of-overlapping-files.md)
- [0005. 팀 저장소의 공유 자산은 제안만 한다](../adr/0005-team-repos-propose-only.md)
- [0011. 팀 저장소에도 파일 변경은 확인 후 PR 로 올리고, 푸시할 수 없으면 패치로 물러난다](../adr/0011-team-repos-file-changes-by-pr.md)

## 확인한 외부 사실

이 페이지로 옮겨 온 외부 사실은 없다.
