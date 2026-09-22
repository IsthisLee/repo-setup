# 스펙: 스킬을 하나로 합치고 추정기를 검증된 도구로 바꾼다

- 상태: 확정(2026-09-22 인터뷰). 구현은 새 세션에서 아래 PR 순서대로 한다.
- 선행: PR #1 `fix(privacy): 가드가 조용히 꺼지는 경로 넷을 막는다` 가 main 에 병합돼 있어야 ② 부터 시작할 수 있다. ② 가 repo-privacy 파일을 옮기므로, PR #1 보다 먼저 병합하면 충돌한다.
- 이 문서는 홈 경로를 글자 그대로 적지 않는다. 이 저장소의 가드와 `tests/invariants.sh` 가 추적 파일에 든 홈 경로를 막기 때문이다. 경로가 필요한 자리는 "홈 폴더 아래 `runner`" 처럼 풀어서 쓴다. 테스트는 지금처럼 경로를 실행할 때 조립한다.

## 1. 왜

2026-09-22 코드 리뷰와 인터뷰에서 확인한 문제는 넷이다.

1. **진입점이 좁은 스킬을 부를 수 없다.** 좁은 스킬 다섯이 모두 `disable-model-invocation: true` 이고, 이 설정은 Skill 도구 호출까지 막는다(6절의 출처 1). 그래서 `plugin/skills/repo-setup/SKILL.md` 3단계 "좁은 스킬을 호출한다"는 Claude Code 에서 동작하지 않는다.
2. **직접 만든 추정기가 틀린 답을 확신하며 내놓는다.** 리뷰 항목 7~12번이 여기서 나왔다. `check-license.sh` 는 제3자 고지에 적힌 "MIT License" 를 보고 독점 라이선스를 MIT 로 판정한다. `find-test-command.sh` 는 테스트가 0개인 `Cargo.toml` 을 보고 테스트가 있다고 판정한다. `check-workflow-security.sh` 는 따옴표로 감싼 SHA 를 오탐하고 composite action 을 보지 않는다. `check-contrib.sh` 는 조직 기본값을 보지 않는다.
3. **부작용이 있는 절차가 SKILL.md 본문에 테스트 없이 들어 있다.** 브랜치 보호 PUT 의 필수 검사 이름이 `test` 인데, 실제 check 이름은 matrix 때문에 `test (ubuntu-latest)` 라서 모든 PR 이 영원히 기다린다. 기본 브랜치를 `git symbolic-ref --short HEAD`(현재 브랜치)로 구한다. `gh run list --limit 1` 이 이전 커밋의 실행을 증거로 집는다.
4. **이 저장소 자체에 CI 가 없다.** 테스트가 macOS(bash 3.2, BSD grep)에서만 돌았다. Linux(bash 5, GNU grep)에서는 한 번도 확인하지 않았다. 두 grep 은 실제로 다르게 동작한다. 예를 들어 BSD grep 은 `a|` 를 문법 오류(exit 2)로 거부한다(2026-09-22 실측).

## 2. 확정한 결정

