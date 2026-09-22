# 이 저장소의 개발 (development)

이 저장소를 고치는 사람을 위한 페이지다. 에이전트가 지킬 규칙의 정본은 저장소 루트의 `CLAUDE.md` 다.

## 하는 일

이 저장소의 구조, 테스트, 자체 CI, 기여 방법을 설명한다.

## 동작

### 구조

저장소는 두 층이다. `plugin/` 만 사용자에게 실리고, 테스트와 문서는 그 밖에 둔다. 스킬은
`plugin/skills/` 아래에 있다. 폴더마다 무엇을 두는지는 `CLAUDE.md` 의 「구조」 절에 있다.

### 테스트

```bash
tests/guard/unit.sh && tests/setup/unit.sh && tests/license/unit.sh && tests/ci/unit.sh && tests/secure/unit.sh && tests/contrib/unit.sh && tests/invariants.sh
```

테스트 목록의 정본은 저장소 루트 `.check.toml` 의 `test_command` 다. shellcheck 명령은 `CLAUDE.md` 의
「검사 명령」 절에 있다.

### 자체 CI

`.github/workflows/test.yml` 이 PR 과 main 푸시마다 `ubuntu-latest` 와 `macos-latest` 에서 돈다. check
이름은 `test (ubuntu-latest)` 와 `test (macos-latest)` 다.

1. checkout 한다. 액션은 SHA 로 고정되어 있고 `persist-credentials: false` 다.
2. shellcheck 공식 릴리스 v0.11.0 을 받아 sha256 으로 확인한 뒤 PATH 에 더한다.
3. `.check.toml` 의 `test_command` 를 읽어 돌린다.
4. shellcheck 판이 0.11.0 인지 확인하고 `CLAUDE.md` 의 shellcheck 명령을 돌린다.

권한은 `contents: read` 만 준다. 같은 ref 에 새로 푸시하면 앞선 실행을 취소하고, 한 러너가 실패해도
다른 러너는 끝까지 돈다.

### 기여

커밋 가드를 켜려면 클론한 뒤 `./setup.sh` 를 한 번 돌린다. 이 저장소의 가드는 스킬 템플릿의 사본이고,
`tests/invariants.sh` 가 둘이 같은지 본다. 규칙과 커밋 메시지 형식은 `CLAUDE.md` 의 「규칙」 절에 있다.

## 바꾸는 것

이 페이지는 이 저장소 자신에 대한 안내라서 대상 저장소에서 바꾸는 것이 없다.

## 한계와 알려진 문제

- Codex, Antigravity 같은 다른 에이전트에서 실제로 실행해 보지 않았다. `npx skills` 가 스킬을 찾는
  경로만 `tests/invariants.sh` 가 검사한다.
- shellcheck 를 올릴 때는 워크플로의 판 하나와 sha256 둘을 손으로 바꿔야 한다.
- shellcheck 명령은 `CLAUDE.md` 와 워크플로 두 곳에 있고, 둘이 같은지 검사하는 테스트는 없다.

## 관련 파일

- `tests/invariants.sh`
- `tests/guard/unit.sh`, `tests/setup/unit.sh`, `tests/license/unit.sh`, `tests/ci/unit.sh`,
  `tests/secure/unit.sh`, `tests/contrib/unit.sh`
- `.github/workflows/test.yml`, `.check.toml`, `CLAUDE.md`

## 관련 ADR

- [0002. 목적별로 좁은 스킬 다섯을 둔다](../adr/0002-five-narrow-skills-by-purpose.md)

## 확인한 외부 사실

1. **공개 저장소**, vercel-labs [skills CLI](https://github.com/vercel-labs/skills), 2026-09-22 확인.
   `npm pack skills@1.7.0` 으로 받은 `dist/cli.mjs` 의 `getPluginSkillPaths` 는
   `.claude-plugin/marketplace.json` 의 `plugins[].source` 가 `./` 로 시작하면 그 아래 `skills` 폴더를
   탐색 경로에 더한다. 스킬을 `plugin/skills/` 에 두는 이유가 이것이다.
2. **실측**, 2026-09-22. 스킬 폴더의 하위 파일이 함께 복사되고 실행 비트도 보존된다. 공식 문서에
   없어 빈 저장소에 CLI 1.7.0 으로 직접 설치해 확인했다. 그래서 템플릿은 스킬 본문에 인용하지 않고
   `<스킬>/templates/` 에 실제 파일로 둔다.
3. **공식 문서**, Claude Code [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces),
   2026-09-22 확인. "when users install a plugin, Claude Code copies the plugin directory to a cache
   location, unless the plugin loads in place."(번역: 사용자가 플러그인을 설치하면, 제자리에서 불러오는
   경우가 아니라면 Claude Code 가 플러그인 폴더를 캐시 위치로 복사한다.) 복사에서 파일을 빼는 방법은
   이 문서에서 찾지 못했다. 그래서 테스트와 문서를 `plugin/` 밖에 둔다.
4. **공개 저장소**, GitHub [actions/runner-images](https://github.com/actions/runner-images),
   2026-09-22 확인. `ubuntu-latest` 는 Ubuntu 24.04(Bash 5.2.21, apt 의 shellcheck 0.9.0-1)이고,
   `macos-latest` 는 macOS 26 Arm64(Bash 3.2.57, shellcheck 없음)다.