| # | 주제 | 결정 |
|---|---|---|
| 1 | 스킬 구조 | `repo-setup` 하나만 스킬로 남기고 `disable-model-invocation: true` 를 유지한다. 지금의 다섯은 그 폴더 안의 목적별 폴더가 되고, 진입점은 고른 목적의 절차 문서만 읽는다. `/repo-setup license` 처럼 인자로 목적 하나만 고를 수 있다 |
| 2 | 판정 수단 | 가드(`pre-commit`, `commit-msg`)와 `setup.sh` 는 계속 bash 와 git 만 쓴다. 나머지 판정은 `gh`(GitHub API)와 zizmor 가 맡고, `gh` 는 필수다 |
| 3 | 제거 | `codeql.yml` 골격, contrib 골격 셋(CODEOWNERS, `ISSUE_TEMPLATE/`, PR 템플릿), CLAUDE.md 의 테스트 건수, `find-test-command.sh`, `check-workflow-security.sh`, `check-contrib.sh`, license 의 python3 폴백 |
| 4 | main 보호 | 룰셋으로 옮긴다. 규칙은 넷이다. `pull_request`(승인 0명), `required_status_checks`(strict), `non_fast_forward`, `deletion`. 우회는 저장소 관리자만 `bypass_mode: pull_request` 로 허용한다. 팀 저장소는 계획만 보이고 적용하지 않는다 |
| 5 | 필수 검사 이름 | 워크플로가 실제로 돈 커밋의 check-runs 에서 이름과 앱 id 를 읽어 `context` 와 `integration_id` 로 건다. 완료된 실행이 없으면 필수 검사를 걸지 않고 그 사실을 보고한다 |
| 6 | SHA 고정 | 에이전트가 `gh api repos/{owner}/{repo}/commits/{ref} --jq .sha` 로 SHA 를 얻어 `uses:` 를 고치고 `# {ref}` 주석을 남긴다. 결과는 zizmor 로 검증한다. 고정 스크립트는 만들지 않는다 |
| 7 | zizmor | 로컬에서 한 번 돌리고, 대상 저장소에도 워크플로로 둔다. `regular` 페르소나에 `--min-severity=low` 로 돌려 low 이상이면 실패시킨다. `zizmor.yml` 로 모든 액션에 SHA 고정을 요구하고, 예외는 `zizmor.yml` 에 이유 주석과 함께 적을 때만 인정한다. 설치돼 있지 않으면 설치 명령을 보이고 멈춘다(자동 설치하지 않는다) |
| 8 | 테스트 판정 | 에이전트가 후보 명령을 로컬에서 실제로 돌리고, 테스트된 판독 스크립트가 요약 줄에서 개수를 읽는다. 0개면 워크플로를 놓지 않는다. 알아보지 못하면 exit 2 로 돌리고, 출력 끝 20줄을 보여 주며 사람에게 확인받는다 |
| 9 | 쓰기 스크립트 | 인자 없이 돌리면 계획만 출력하고, `--apply` 를 줘야 보낸다. 보낸 뒤에는 되읽어 확인하고 되돌리는 명령을 출력한다. 종료 코드는 0·1·2 셋이다(3.7절) |
| 10 | privacy 나머지 | 셋 모두 넣는다. (a) 내용 검사는 추가된 줄만 하고(바이너리는 blob 전체), 내장 예외 넷을 두고, Windows 경로를 더한다. (b) `commit-msg` 훅으로 커밋 메시지도 검사한다. (c) `setup.sh` 가 훅이 아닌 파일에 실행 비트를 붙이지 않는다 |
| 11 | 내장 홈 경로 예외 | 홈 폴더(`/home/`) 바로 아래가 정확히 `runner`, `node`, `vscode`, `linuxbrew` 인 경로만 예외다. macOS 의 공용 폴더(Users 아래 Shared)와 클라우드 기본 계정(`ubuntu`, `ec2-user`)은 계속 막는다. 예외 목록은 훅에 박힌 고정 목록이고 설정으로 늘릴 수 없다 |
| 12 | 자체 CI | `pull_request` 와 main 푸시에서 `ubuntu-latest` 와 `macos-latest` 로 돌린다. 같은 브랜치에 새로 푸시하면 이전 실행을 취소하고, 권한은 `contents: read` 만 주며, 액션은 SHA 로 고정한다. 저장소가 공개로 바뀌어(2026-09-22) 표준 러너는 무료다 |
| 13 | 호환성 | `breaking` 라벨을 만들어 ② 에 붙이고, 두 매니페스트를 0.2.0 으로 올린다. README 에 이전 판에서 옮겨 오는 방법을 적는다 |
| 14 | PR 분할 | 기능별로 10개다(4절). squash 병합이므로 PR 하나가 main 의 커밋 하나가 된다 |
| 15 | 종단 검증 | 공개 임시 저장소에서 처음 세팅하는 경로를 돌리고, 이 저장소에서 이미 도구가 있는 저장소에 얹는 경로를 돌린다(8절) |
| 16 | 스펙 위치 | 이 파일을 ① 과 함께 커밋한다. 모두 끝나면 확정된 설계를 `docs/decisions.md` 로 옮기고, 이 파일에는 완료 표시만 남긴다 |

## 3. 목표 구조와 인터페이스

### 3.1 폴더

```
plugin/skills/repo-setup/
  SKILL.md                  진입점: 실측, 선택, 순서, 보고
  privacy/
    PROCEDURE.md
    templates/pre-commit      → 대상 .githooks/pre-commit
    templates/commit-msg      → 대상 .githooks/commit-msg      (④)
    templates/lib/guard.sh    → 대상 .githooks/lib/guard.sh    (④, 두 훅이 source)
    templates/setup.sh        → 대상 저장소 루트 setup.sh
  license/
    PROCEDURE.md
    scripts/check-license.sh
  ci/
    PROCEDURE.md
    scripts/check-test-run.sh
    scripts/wait-run.sh
    templates/tests.yml       → 대상 .github/workflows/tests.yml
  secure/
    PROCEDURE.md
    scripts/secret-scanning.sh
    scripts/code-scanning.sh
    templates/dependabot.yml  → 대상 .github/dependabot.yml
    templates/zizmor.yml      → 대상 설정 파일(위치는 7절에서 확인)
    templates/zizmor-workflow.yml → 대상 .github/workflows/zizmor.yml
  contrib/
    PROCEDURE.md
    scripts/community-defaults.sh
    scripts/ruleset.sh
    templates/CONTRIBUTING.md
    templates/SECURITY.md
```

- `templates/` 는 대상 저장소로 **복사하는** 파일이고, `scripts/` 는 스킬 폴더에서 **그대로 실행하는** 파일이다. 지금은 둘이 한 폴더에 섞여 있어서 리뷰가 "스크립트를 저장소 루트에서 `bash templates/x.sh` 로 돌리라"는 틀린 안내를 찾아냈다.
- 스크립트는 **대상 저장소의 루트를 현재 폴더로 두고** 실행한다. 절차 문서에는 `<목적>/scripts/x.sh` 처럼 스킬 폴더 기준 상대 경로로 적는다. 스킬 폴더가 어디인지는 진입점 SKILL.md 가 처음에 한 번 알려 준다("이 SKILL.md 가 있는 폴더").
- 이 저장소 루트의 `.githooks/pre-commit`, `.githooks/commit-msg`, `.githooks/lib/guard.sh`, `setup.sh` 는 `privacy/templates/` 의 사본으로 둔다. invariants 가 일치를 본다.

### 3.2 진입점 `SKILL.md`

- frontmatter: `name: repo-setup`, `disable-model-invocation: true`, `description` 은 영어와 한국어를 함께 적고 다섯 목적을 모두 담는다. `description` 은 다른 에이전트가 스킬을 고르는 유일한 신호다.
- 인자: 없으면 전체 흐름을 돈다. `privacy`, `license`, `ci`, `secure`, `contrib` 중 하나를 주면 그 목적만 돈다. 어느 쪽이든 공통 실측은 항상 한다.
- 공통 실측에 **기본 브랜치**를 더한다.
  - GitHub 원격이면 `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name` 을 쓴다.
  - 원격은 있지만 GitHub 이 아니면 `git symbolic-ref --short refs/remotes/origin/HEAD` 에서 `origin/` 을 뗀다.
  - 둘 다 안 되면 사람에게 묻는다.
  - 이미 있는 훅은 `git config core.hooksPath` 와 `find "$(git rev-parse --git-common-dir)/hooks" -type f -perm -u+x ! -name '*.sample'` 로 본다.
- 선택 표: 목적 | 고르는 조건 | 빼는 조건 | 순서 | 선행. 첫 칸은 `` `privacy` `` 모양이다(invariants 가 목적 폴더 집합과 대조한다). 순서는 지금과 같이 privacy → license → ci → secure → contrib 이다.
- 목록에 없는 세팅이 필요하면 직접 하지 않고 보고한다. `docs/decisions.md` 를 가리키는 문장은 뺀다. 설치된 쪽에는 그 파일이 없다.

### 3.3 privacy

- **③ 추가된 줄만 검사**
  - 텍스트 파일은 `git diff --cached -U0 --no-color --no-ext-diff --no-textconv --no-renames` 가 내놓는 `+` 줄만 검사한다(`+++` 머리 줄은 뺀다).
  - `git diff --cached --numstat -z` 가 `-	-` 를 내는 바이너리는 지금처럼 blob 전체를 검사한다.
  - 파일 목록과 이름은 PR #1 처럼 `-z` 로 받고, 경로 검사(`.private/*`)는 그대로 둔다.
- **③ 내장 패턴**
  - 지금의 두 패턴(`/Users/[A-Za-z]`, `/home/[A-Za-z]`)에 Windows 경로를 더한다. 드라이브 문자 뒤에 `\Users\` 가 오고 영문자가 이어지는 경로이며, 역슬래시가 하나인 경우와 이스케이프돼 둘인 경우를 모두 잡는다.
  - 예외는 결정 11의 넷이다. 경로 구성 요소 전체가 일치할 때만 예외로 본다. 예를 들어 홈 폴더 아래 `nodejs-user` 는 막는다.
  - 구현 방법은 정하지 않는다. 다만 한 줄에 예외 경로와 막을 경로가 함께 있으면 막아야 한다.
- **④ commit-msg**
  - `.githooks/commit-msg "$1"` 은 메시지 파일에서 `#` 로 시작하는 줄을 빼고, pre-commit 과 같은 패턴(내장 패턴과 세 출처)으로 검사한다.
  - 패턴 적재와 검증 코드는 `.githooks/lib/guard.sh` 한 곳에 두고 두 훅이 `source` 한다.
  - 공존 한 줄: `"$(git rev-parse --show-toplevel)"/.githooks/commit-msg "$1" || exit 1`
  - `./setup.sh --verify` 는 임시 메시지 파일로 commit-msg 도 탐침한다. 두 훅이 모두 막아야 통과다.
- **⑤ 실행 비트**: `setup.sh` 는 git 이 아는 훅 이름(`pre-commit`, `commit-msg` 등 githooks(5) 의 목록)에만 실행 비트를 채우고 그것만 센다. `team-patterns` 와 `lib/` 는 건드리지 않는다.

### 3.4 license

- `scripts/check-license.sh --expect <key> --year <YYYY> --holder <이름>`
  - `gh api /licenses/<key> --jq .body` 로 템플릿을 받아 자리표시자를 채운다. 자리표시자 목록은 지원하는 키마다 구현할 때 GitHub 응답에서 실측해 둔다(7절).
  - 그 결과를 대상 저장소의 LICENSE 와 바이트 단위로 비교한다. 줄 끝의 CRLF 를 LF 로 바꾸는 것 말고는 정규화하지 않는다.
  - 종료 코드: 0 같다, 1 다르다(diff 앞 20줄 출력), 2 판단 불가(gh 없음, 인증 없음, 모르는 키).
- `scripts/check-license.sh`(인자 없음): 이미 있는 LICENSE 를 식별한다.
  - `gh api repos/{owner}/{repo}/license --jq '{spdx: .license.spdx_id, sha: .sha, path: .path}'` 로 GitHub 의 판정을 받는다.
  - 로컬 파일의 `git hash-object` 가 응답의 `sha` 와 다르면(푸시하지 않았음) exit 2 다. `NOASSERTION` 이어도 exit 2 다.
  - 같으면 매니페스트의 `license` 필드와 대조한다. 대조와 정규화 규칙(`-only`, `-or-later`, 대소문자)은 지금 것을 유지한다. 결과는 0 또는 1 이다.
  - 파일 이름은 `LICENSE*`, `LICENCE*`, `COPYING*` 을 모두 본다.
- 전문을 받을 때는 임시 파일에 받고, 성공했을 때만 `LICENSE` 로 옮긴다. 다운로드에 실패해 빈 LICENSE 가 남던 문제를 막기 위해서다.
- PROCEDURE.md 에서 6단계가 "4단계에서 정한 SPDX" 라고 잘못 가리키는 번호를 바로잡는다.

### 3.5 ci

- `find-test-command.sh` 를 지운다. 후보 명령은 에이전트가 프로젝트 파일을 읽어 고른다.
  - 후보: `.check.toml` 의 `test_command`, `npm pkg get scripts.test`, Makefile 의 `test` 타깃, `pyproject.toml`, `Cargo.toml`, `go.mod` 등.
  - 고른 명령을 로컬에서 돌리고 출력을 파일로 남긴다.
- `scripts/check-test-run.sh <로그 파일>`: 요약 줄에서 실행된 테스트 수를 읽는다.
  - 지원하는 형식은 pytest(`N passed`), jest(`Tests: … N passed`), vitest(`Tests  N passed`), cargo(`test result: ok. N passed` 를 모두 합산), go(`ok` 줄 수, `[no test files]` 는 0), `node --test`(`# pass N`)다.
  - 종료 코드: 0 은 1개 이상(표준 출력에 개수), 1 은 0개, 2 는 알아보지 못함이다.
  - 형식별 픽스처 로그로 테스트한다.
- `templates/tests.yml`
  - `run:` 은 블록 스칼라(`run: |`)로 쓴다. 명령에 `#` 나 `: ` 가 있어도 YAML 이 깨지지 않게 하기 위해서다.
  - `__DEFAULT_BRANCH__` 에는 진입점이 잰 값을 넣는다.
  - matrix 는 유지한다. 필수 검사 이름은 실제 실행에서 읽기 때문이다(결정 5).
- `scripts/wait-run.sh <워크플로 파일명> <커밋 SHA>`
  - `gh run list --workflow <파일> --commit <SHA> --json databaseId,status,conclusion` 을 실행이 나타날 때까지 5초 간격으로 최대 24번 조회한다.
  - 실행이 나타나면 `gh run watch <id> --exit-status` 로 끝까지 본다.
  - 종료 코드: 0 성공, 1 실패, 2 실행이 나타나지 않음.
  - 가짜 gh 로 테스트한다.

### 3.6 secure

- `check-workflow-security.sh` 와 `templates/codeql.yml` 을 지운다.
- `scripts/secret-scanning.sh [--apply]`
  - 계획 단계에서 `GET repos/{o}/{r}` 의 `.security_and_analysis` 를 읽고, secret scanning 과 push protection 을 `enabled` 로 바꾸는 `PATCH` 를 계획한다.
  - 기능을 쓸 수 없는 저장소(필드가 없거나 PATCH 가 거절됨)는 exit 2 다.
- `scripts/code-scanning.sh [--apply]`
  - 계획 단계에서 `GET repos/{o}/{r}/code-scanning/default-setup` 을 읽는다.
  - 403 "Code scanning is not enabled" 나 GHAS·Code Security 가 없으면 exit 2 로 보고하고 건너뛴다.
  - `.github/workflows/` 에 `github/codeql-action/analyze` 를 쓰는 고급 설정 워크플로가 있으면 건드리지 않고 exit 2 다.
  - 그 밖에는 `PATCH …/default-setup` 에 `{"state":"configured"}` 를 보내고, 되읽어 `state` 가 `configured` 인지 확인한다.
- `templates/zizmor.yml`: `unpinned-uses` 정책으로 모든 액션에 SHA 고정을 요구한다. 형식은 7절에서 확인한다.
- `templates/zizmor-workflow.yml`
  - `.github/**` 가 바뀌는 `pull_request` 와 main 푸시에서 zizmor 를 고정한 버전으로 돌린다.
  - 판정은 plain 형식의 종료 코드로 한다(low 이상이면 실패). SARIF 형식은 종료 코드를 끄기 때문이다(6절의 출처 3).
  - 코드 스캐닝을 쓸 수 있는 저장소에서는 SARIF 업로드 단계를 따로 더한다. 권한은 기본 `contents: read` 이고, 업로드 job 에만 `security-events: write` 를 준다.
- `templates/dependabot.yml` 은 유지하되 zizmor 를 통과하게 고친다(예: `dependabot-cooldown`). codeql-action 묶음은 zizmor 워크플로가 그 액션을 쓸 때만 남긴다.
- PROCEDURE.md 순서:
  1. 실측
  2. secret-scanning 계획 → 확인 → `--apply`
  3. dependabot
  4. code-scanning 계획 → 확인 → `--apply`
  5. zizmor 설정과 워크플로를 놓는다
  6. SHA 를 고정한다(결정 6)
  7. `GH_TOKEN="$(gh auth token)" zizmor --min-severity=low .github/` 가 exit 0 이어야 한다
  8. 보고

### 3.7 쓰기 스크립트의 공통 규칙 (`secret-scanning.sh`, `code-scanning.sh`, `ruleset.sh`)

- 대상 저장소는 현재 폴더에서 `gh repo view --json nameWithOwner` 로 정한다.
- 인자 없이 돌리면 `current:` 줄에 현재 값을, `plan:` 줄에 보낼 요청(메서드, 경로, JSON 본문)을 출력한다. 아무것도 바꾸지 않는다.
- `--apply` 를 주면 보낸 뒤 GET 으로 되읽어 기대값과 비교하고, `revert:` 줄에 되돌리는 명령을 출력한다.
- 종료 코드
  - 0: 계획 출력 성공, 또는 적용하고 확인까지 됨
  - 1: 적용 실패, 또는 되읽은 값이 기대와 다름
  - 2: 판단 불가(gh 없음, 인증 없음, 권한 없음, 플랜이 기능을 지원하지 않음, 원격이 GitHub 이 아님)
- 팀 저장소에서는 절차 문서가 `--apply` 를 부르지 않는다. 계획을 제안으로 보고한다.
- 테스트: `tests/<목적>/` 에 가짜 `gh` 를 두고 PATH 앞에 넣는다. 가짜 gh 는 받은 요청을 파일에 기록하고 준비된 응답과 종료 코드를 돌려준다. 가짜 응답은 실제 API 응답과 어긋날 수 있으므로, 실제 동작은 8절에서 따로 증명한다.

### 3.8 contrib

- `templates/CODEOWNERS`, `templates/ISSUE_TEMPLATE/`, `templates/pull_request_template.md`, `check-contrib.sh` 를 지운다.
- `scripts/community-defaults.sh`
  - CONTRIBUTING.md 와 SECURITY.md 를 두 곳에서 찾는다. 하나는 대상 저장소의 `.github/`, 루트, `docs/`(GitHub 의 우선순위 순서)다. 다른 하나는 소유자의 공개 `.github` 저장소의 같은 세 자리다(`gh api repos/{owner}/.github/contents/{path}`).
  - 찾은 파일마다 출처를 출력한다.
  - 종료 코드: 0 둘 다 있음, 1 빠진 것 있음(이름 출력), 2 판단 불가.
- CONTRIBUTING.md 와 SECURITY.md 는 저장소에도 소유자 기본값에도 없을 때만 놓는다.
- `templates/CONTRIBUTING.md` 의 "커밋 가드가 걸려 있다" 문장은 `__GUARD_NOTE__` 자리표시자로 바꾼다. privacy 를 깔았을 때만 채우고, 아니면 그 줄을 지운다. `__TEST_COMMAND__` 에는 ci 가 확인한 명령을 넣는다.
- `scripts/ruleset.sh [--apply] --branch <이름> [--commit <SHA>]`
  - `--commit` 을 주면 `gh api repos/{o}/{r}/commits/{SHA}/check-runs` 에서 `status == completed` 이고 `conclusion == success` 인 check 의 `name` 과 `app.id` 를 읽어 `required_status_checks` 를 만든다.
  - `--commit` 이 없거나 해당하는 check 가 없으면, 필수 검사 없이 나머지 세 규칙만 건다고 계획에 적는다.
  - 룰셋 이름은 `repo-setup: <branch>` 다. 같은 이름의 룰셋이 있으면 PUT 으로 갱신하고, 없으면 POST 로 만든다.
  - `bypass_actors` 는 저장소 관리자 역할(`RepositoryRole`)에 `bypass_mode: pull_request` 를 준다. 관리자 역할의 `actor_id` 는 7절에서 확인하고, 확인하지 못하면 exit 2 다.
  - 되읽을 때는 `gh api repos/{o}/{r}/rules/branches/{branch}` 로 네 규칙이 모두 걸렸는지 본다. `revert:` 는 `gh api -X DELETE repos/{o}/{r}/rulesets/{id}` 다.

### 3.9 이 저장소 자체

- ①: `.github/workflows/test.yml`
  - 트리거는 `pull_request` 와 main 푸시이고, matrix 는 `ubuntu-latest` 와 `macos-latest` 다.
  - `concurrency` 는 `cancel-in-progress: true` 이고, `permissions` 는 `contents: read` 이며, 액션은 SHA 로 고정한다.
  - 단계는 checkout, shellcheck 준비(러너별 설치 방법은 7절에서 확인), `.check.toml` 의 `test_command`, CLAUDE.md 의 shellcheck 명령 순서다.
- ⑥ 뒤: 자체 CI 에 zizmor job 을 더한다. 대상은 이 저장소의 `.github/workflows/` 다.
- ②: `tests/invariants.sh` 를 새 구조에 맞춘다.
  - 스킬 수는 1이다.
  - 진입점 표의 목적 이름 집합이 목적 폴더 집합과 같아야 한다.
  - 목적 폴더마다 `PROCEDURE.md` 가 있어야 한다.
  - SKILL.md 와 PROCEDURE.md 가 가리키는 `<목적>/(scripts|templates)/…` 경로가 실제로 있어야 한다.
  - `scripts/*.sh` 와 훅 템플릿에 실행 비트가 있어야 한다.
  - 루트 사본이 새 경로의 템플릿과 같아야 한다.
  - 본문이 `../` 나 저장소 루트의 `docs/` 를 가리키면 안 된다. 지금 검사는 `../` 만 보아서 `docs/decisions.md` 참조를 놓친다.
  - 매니페스트 description 대조는 유지한다.
- ②: CLAUDE.md 의 구조 절과 shellcheck 글롭, README, `docs/decisions.md` 를 새 구조로 고친다. 각 목적의 세부 문서는 그 목적의 PR 에서 고친다.

## 4. PR 순서

| # | 제목 | 라벨 | 선행 | 완료 조건 |
|---|---|---|---|---|
| ① | `ci: 테스트와 shellcheck 를 ubuntu 와 macOS 에서 돌린다` | 없음(`ci` 에 맞는 라벨이 없다. PR 본문에 적는다) | 없음 | 두 러너에서 초록. 이 스펙 문서 포함 |
| ② | `refactor(skill)!: 좁은 스킬 다섯을 repo-setup 의 목적별 폴더로 합친다` | `breaking`(새로 만든다) | PR #1, ① | 동작 변화 없이 파일 이동, frontmatter, 진입점, invariants, 문서, 0.2.0. 기계적 이동과 내용 변경을 섞지 않는다 |
| ③ | `fix(privacy): 추가된 줄만 검사하고 공용 계정 경로를 막지 않는다` | `bug` | ② | 3.3 의 ③ |
| ④ | `feat(privacy): 커밋 메시지도 가드가 검사한다` | `enhancement` | ② | 3.3 의 ④ |
| ⑤ | `fix(privacy): 훅이 아닌 파일에 실행 비트를 붙이지 않는다` | `bug` | ② | 3.3 의 ⑤ |
| ⑥ | `feat(secure)!: 워크플로 검사를 zizmor 로, CodeQL 을 default setup 으로 바꾼다` | `enhancement`, `breaking` | ② | 3.6, 3.7 |
| ⑦ | `fix(license): 알아보지 못한 본문에 이름을 붙이지 않는다` | `bug` | ② | 3.4 |
| ⑧ | `fix(ci): 테스트가 실제로 돈 것을 보고 워크플로를 놓는다` | `bug` | ② | 3.5, 기본 브랜치 실측(3.2) |
| ⑨ | `feat(contrib)!: 브랜치 보호를 룰셋으로 옮기고 골격 셋을 뺀다` | `enhancement`, `breaking` | ⑧ | 3.7, 3.8 |
| ⑩ | `docs: CLAUDE.md 에서 테스트 건수와 낡은 문장을 뺀다` | `documentation` | ② | 건수 제거. "repo-privacy 가 템플릿 둘을 본문에 품는다" 같은 낡은 문장 정리 |

- 모든 PR 은 저장소 규칙대로 **테스트를 먼저 쓰고 RED 를 확인한 뒤** 구현한다.
- PR 본문은 main 에 그대로 남을 글로 쓴다. 제목은 `type(scope): 요약` 이다.
- ③~⑧ 과 ⑩ 은 ② 뒤라면 서로 순서가 없다.

## 5. 범위 밖

- 언어별 도구 체인과 `.gitignore` 전체. `docs/decisions.md` 1절과 3절을 유지한다.
- Codex, Antigravity 에서의 실제 실행 검증. `npx skills` 탐색 경로 불변식만 유지한다.
- 조직 수준 룰셋, GHAS 와 Code Security 구매·설정.
- zizmor 말고 다른 워크플로 린터(actionlint 등)와 자동 고정 도구(pinact 등).
- 이미 공개된 이력의 재작성(작성자 이메일 등).
- 가드 예외 목록을 설정으로 늘리는 기능.
- Git Bash 가 아닌 Windows 네이티브 셸에서의 실행.

## 6. 확인한 외부 사실

모두 2026-09-22 에 확인했다. "공식 문서"는 링크한 문서를 열어 해당 문장을 확인했다는 뜻이고, "실측"은 이 저장소에서 명령을 돌린 결과다.

1. **공식 문서**, Claude Code [Skills](https://code.claude.com/docs/en/skills): `disable-model-invocation` 은 "Set to `true` to prevent Claude from automatically loading this skill."(번역: `true` 로 두면 Claude 가 이 스킬을 자동으로 불러오지 못한다.) 같은 문서의 표에서 Skill 도구로 부르는 것도 막히고, 시도하면 "Claude Code blocks the call"(번역: Claude Code 가 호출을 막는다)이라고 적혀 있다. 지원 파일에 대해서는 "Skills can include multiple files in their directory."(번역: 스킬은 자기 폴더 안에 여러 파일을 둘 수 있다.)
2. **공식 문서**, [zizmor audits](https://docs.zizmor.sh/audits/): 규칙 41개 가운데 `unpinned-uses`, `excessive-permissions`(워크플로 수준과 job 수준), `dangerous-triggers`(`pull_request_target`, `workflow_run`, `issue_comment`), `impostor-commit`, `ref-version-mismatch` 가 있다. `unpinned-uses` 는 자동 수정을 지원하지 않는다("Auto-fixes available: ❌").
3. **공식 문서**, [zizmor usage](https://docs.zizmor.sh/usage/): 입력으로 `my-action/action.yml` 같은 composite action 정의를 받는다. `--min-severity`, `--min-confidence`, `--persona`(regular, pedantic, auditor)가 있다. 종료 코드 11~14 는 가장 높은 발견의 심각도이고, SARIF 형식은 이 종료 코드를 끈다. 온라인 모드는 `GH_TOKEN` 같은 토큰이 있을 때 켜진다.
4. **공식 문서**, [About code scanning](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning): "If you want to use code scanning on private repositories, you need a GitHub Code Security license."(번역: 비공개 저장소에서 코드 스캐닝을 쓰려면 GitHub Code Security 라이선스가 필요하다.)
5. **공식 문서**, [Code scanning REST](https://docs.github.com/en/rest/code-scanning/code-scanning#update-a-code-scanning-default-setup-configuration): `PATCH /repos/{owner}/{repo}/code-scanning/default-setup` 의 본문은 `state`, `query_suite`, `languages` 이고, "Response if the repository is archived or if GitHub Advanced Security is not enabled"(번역: 저장소가 보관됐거나 GitHub Advanced Security 가 켜져 있지 않을 때의 응답) 가 403 이다.
6. **공식 문서**, [Repository rules REST](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset): `bypass_mode` 는 `always`, `pull_request`, `exempt` 셋이다. "pull_request means that an actor can only bypass rules on pull requests."(번역: pull_request 는 행위자가 풀 리퀘스트에서만 규칙을 우회할 수 있다는 뜻이다.) `required_status_checks` 의 항목은 `context`(필수)와 `integration_id`(선택)다. `non_fast_forward`, `deletion`, `pull_request` 규칙이 있다.
7. **공식 문서**, [Creating a default community health file](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file): 조직뿐 아니라 개인 계정도 기본값을 둘 수 있다. "The `.github` repository must be public."(번역: `.github` 저장소는 공개여야 한다.) 우선순위는 `.github` 폴더, 루트, `docs` 폴더 순이다. 목록에 CODEOWNERS 는 없다.
8. **공식 문서**, [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions): 공개 저장소의 표준 러너는 무료다. 비공개 저장소에는 GitHub Free 가 2,000분, Pro 가 3,000분을 포함한다. 분당 요금은 Linux 2코어 $0.006, macOS $0.062 다.
9. **실측**(이 저장소, 비공개였던 시점)
   - `gh api repos/IsthisLee/repo-setup/code-scanning/default-setup` → HTTP 403 "Code scanning is not enabled for this repository."
   - `gh api repos/IsthisLee/repo-setup/rulesets` → HTTP 200, 0개. 만들 수 있다는 증거는 아니다.
   - `gh api repos/IsthisLee/repo-setup/community/profile` → 응답은 왔지만 `files` 에 `security` 키가 없다.
   - 그 뒤 `gh repo edit --visibility public` 으로 공개로 바꿨다. 공개하기 전에 전체 이력(커밋 17개)에서 홈 경로, 흔한 비밀 형식, `.private/`, 개인 패턴이 추가된 줄이 모두 0건임을 확인했다.

## 7. 구현 전에 확인할 것 (아직 확인하지 않음)

- zizmor: `zizmor.yml` 에서 `unpinned-uses` 정책을 쓰는 정확한 형식, 설정 파일을 찾는 위치, 예외를 적는 형식, `impostor-commit`·`ref-version-mismatch` 가 온라인 모드를 요구하는지, 공식 설치 명령, 대상 CI 에서 돌리는 방법(공식 액션인지 패키지 설치인지)과 버전 고정 방법.
- 룰셋: `RepositoryRole` 의 저장소 관리자 `actor_id`, 개인 계정의 공개 저장소에서 룰셋을 만들 수 있는지, check-runs 의 `app.id` 가 `integration_id` 로 그대로 통하는지.
- 코드 스캐닝 default setup: `languages` 를 빼면 GitHub 이 언어를 고르는지, 응답이 202 인지와 되읽기에 걸리는 시간, 고급 설정 워크플로가 있을 때의 응답.
- secret scanning: 쓸 수 없는 저장소에서 `PATCH` 가 내는 상태 코드와 메시지.
- GitHub 라이선스 템플릿: 지원할 키마다의 자리표시자 목록(`[year]`, `[fullname]` 외).
- macOS 러너와 ubuntu 러너에 shellcheck 가 미리 깔려 있는지, 없으면 설치 방법.
- 이전 판에서 옮겨 오기: 플러그인으로 설치한 경우 업데이트할 때 옛 스킬이 사라지는지, `npx skills` 로 설치한 경우 옛 스킬 폴더를 지우는 명령.

확인하지 못한 항목은 스펙대로 구현하지 말고, 그 사실과 대안을 사용자에게 묻는다.

## 8. 종단 검증

### 8.1 PR 마다

```bash
tests/guard/unit.sh && tests/setup/unit.sh && tests/license/unit.sh && tests/ci/unit.sh \
  && tests/secure/unit.sh && tests/contrib/unit.sh && tests/invariants.sh
shellcheck -x -s bash <CLAUDE.md 에 적힌 대상>
gh pr checks <PR 번호>
```

- 테스트는 모두 `실패 0건`(invariants 는 `전부 통과`)을 출력하고 exit 0 이어야 한다.
- shellcheck 는 rc 0 이어야 한다.
- `gh pr checks` 에서 ubuntu 와 macOS 두 job 이 모두 `pass` 여야 한다.
- 테스트 이름과 개수는 바뀔 수 있다. 판정은 종료 코드로 한다.

### 8.2 가드 (③④⑤ 뒤, 로컬 임시 저장소)

`privacy/templates/` 의 파일을 새 임시 저장소에 복사하고 `./setup.sh` 를 돌린 뒤, 실제 `git commit` 으로 확인한다.

| 경우 | 기대 |
|---|---|
| 새 파일에 홈 경로(`/Users` 뒤에 영문 이름) | 차단 |
| 이미 홈 경로가 든 파일에서 다른 줄만 고침 | 통과 |
| Dockerfile 에 홈 폴더 아래 `node` 경로를 새로 씀 | 통과 |
| 같은 줄에 홈 폴더 아래 `runner` 경로와 `/Users` 뒤 영문 이름이 함께 있음 | 차단 |
| Windows 경로(드라이브 뒤 `\Users\` 와 영문 이름) | 차단 |
| 커밋 메시지에 홈 경로 | 차단(commit-msg) |
| 커밋 메시지의 `#` 주석 줄에만 홈 경로 | 통과 |

그리고 다음을 확인한다.

- `./setup.sh --verify` 는 `검증 통과` 와 exit 0 을 내야 하고, pre-commit 과 commit-msg 를 모두 탐침해야 한다.
- `.githooks/team-patterns` 가 있는 저장소에서 `./setup.sh` 를 돌린 뒤 `git status --porcelain` 에 모드 변경이 없어야 한다.

### 8.3 처음 세팅하는 경로 (⑨ 뒤, 공개 임시 저장소)

1. 사용자에게 확인받은 뒤 `gh repo create IsthisLee/repo-setup-e2e --public --clone` 을 실행한다. 저장소에는 pytest 테스트 하나를 가진 작은 파이썬 프로젝트만 두고, LICENSE 와 워크플로는 두지 않는다.
2. 그 저장소에서 `/repo-setup` 을 인자 없이 돌린다. `--apply` 는 매번 확인받는다.
3. 아래가 모두 기대대로 나와야 한다.

| 목적 | 명령 | 기대 |
|---|---|---|
| privacy | `./setup.sh --verify` | `검증 통과`, exit 0 |
| license | `check-license.sh --expect mit --year 2026 --holder <이름>` | exit 0. 푸시한 뒤 `gh api repos/IsthisLee/repo-setup-e2e/license --jq .license.spdx_id` → `MIT` |
| ci | `wait-run.sh tests.yml "$(git rev-parse HEAD)"` | exit 0. `check-test-run.sh` 가 1 이상 |
| secure | `gh api repos/IsthisLee/repo-setup-e2e --jq '.security_and_analysis \| .secret_scanning.status, .secret_scanning_push_protection.status'` | `enabled` 두 줄 |
| secure | `gh api repos/IsthisLee/repo-setup-e2e/code-scanning/default-setup --jq .state` | `configured` |
| secure | `GH_TOKEN="$(gh auth token)" zizmor --min-severity=low .github/` | exit 0. zizmor 워크플로 실행도 성공 |
| contrib | `gh api repos/IsthisLee/repo-setup-e2e/rules/branches/main --jq '[.[].type] \| sort'` | `deletion`, `non_fast_forward`, `pull_request`, `required_status_checks` 가 모두 있음 |
| contrib | 빈 커밋을 main 으로 직접 `git push` | 룰 위반으로 거절 |
| contrib | 같은 커밋을 PR 로 올림 | 필수 검사가 이름대로 나타나고, 통과한 뒤 병합 가능 |

4. 사람이 `gh auth refresh -s delete_repo` 를 직접 실행한다. 삭제 직전에 다시 확인받고 `gh repo delete IsthisLee/repo-setup-e2e --yes` 를 실행한다.

### 8.4 이미 도구가 있는 저장소에 얹는 경로 (⑨ 뒤, 이 저장소)

이 저장소에서 `/repo-setup` 을 돌린다. `--apply` 는 매번 확인받는다.

| 확인 | 기대 |
|---|---|
| `check-license.sh`(인자 없음) | exit 0, MIT. LICENSE 를 다시 쓰지 않음 |
| `.github/workflows/test.yml` | 내용이 그대로이고 tests.yml 을 새로 만들지 않음 |
| `./setup.sh` | 이미 걸린 `.githooks` 를 멱등으로 통과 |
| `secret-scanning.sh`, `code-scanning.sh` | 적용 뒤 되읽기 일치, exit 0 |
| `ruleset.sh --branch main --commit <main 의 최근 SHA>` | 필수 검사에 ubuntu 와 macOS 두 check 이름과 앱 id 가 들어감. `gh api repos/IsthisLee/repo-setup/rules/branches/main` 에 네 규칙 |

이 저장소에서는 main 으로 직접 푸시해 보는 시험을 하지 않는다. 설정이 틀렸다면 그 커밋이 main 에 남기 때문이다. 되읽기로만 확인한다.

## 9. 진행 상황

| # | 상태 | PR |
|---|---|---|
| PR #1 | 열림, 병합 대기 | https://github.com/IsthisLee/repo-setup/pull/1 |
| ① | 대기 | |
| ② ~ ⑩ | 대기 | |
