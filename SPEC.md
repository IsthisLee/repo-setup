# 스펙: 스킬을 하나로 합치고 추정기를 검증된 도구로 바꾼다

- 상태: 확정(2026-09-22 인터뷰 두 차례). 구현은 새 세션에서 4절의 PR 순서대로 한다.
- 선행: PR #1 `fix(privacy): 가드가 조용히 꺼지는 경로 넷을 막는다` 가 main 에 병합돼 있어야 ③ 부터 시작할 수 있다. ③ 가 repo-privacy 파일을 옮기므로, PR #1 보다 먼저 병합하면 충돌한다.
- 이 문서는 홈 경로를 글자 그대로 적지 않는다. 이 저장소의 가드와 `tests/invariants.sh` 가 추적 파일에 든 홈 경로를 막기 때문이다. 경로가 필요한 자리는 "홈 폴더 아래 `runner`" 처럼 풀어서 쓴다. 테스트는 지금처럼 경로를 실행할 때 조립한다.

## 1. 왜

2026-09-22 코드 리뷰와 인터뷰에서 확인한 문제는 다섯이다.

1. **진입점이 좁은 스킬을 부를 수 없다.** 좁은 스킬 다섯이 모두 `disable-model-invocation: true` 이고, 이 설정은 Skill 도구 호출까지 막는다(6절의 출처 1). 그래서 `plugin/skills/repo-setup/SKILL.md` 3단계 "좁은 스킬을 호출한다"는 Claude Code 에서 동작하지 않는다.
2. **직접 만든 추정기가 틀린 답을 확신하며 내놓는다.** 리뷰 항목 7~12번이 여기서 나왔다.
   - `check-license.sh` 는 제3자 고지에 적힌 "MIT License" 를 보고 독점 라이선스를 MIT 로 판정한다.
   - `find-test-command.sh` 는 테스트가 0개인 `Cargo.toml` 을 보고 테스트가 있다고 판정한다.
   - `check-workflow-security.sh` 는 따옴표로 감싼 SHA 를 오탐하고 composite action 을 보지 않는다.
   - `check-contrib.sh` 는 조직 기본값을 보지 않는다.
3. **부작용이 있는 절차가 SKILL.md 본문에 테스트 없이 들어 있다.**
   - 브랜치 보호 PUT 의 필수 검사 이름이 `test` 인데, 실제 check 이름은 matrix 때문에 `test (ubuntu-latest)` 라서 모든 PR 이 영원히 기다린다.
   - 기본 브랜치를 `git symbolic-ref --short HEAD`(현재 브랜치)로 구한다.
   - `gh run list --limit 1` 이 이전 커밋의 실행을 증거로 집는다.
4. **사용자가 무엇에 동의하는지 모른 채 세팅이 진행된다.** 진입점은 "용도가 모호하거나 되돌리기 어려운 항목이 섞일 때"만 확정을 받는다(main 판 `SKILL.md:59`). 파일을 쓰기 전에 확인하는 자리가 없고, 처음 보는 사람을 위한 설명 형식도 없다. 이미 개발 중인 저장소에 얹을 때 변경을 어디에 올리는지, 룰셋이 열린 PR 과 자동화에 어떤 영향을 주는지, 기존 워크플로의 zizmor 발견을 어떻게 처리하는지도 정해져 있지 않다.
5. **이 저장소 자체에 CI 가 없다.** 테스트가 macOS(bash 3.2, BSD grep)에서만 돌았고, Linux(bash 5, GNU grep)에서는 한 번도 확인하지 않았다. 두 grep 은 실제로 다르게 동작한다. 예를 들어 BSD grep 은 `a|` 를 문법 오류(exit 2)로 거부한다(2026-09-22 실측).

## 2. 확정한 결정

| # | 주제 | 결정 |
|---|---|---|
| 1 | 스킬 구조 | `repo-setup` 하나만 스킬로 남기고 `disable-model-invocation: true` 를 유지한다. 지금의 다섯은 그 폴더 안의 목적별 폴더가 되고, 진입점은 고른 목적의 절차 문서만 읽는다. `/repo-setup license` 처럼 인자로 목적 하나만 고를 수도 있다 |
| 2 | 판정 수단 | 가드(`pre-commit`, `commit-msg`)와 설정 스크립트 `script/setup` 은 계속 bash 와 git 만 쓴다. 나머지 판정은 `gh`(GitHub API)와 zizmor 가 맡고, `gh` 는 필수다 |
| 3 | 제거 | `codeql.yml` 골격, contrib 골격 셋(CODEOWNERS, `ISSUE_TEMPLATE/`, PR 템플릿), CLAUDE.md 의 테스트 건수, `find-test-command.sh`, `check-workflow-security.sh`, `check-contrib.sh`, license 의 python3 폴백 |
| 4 | main 보호 | 룰셋으로 옮긴다. 규칙은 넷이다. `pull_request`(승인 0명), `required_status_checks`(strict), `non_fast_forward`, `deletion`. 우회는 저장소 관리자만 `bypass_mode: pull_request` 로 허용한다. 팀 저장소는 계획만 보이고 적용하지 않는다 |
| 5 | 필수 검사의 출처 | 워크플로가 실제로 돈 커밋의 check-runs 에서 이름과 앱 id 를 읽어 `context` 와 `integration_id` 로 건다. 어느 것을 필수로 둘지는 결정 19 로 사람이 고른다. 완료된 실행이 없으면 필수 검사를 걸지 않고 그 사실을 보고한다 |
| 6 | SHA 고정 | 에이전트가 `gh api repos/{owner}/{repo}/commits/{ref} --jq .sha` 로 SHA 를 얻어 `uses:` 를 고치고 `# {ref}` 주석을 남긴다. 결과는 zizmor 로 검증한다. 고정 스크립트는 만들지 않는다 |
| 7 | zizmor | 로컬에서 한 번 돌리고, 대상 저장소에도 워크플로로 둔다. `regular` 페르소나에 `--min-severity=low` 로 돌려 low 이상이면 실패시킨다. `zizmor.yml` 로 모든 액션에 SHA 고정을 요구하고, 예외는 `zizmor.yml` 에 이유 주석과 함께 적을 때만 인정한다. 설치돼 있지 않으면 설치 명령을 보이고 멈춘다(자동 설치하지 않는다). 기존 발견은 결정 20 으로 처리한다 |
| 8 | 테스트 판정 | 에이전트가 후보 명령을 로컬에서 실제로 돌리고, 테스트된 판독 스크립트가 요약 줄에서 개수를 읽는다. 0개면 워크플로를 놓지 않는다. 알아보지 못하면 exit 2 로 돌리고, 출력 끝 20줄을 보여 주며 사람에게 확인받는다 |
| 9 | 쓰기 스크립트 | 인자 없이 돌리면 계획만 출력하고, `--apply` 를 줘야 보낸다. 보낸 뒤에는 되읽어 확인하고 되돌리는 명령을 출력한다. 종료 코드는 0·1·2 셋이다(3.7절) |
| 10 | privacy 나머지 | 셋 모두 넣는다. (a) 내용 검사는 추가된 줄만 하고(바이너리는 blob 전체), 내장 예외 넷을 두고, Windows 경로를 더한다. (b) `commit-msg` 훅으로 커밋 메시지도 검사한다. (c) `script/setup` 이 훅이 아닌 파일에 실행 비트를 붙이지 않는다 |
| 11 | 내장 홈 경로 예외 | 홈 폴더(`/home/`) 바로 아래가 정확히 `runner`, `node`, `vscode`, `linuxbrew` 인 경로만 예외다. macOS 의 공용 폴더(Users 아래 Shared)와 클라우드 기본 계정(`ubuntu`, `ec2-user`)은 계속 막는다. 예외 목록은 훅에 박힌 고정 목록이고 설정으로 늘릴 수 없다 |
| 12 | 자체 CI | `pull_request` 와 main 푸시에서 `ubuntu-latest` 와 `macos-latest` 로 돌린다. 같은 브랜치에 새로 푸시하면 이전 실행을 취소하고, 권한은 `contents: read` 만 주며, 액션은 SHA 로 고정한다. 저장소가 공개로 바뀌어(2026-09-22) 표준 러너는 무료다 |
| 13 | 호환성 | `breaking` 라벨을 만들어 ③ 에 붙이고, 두 매니페스트를 0.2.0 으로 올린다. README 에 이전 판에서 옮겨 오는 방법을 적는다 |
| 14 | PR 분할 | 기능별로 나눈다(4절, 14개). squash 병합이므로 PR 하나가 main 의 커밋 하나가 된다. 처음에는 10개였고, 두 번째 인터뷰에서 확인 흐름과 변경 전달(④)이, 세 번째 인터뷰에서 문서 구조 전환(②)과 가드를 켜는 방식 둘(⑧, ⑨)이 더해졌다 |
| 15 | 종단 검증 | 공개 임시 저장소 둘(처음 세팅하는 저장소, 활발한 저장소를 흉내 낸 저장소)과 이 저장소에서 한다(8절) |
| 16 | 스펙 위치와 수명 | 이 파일은 저장소 루트의 `SPEC.md` 이고 ① 과 함께 커밋한다. 파일 이름에 날짜를 넣지 않는다(날짜는 git 이력과 이 문서 첫 줄에 있다). 진행 중인 계획만 담는 임시 문서다. 각 PR 은 구현한 기능의 무엇·어떻게를 wiki 페이지에(결정 22), 왜를 ADR 에(결정 21) 같은 PR 안에서 옮긴다. 마지막 PR ⑭ 에서 2절의 결정이 모두 wiki, ADR, 코드·테스트 중 한 곳으로 옮겨졌는지 확인한 뒤 이 파일을 지운다 |
| 17 | 확인 흐름 | 두 층으로 받는다. 먼저 실측 결과와 함께 목적마다 설명 카드를 보여 주고 적용할 목적을 고르게 한다. 그다음 고른 목적 안에서 부작용이 있는 단계마다 다시 확인받는다. 설명 카드는 처음 보는 사람도 이해할 수 있게 쓰되 실무적인 깊이를 갖춘다(3.2.2) |
| 18 | 변경 전달 | 작업 트리에 추적 파일의 변경이 있으면 시작하지 않는다. 기본 브랜치의 최신 상태에서 `repo-setup/<YYYY-MM-DD>` 브랜치를 만들어 목적마다 커밋하고, PR 하나로 올린다. main 에는 직접 커밋하지 않는다. GitHub 설정은 확인을 받은 뒤 API 로 바꾸고, 룰셋은 세팅 PR 이 병합된 뒤에 건다(3.2.3) |
| 19 | 필수 검사 선택 | 실제 실행에서 읽은 check 를 모두 보여 주고, 각각이 어느 워크플로의 것인지와 그 워크플로에 `paths`·`paths-ignore`·`branches` 필터나 job `if` 조건이 있는지를 표시한다. 필터나 조건이 있는 check 는 기본으로 빼 두고, 사람이 필수로 둘 것을 고른다. 걸기 전에 열린 PR 가운데 멈출 PR 과, PR 없이 main 에 들어온 최근 커밋을 보고한다 |
| 20 | zizmor 기존 발견 | 처음 검사의 발견을 규칙별로 묶어 보여 주고, 에이전트가 고칠 것과 사람이 판단할 것으로 나눈다. 고칠 것은 고치고, 남길 것은 `zizmor.yml` 에 이유 주석과 함께 예외로 적는다. 로컬 검사가 0건이 된 뒤에만 차단하는 zizmor 워크플로를 놓는다. 기존 워크플로를 고치는 변경은 세팅 PR 안에서 별도 커밋으로 두고, 고친 파일과 줄 수를 보고한다 |
| 21 | 설계 근거의 자리 | `docs/decisions.md` 를 결정 하나에 파일 하나인 ADR(`docs/adr/`)로 나눈다(3.10). 실행 규칙(선택 조건, 순서)은 `SKILL.md` 한 곳에만 두고, ADR 에는 "왜"만 둔다. `docs/decisions.md` 는 ② 에서 지운다 |
| 22 | 구현된 기능의 설명 | `docs/wiki/` 에 기능마다 페이지를 두고, 지금 구현된 것이 무엇을 하고 어떻게 동작하며 무엇을 바꾸고 어디까지 못 하는지 적는다. 이유는 쓰지 않고 해당 ADR 을 링크한다. 세팅 중에 사용자에게 보이는 카드 문구는 `PROCEDURE.md` 가 정본이고, wiki 는 그것을 옮겨 적지 않고 링크한다(3.11) |
| 23 | README | 무엇인지, 설치, 첫 실행, 목적 다섯의 한 줄 요약, wiki 로 가는 링크만 남기고 100줄 안팎으로 줄인다. 기능의 세부는 wiki 에만 둔다. 존댓말(합니다체)로 쓴다. 모든 저장소의 README 에 적용하는 전역 규칙이다(2026-09-22 사용자 지시). wiki, ADR, SPEC.md, CLAUDE.md, 스킬 본문은 지금처럼 '~한다' 체로 둔다 |
| 24 | 가드를 켜는 방식 | 켜는 층을 둘로 둔다. **(1) PR 검사:** 모든 대상 저장소에 PR 과 main 푸시마다 가드를 돌리는 워크플로를 두고, 룰셋의 필수 검사 후보로 올린다. 누구도 설치하지 않아도 병합 전에 잡힌다. 다만 푸시한 뒤에 돌기 때문에 공개 저장소에서는 "새는 것을 막지" 못하고 "새었다고 알릴" 뿐이며, 개인 패턴 파일은 CI 에 없어 내장 홈 경로와 팀 패턴만 본다. **(2) 로컬 훅:** 저장소가 이미 쓰는 도구에 얹는다. husky, pre-commit 프레임워크, lefthook 중 하나가 있으면 그 설정에 가드를 등록한다. 없고 `package.json` 이 있으면 husky 를 더한다(`"prepare": "husky"`, 팀원은 `npm install` 만). 어느 것도 없으면 설정 스크립트 `script/setup` 을 둔다. 컴퓨터당 한 번 켜는 방식(git 템플릿 폴더)은 쓰지 않는다(2026-09-22 사용자 결정) |
| 25 | 설정 스크립트의 이름 | `setup.sh` 를 `script/setup` 으로 옮긴다. GitHub 의 "Scripts To Rule Them All" 관례에서 `script/setup` 은 처음 클론한 뒤에 실행하는 스크립트다(6절의 출처 16). 이름을 바꾸는 일은 기계적 변경이므로 파일을 옮기기만 하는 ③ 에 넣는다 |

## 3. 목표 구조와 인터페이스

### 3.1 폴더

```
plugin/skills/repo-setup/
  SKILL.md                  진입점: 실측, 설명 카드, 선택, 순서, 변경 전달, 보고
  privacy/
    PROCEDURE.md
    templates/pre-commit      → 대상 .githooks/pre-commit
    templates/commit-msg      → 대상 .githooks/commit-msg      (⑥)
    templates/lib/guard.sh    → 대상 .githooks/lib/guard.sh    (⑥, 두 훅이 source)
    templates/setup           → 대상 script/setup      (③ 에서 setup.sh 를 옮긴다)
    templates/guard-workflow.yml → 대상 .github/workflows/guard.yml  (⑧)
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
- 이 저장소 루트의 `.githooks/pre-commit`, `.githooks/commit-msg`, `.githooks/lib/guard.sh`, `script/setup` 은 `privacy/templates/` 의 사본으로 둔다. invariants 가 일치를 본다.

### 3.2 진입점 `SKILL.md`

- frontmatter: `name: repo-setup`, `disable-model-invocation: true`, `description` 은 영어와 한국어를 함께 적고 다섯 목적을 모두 담는다. `description` 은 다른 에이전트가 스킬을 고르는 유일한 신호다.
- 인자: 없으면 전체 흐름을 돈다. `privacy`, `license`, `ci`, `secure`, `contrib` 중 하나를 주면 그 목적만 돈다. 어느 쪽이든 공통 실측은 항상 한다.
- 공통 실측에 **기본 브랜치**, **작업 트리 상태**, **활동량**을 더한다.
  - 기본 브랜치: GitHub 원격이면 `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name` 을 쓴다. 원격은 있지만 GitHub 이 아니면 `git symbolic-ref --short refs/remotes/origin/HEAD` 에서 `origin/` 을 뗀다. 둘 다 안 되면 사람에게 묻는다.
  - 작업 트리: `git status --porcelain`. 추적 파일의 변경이 있으면 3.2.3 에 따라 멈춘다.
  - 활동량: 열린 PR 수(`gh pr list --state open --json number --jq length`), 최근 30일 커밋 수, 기존 워크플로 수. 설명 카드의 숫자로 쓴다.
  - 이미 있는 훅은 `git config core.hooksPath` 와 `find "$(git rev-parse --git-common-dir)/hooks" -type f -perm -u+x ! -name '*.sample'` 로 본다.
- 선택 표: 목적 | 고르는 조건 | 빼는 조건 | 순서 | 선행. 첫 칸은 `` `privacy` `` 모양이다(invariants 가 목적 폴더 집합과 대조한다). 순서는 지금과 같이 privacy → license → ci → secure → contrib 이다.
- 목록에 없는 세팅이 필요하면 직접 하지 않고 보고한다. `docs/decisions.md` 를 가리키는 문장은 뺀다. 설치된 쪽에는 그 파일이 없다.

#### 3.2.1 확인 흐름 (결정 17)

1. **실측 결과를 보인다.** 공개 여부, 소유, 호스트, 기본 브랜치, 작업 트리 상태, 활동량, 이미 있는 도구다.
2. **목적마다 설명 카드를 보이고, 적용할 목적을 고르게 한다.**
   - 고르는 조건에 맞지 않는 목적은 카드 첫 줄에 이유를 적고 기본으로 빼 둔다. 그래도 사람이 고를 수 있다.
   - Claude Code 의 `AskUserQuestion` 은 질문 하나에 선택지를 4개까지만 받는다. 그래서 두 질문으로 나눈다. 로컬 층(privacy, license, ci)과 GitHub 층(secure, contrib)이다. 다른 에이전트에서는 번호 목록으로 묻는다.
3. **고른 목적 안에서 부작용이 있는 단계마다 다시 확인받는다.** 단계마다 무엇을 보여 주고 확인받는지는 아래 표와 같다.

| 단계 | 확인받기 전에 보여 줄 것 |
|---|---|
| 새 파일 쓰기 | 경로와 전체 내용(길면 앞뒤와 자리표시자를 채운 값) |
| 기존 파일 고치기 | `git diff` 형태의 차이와 고친 줄 수 |
| 푸시와 PR 만들기 | 브랜치 이름, 올라갈 커밋 목록, 이 푸시로 도는 워크플로 |
| GitHub 설정 바꾸기 | 쓰기 스크립트의 `current:`·`plan:` 출력과 영향 보고(3.7, 3.8) |
| 로컬에서 테스트 명령 실행 | 돌릴 명령과, 네트워크나 파일에 부작용이 있을 수 있다는 사실 |

4. **끝나면 보고한다.** 한 것, 건너뛴 것과 이유, 사람이 해야 할 것(예: 병합한 뒤 `/repo-setup contrib` 다시 부르기), 되돌리는 법을 적는다.

#### 3.2.2 설명 카드의 규칙

카드는 **처음 보는 사람이 읽고 결정할 수 있어야 하고**, 동시에 **실무에서 켠 뒤 겪을 일을 미리 알 수 있어야 한다.** 용어는 풀어 쓰되 내용을 얕게 만들지 않는다.

카드에는 아래 일곱 칸을 이 순서로 채운다.

1. **무엇인가.** 한두 문장으로 쓴다. 용어가 처음 나오면 그 자리에서 뜻을 붙인다. 예: "룰셋(브랜치에 거는 규칙 묶음)".
2. **이 저장소에서 왜.** 실측값에 근거해 쓴다. 예: "공개 저장소이고, 기존 워크플로 3개가 액션을 태그로 참조한다."
3. **무엇이 바뀌나.** 파일(경로, 새로 만드는지 고치는지), GitHub 설정(이름과 전후 값), **다른 사람에게 생기는 일**(동료가 해야 할 일, 막히는 동작, 받게 될 알림)을 적는다.
4. **켠 뒤 실제로 겪는 일.** 운영 중에 마주칠 장면과 그때 할 일을 적는다. 예: "main 으로 직접 푸시하면 거절되고, 브랜치를 만들어 PR 로 올려야 한다." "dependabot PR 이 생태계마다 한 번에 최대 N개 열린다." "워크플로 한 번에 러너 약 N분이 든다."
5. **감수할 것.** 비용, 속도, 오탐 가능성, 잠길 위험을 적는다.
6. **되돌리는 법.** 정확한 명령이나 화면 경로를 적는다. 되돌릴 수 없는 부분은 되돌릴 수 없다고 적는다.
7. **건너뛰면.** 무엇이 위험으로 남는지 적는다.

- 숫자는 실측값을 쓴다(열린 PR 수, 워크플로 수, 발견 수). 추정이면 추정이라고 표시한다.
- 카드 하나는 한 화면 안(대략 15줄)에 들어가야 한다. 넘치면 세부를 "자세히" 한 줄로 접는다.
- 카드 문구는 각 `PROCEDURE.md` 맨 앞의 「카드」 절에 두고, 진입점은 그 절에 실측값을 채워 보여 준다. 카드 내용을 진입점에 옮겨 적지 않는다.

예시 카드 (contrib 의 룰셋, 활발한 저장소 가정):

```
main 보호 (룰셋)
1. 무엇: 룰셋은 브랜치에 거는 규칙 묶음이다. main 은 PR 로만 바뀌고, 고른 검사가 통과해야
   병합되며, 강제 푸시와 삭제가 막힌다. 관리자만 PR 안에서 규칙을 건너뛸 수 있다.
2. 왜: main 에 PR 없이 들어온 커밋이 최근 30개 중 7개다(실측).
3. 바뀌는 것: GitHub 설정에 룰셋 "repo-setup: main" 이 생긴다. 파일은 바뀌지 않는다.
   동료: 로컬에서 main 에 커밋해 푸시하던 습관이 막힌다. 열린 PR 12개 중 4개는 새 필수 검사가
   없어 main 을 병합하거나 다시 푸시해야 병합할 수 있다(실측).
4. 겪는 일: 직접 푸시하면 "Changes must be made through a pull request" 같은 메시지로 거절된다.
   릴리스 봇이 main 에 푸시한다면 그 봇도 막힌다.
5. 감수: 모든 변경에 PR 이 필요하다. 필수 검사가 멈추면 관리자만 PR 에서 우회할 수 있다.
6. 되돌리기: gh api -X DELETE repos/OWNER/REPO/rulesets/<id>  (설정 → Rules → Rulesets 에서도 된다)
7. 건너뛰면: 실수로 한 직접 푸시와 강제 푸시가 그대로 main 에 남는다.
```

거절 메시지의 실제 문구는 8.3 에서 실측한 값으로 바꾼다.

#### 3.2.3 변경을 올리는 방식 (결정 18)

1. **시작 조건.** `git status --porcelain` 에 추적 파일의 변경(`??` 가 아닌 줄)이 있으면 멈추고, 사람이 커밋하거나 치우게 한다. 추적되지 않은 파일은 두어도 되지만 `git add -A` 는 쓰지 않는다. 커밋할 때는 세팅이 만든 경로만 이름으로 더한다.
2. **브랜치.** `git fetch origin` 뒤 `git switch -c repo-setup/<YYYY-MM-DD> origin/<기본 브랜치>` 로 만든다. 같은 이름이 있으면 `-2`, `-3` 을 붙인다. 원격이 없는 저장소는 기본 브랜치에서 로컬 브랜치만 만들고, 병합은 사람에게 맡긴다.
3. **커밋.** 목적마다 커밋 하나를 만든다. 기존 워크플로를 고치는 변경(SHA 고정, 권한 좁히기, zizmor 지적 수정)은 따로 커밋한다. 커밋 메시지 형식은 대상 저장소의 `git log` 관례를 따르고, 관례가 없으면 Conventional Commits 로 쓴다.
4. **푸시와 PR.** 확인을 받은 뒤 푸시하고 PR 하나를 연다. PR 본문에는 목적별로 한 것, 검증 결과, **PR 밖에서 바꾼 GitHub 설정**(secret scanning, 코드 스캐닝)과 되돌리는 명령을 적는다. repo-ci 의 "한 번 돌아 통과한다" 판정은 이 PR 에서 도는 실행으로 한다.
5. **GitHub 설정의 시점.**
   - secret scanning 과 코드 스캐닝 default setup 은 파일과 무관하므로 확인을 받으면 바로 바꾼다.
   - 룰셋은 세팅 PR 이 병합된 뒤에 건다. 필수로 걸 검사를 만드는 워크플로가 main 에 없을 때 걸면, 다른 PR 이 모두 멈추기 때문이다.
   - 그래서 진입점은 contrib 에 이르면 PR 이 병합됐는지 확인한다. 병합되지 않았으면 "병합한 뒤 `/repo-setup contrib` 를 다시 부른다"를 사람이 할 일로 보고하고 끝낸다.
6. **팀 저장소.** 파일 변경은 확인을 받은 뒤 PR 로 올린다(2026-09-22 사용자 확인). PR 은 병합되기 전까지 main 에 영향이 없고 팀이 리뷰해서 받을지 정하므로, 제안의 한 형태로 본다. GitHub 설정(보안 기능, 룰셋)은 PR 로 올릴 수 없고 즉시 적용되므로 계속 계획만 보인다.
   - **푸시 직전의 확인 카드**에는 팀에 생길 일을 실측값으로 적는다.
     - 올라갈 브랜치 이름과 커밋 목록
     - 리뷰 요청이 누구에게 가는지(`CODEOWNERS` 가 있으면 바뀌는 파일에 걸리는 소유자)
     - 이 PR 에서 도는 워크플로(`pull_request` 트리거를 가진 파일 목록)
     - 비공개 저장소라면 조직의 Actions 사용량을 쓴다는 사실
     - 병합된 뒤 팀원마다 가드를 켜는 명령(Node 저장소는 `npm install`, 그 밖에는 `script/setup`)을 한 번 돌려야 로컬 가드가 켜진다는 사실(이 안내는 PR 본문에도 넣는다)
   - **푸시할 수 없을 때는 제안으로 물러난다.** 포크해서 올리는 방식은 쓰지 않는다.
     - 내 권한(`viewerPermission`)이 `READ` 나 `TRIAGE` 면 푸시를 시도하지 않는다.
     - 푸시가 거절되면(브랜치 이름 규칙, 서명된 커밋 필수, 푸시 제한 같은 조직 정책) 거절 메시지를 그대로 보고한다.
     - 두 경우 모두 로컬 브랜치와 커밋은 남기고, `git format-patch` 로 만든 패치 파일의 경로를 알려 준다. 사람이 그 파일을 팀에 공유하거나 권한 있는 사람이 적용할 수 있다.

### 3.3 privacy

- **⑤ 추가된 줄만 검사**
  - 텍스트 파일은 `git diff --cached -U0 --no-color --no-ext-diff --no-textconv --no-renames` 가 내놓는 `+` 줄만 검사한다(`+++` 머리 줄은 뺀다).
  - `git diff --cached --numstat -z` 가 `-	-` 를 내는 바이너리는 지금처럼 blob 전체를 검사한다.
  - 파일 목록과 이름은 PR #1 처럼 `-z` 로 받고, 경로 검사(`.private/*`)는 그대로 둔다.
- **⑤ 내장 패턴**
  - 지금의 두 패턴(`/Users/[A-Za-z]`, `/home/[A-Za-z]`)에 Windows 경로를 더한다. 드라이브 문자 뒤에 `\Users\` 가 오고 영문자가 이어지는 경로이며, 역슬래시가 하나인 경우와 이스케이프돼 둘인 경우를 모두 잡는다.
  - 예외는 결정 11의 넷이다. 경로 구성 요소 전체가 일치할 때만 예외로 본다. 예를 들어 홈 폴더 아래 `nodejs-user` 는 막는다.
  - 구현 방법은 정하지 않는다. 다만 한 줄에 예외 경로와 막을 경로가 함께 있으면 막아야 한다.
- **⑥ commit-msg**
  - `.githooks/commit-msg "$1"` 은 메시지 파일에서 `#` 로 시작하는 줄을 빼고, pre-commit 과 같은 패턴(내장 패턴과 세 출처)으로 검사한다.
  - 패턴 적재와 검증 코드는 `.githooks/lib/guard.sh` 한 곳에 두고 두 훅이 `source` 한다.
  - 공존 한 줄: `"$(git rev-parse --show-toplevel)"/.githooks/commit-msg "$1" || exit 1`
  - `script/setup --verify` 는 임시 메시지 파일로 commit-msg 도 탐침한다. 두 훅이 모두 막아야 통과다.
- **⑦ 실행 비트**: `script/setup` 은 git 이 아는 훅 이름(`pre-commit`, `commit-msg` 등 githooks(5) 의 목록)에만 실행 비트를 채우고 그것만 센다. `team-patterns` 와 `lib/` 는 건드리지 않는다.
- **⑧ PR 검사(CI 가드)**
  - `templates/guard-workflow.yml` 을 대상 `.github/workflows/guard.yml` 로 놓는다. 트리거는 `pull_request` 와 기본 브랜치 푸시이고, 필터(`paths`)를 두지 않는다. 필수 검사 후보가 되기 때문이다. 권한은 `contents: read` 만 준다.
  - 워크플로는 저장소에 커밋된 `.githooks/lib/guard.sh` 를 **범위 모드**로 부른다. 로컬 훅이 인덱스(스테이징된 내용)를 보는 것과 달리, 범위 모드는 PR 의 기준 커밋과 머리 커밋 사이(`git diff <base>...<head>` 의 추가된 줄과 `git log <base>..<head>` 의 커밋 메시지)를 본다. 같은 검사 코드를 두 모드가 함께 쓴다.
  - CI 에는 개인 패턴 파일(`~/.config/git-guard/patterns`, `.private/guard-patterns`)이 없으므로 내장 홈 경로와 `.githooks/team-patterns` 만 검사한다. 이 한계는 privacy 카드와 wiki 에 적는다.
  - 실패하면 어느 커밋의 어느 파일, 몇 번째 줄인지를 출력한다. 로컬 훅과 같이 패턴 값은 출력하지 않는다.
  - 카드의 「켠 뒤 겪는 일」: "푸시한 뒤에 돈다. 공개 저장소라면 이 검사가 실패한 시점에 그 커밋은 이미 공개돼 있다. 되돌리려면 이력을 다시 써야 하고, 이미 받아 간 사람이 있으면 회수할 수 없다."
- **⑨ 로컬 훅을 켜는 방식**
  - 순서대로 본다. 첫 번째로 해당하는 것 하나만 쓴다.
    1. husky 를 쓰고 있으면(`.husky/` 가 있거나 `core.hooksPath` 가 `.husky/_`) `.husky/pre-commit` 과 `.husky/commit-msg` 에 가드를 부르는 줄을 더한다.
    2. pre-commit 프레임워크를 쓰고 있으면(`.pre-commit-config.yaml`) `repo: local` 훅 둘(pre-commit 단계, commit-msg 단계)로 등록한다. commit-msg 단계가 설치되도록 `default_install_hook_types` 를 확인한다.
    3. lefthook 을 쓰고 있으면(`lefthook.yml` 등) `pre-commit` 과 `commit-msg` 에 명령을 더한다.
    4. 셋 다 없고 `package.json` 이 있으면 husky 를 더한다. 그 저장소의 패키지 매니저(잠금 파일로 판별: `package-lock.json`→npm, `pnpm-lock.yaml`→pnpm, `yarn.lock`→yarn)로 devDependency 에 설치하고, `"prepare": "husky"` 를 두고, `.husky/pre-commit` 과 `.husky/commit-msg` 가 가드를 부르게 한다. 잠금 파일은 손으로 고치지 않고 패키지 매니저가 다시 만든다. 이미 다른 `prepare` 가 있으면 뒤에 이어 붙인다.
    5. 그 밖에는 `script/setup` 을 둔다(지금 방식).
  - 어느 방식이든 가드 본체는 `.githooks/pre-commit`, `.githooks/commit-msg`, `.githooks/lib/guard.sh` 다. 도구들은 이 파일을 부르기만 한다.
  - 1~4 에서는 `script/setup` 을 대상 저장소에 놓지 않는다. 증명은 스킬 폴더의 `privacy/templates/setup --verify` 를 **대상 저장소 루트에서** 실행해 한다. 이 명령은 git 이 실제로 부를 훅을 찾아 돌리므로, husky 같은 도구를 거쳐서도 동작한다.
  - 1~4 는 팀의 설정 파일(`package.json`, `.pre-commit-config.yaml`, `lefthook.yml`, `.husky/*`)을 고치므로, 3.2.1 의 확인 흐름에 따라 diff 를 보여 주고 따로 확인받는다.
- privacy 카드의 「켠 뒤 겪는 일」에는 다음을 적는다. 동료도 클론마다 가드를 켜는 명령을 한 번 돌려야 하고(Node 저장소는 `npm install` 이 대신한다), 켜지 않은 기계의 커밋은 푸시한 뒤에 PR 검사(⑧)에서야 잡힌다. 이미 커밋된 이력은 검사하지 않는다. commitlint 처럼 commit-msg 를 쓰는 도구가 있으면 공존 한 줄이 필요하다.

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
- 이미 LICENSE 가 있으면 절대 다시 쓰지 않는다. 매니페스트와 어긋나면 어느 쪽을 고칠지 사람에게 묻는다.
- PROCEDURE.md 에서 6단계가 "4단계에서 정한 SPDX" 라고 잘못 가리키는 번호를 바로잡는다.

### 3.5 ci

- `find-test-command.sh` 를 지운다. 후보 명령은 에이전트가 프로젝트 파일을 읽어 고른다.
  - 후보: `.check.toml` 의 `test_command`, `npm pkg get scripts.test`, Makefile 의 `test` 타깃, `pyproject.toml`, `Cargo.toml`, `go.mod` 등.
  - 고른 명령을 로컬에서 돌리고(3.2.1 의 확인을 받은 뒤) 출력을 파일로 남긴다.
- `scripts/check-test-run.sh <로그 파일>`: 요약 줄에서 실행된 테스트 수를 읽는다.
  - 지원하는 형식은 pytest(`N passed`), jest(`Tests: … N passed`), vitest(`Tests  N passed`), cargo(`test result: ok. N passed` 를 모두 합산), go(`ok` 줄 수, `[no test files]` 는 0), `node --test`(`# pass N`)다.
  - 종료 코드: 0 은 1개 이상(표준 출력에 개수), 1 은 0개, 2 는 알아보지 못함이다.
  - 형식별 픽스처 로그로 테스트한다.
- 워크플로가 이미 있는 저장소(활발한 저장소는 대개 여기에 해당)에서는 tests.yml 을 새로 만들지 않는다. 대신 기존 워크플로가 PR 에서 테스트를 돌리는지 카드로 보고한다.
- `templates/tests.yml`
  - `run:` 은 블록 스칼라(`run: |`)로 쓴다. 명령에 `#` 나 `: ` 가 있어도 YAML 이 깨지지 않게 하기 위해서다.
  - `__DEFAULT_BRANCH__` 에는 진입점이 잰 값을 넣는다.
  - matrix 는 유지한다. 필수 검사 이름은 실제 실행에서 읽기 때문이다(결정 5).
  - 필터(`paths` 등)를 두지 않는다. 필수 검사가 될 수 있으므로 모든 PR 에서 돌아야 한다.
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
  - 카드의 「겪는 일」: push protection 을 켜면 비밀 형식이 든 푸시가 동료의 것까지 거절되고, 거절 메시지에 우회 절차가 나온다.
- `scripts/code-scanning.sh [--apply]`
  - 계획 단계에서 `GET repos/{o}/{r}/code-scanning/default-setup` 을 읽는다.
  - 403 "Code scanning is not enabled" 나 GHAS·Code Security 가 없으면 exit 2 로 보고하고 건너뛴다.
  - `.github/workflows/` 에 `github/codeql-action/analyze` 를 쓰는 고급 설정 워크플로가 있으면 건드리지 않고 exit 2 다.
  - 그 밖에는 `PATCH …/default-setup` 에 `{"state":"configured"}` 를 보내고, 되읽어 `state` 가 `configured` 인지 확인한다.
- `templates/zizmor.yml`: `unpinned-uses` 정책으로 모든 액션에 SHA 고정을 요구한다. 형식은 7절에서 확인한다.
- `templates/zizmor-workflow.yml`
  - `.github/**` 가 바뀌는 `pull_request` 와 main 푸시에서 zizmor 를 고정한 버전으로 돌린다. 이 워크플로는 `paths` 필터가 있으므로 결정 19 에 따라 필수 검사 후보에서 기본으로 빠진다.
  - 판정은 plain 형식의 종료 코드로 한다(low 이상이면 실패). SARIF 형식은 종료 코드를 끄기 때문이다(6절의 출처 3).
  - 코드 스캐닝을 쓸 수 있는 저장소에서는 SARIF 업로드 단계를 따로 더한다. 권한은 기본 `contents: read` 이고, 업로드 job 에만 `security-events: write` 를 준다.
- `templates/dependabot.yml` 은 유지하되 zizmor 를 통과하게 고친다(예: `dependabot-cooldown`). codeql-action 묶음은 zizmor 워크플로가 그 액션을 쓸 때만 남긴다. 카드에는 생태계마다 한 번에 열리는 PR 수의 상한을 적는다(기본값은 7절에서 확인).
- **기존 발견 처리 (결정 20)**
  1. `zizmor.yml` 을 놓고, 기존 워크플로와 composite action 전체에 로컬 검사를 돌린다.
  2. 발견을 규칙별로 묶어 보여 주고 두 무더기로 나눈다. 하나는 에이전트가 고칠 수 있는 것(예: `unpinned-uses`, `excessive-permissions`, `artipacked`)이고, 다른 하나는 사람이 판단할 것(예: `dangerous-triggers`, `template-injection`, `self-hosted-runner`)이다. 어느 규칙이 어느 무더기인지는 구현할 때 zizmor 문서의 설명을 근거로 표로 정한다.
  3. 에이전트가 고칠 것은 확인을 받은 뒤 고친다. SHA 고정(결정 6)도 여기서 한다. 이 변경은 별도 커밋이다.
  4. 사람이 판단한 것 중 남길 것은 `zizmor.yml` 에 파일·규칙·이유 주석과 함께 예외로 적는다.
  5. `GH_TOKEN="$(gh auth token)" zizmor --min-severity=low .github/` 가 exit 0 이 된 뒤에만 `zizmor-workflow.yml` 을 놓는다. 0 이 되지 않으면 차단 워크플로를 놓지 않고, 남은 발견과 이유를 보고한다.
- PROCEDURE.md 순서:
  1. 실측(기존 워크플로 수, `security_and_analysis`, default setup 상태)
  2. secret-scanning 계획 → 확인 → `--apply`
  3. dependabot
  4. code-scanning 계획 → 확인 → `--apply`
  5. 기존 발견 처리(위 1~5)
  6. 보고

### 3.7 쓰기 스크립트의 공통 규칙 (`secret-scanning.sh`, `code-scanning.sh`, `ruleset.sh`)

- 대상 저장소는 현재 폴더에서 `gh repo view --json nameWithOwner` 로 정한다.
- 인자 없이 돌리면 `current:` 줄에 현재 값을, `plan:` 줄에 보낼 요청(메서드, 경로, JSON 본문)을, `impact:` 줄에 다른 사람에게 미치는 영향(해당하는 경우)을 출력한다. 아무것도 바꾸지 않는다.
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
- `scripts/ruleset.sh`
  - `--list --commit <SHA>`: 그 커밋의 check-runs(`gh api repos/{o}/{r}/commits/{SHA}/check-runs`) 가운데 `status == completed` 이고 `conclusion == success` 인 것마다 이름, `app.id`, 앱 이름, 그 check 를 만든 워크플로 파일 경로를 한 줄씩 출력한다. 워크플로 경로는 같은 SHA 의 Actions 실행(`gh api "repos/{o}/{r}/actions/runs?head_sha={SHA}"`)과 job 이름으로 맞춘다. 맞출 수 없으면 경로 칸을 `?` 로 둔다.
  - 에이전트는 경로가 나온 워크플로 파일을 읽어 `paths`·`paths-ignore`·`branches` 필터와 job `if` 조건이 있는지 표시하고, 표로 사람에게 보인다(결정 19). 필터나 조건이 있는 check 와 경로가 `?` 인 check 는 기본으로 뺀다.
  - `--branch <이름> [--check <이름>:<app id> ...] [--apply]`: 고른 check 로 룰셋을 계획한다. `--check` 가 없으면 필수 검사 없이 나머지 세 규칙만 건다고 계획에 적는다.
  - `impact:` 줄에는 두 가지를 적는다.
    - 열린 PR 수와, 그 가운데 고른 check 가 최신 커밋에 성공으로 붙어 있지 않아 멈출 PR 의 번호(`gh pr list --state open --json number,statusCheckRollup`)
    - 대상 브랜치의 최근 커밋 30개 중 PR 없이 들어온 커밋 수(`gh api repos/{o}/{r}/commits/{sha}/pulls` 가 빈 배열인 것). 봇이나 자동화가 직접 푸시하고 있다는 신호다.
  - 룰셋 이름은 `repo-setup: <branch>` 다. 같은 이름의 룰셋이 있으면 PUT 으로 갱신하고, 없으면 POST 로 만든다.
  - `bypass_actors` 는 저장소 관리자 역할(`RepositoryRole`)에 `bypass_mode: pull_request` 를 준다. 관리자 역할의 `actor_id` 는 7절에서 확인하고, 확인하지 못하면 exit 2 다.
  - 되읽을 때는 `gh api repos/{o}/{r}/rules/branches/{branch}` 로 네 규칙이 모두 걸렸는지 본다. `revert:` 는 `gh api -X DELETE repos/{o}/{r}/rulesets/{id}` 다.
- PROCEDURE.md 순서:
  1. 실측
  2. community-defaults
  3. CONTRIBUTING, SECURITY 놓기(기본값이 없을 때만)
  4. 세팅 PR 이 병합됐는지 확인. 아니면 사람이 할 일로 보고하고 끝낸다(3.2.3 의 5)
  5. `ruleset.sh --list` → 필수 검사 고르기 → 계획과 영향 보고 → 확인 → `--apply`
  6. 되읽기와 보고

### 3.9 이 저장소 자체

- ①: `.github/workflows/test.yml`
  - 트리거는 `pull_request` 와 main 푸시이고, matrix 는 `ubuntu-latest` 와 `macos-latest` 다.
  - `concurrency` 는 `cancel-in-progress: true` 이고, `permissions` 는 `contents: read` 이며, 액션은 SHA 로 고정한다.
  - 단계는 checkout, shellcheck 준비, `.check.toml` 의 `test_command`, CLAUDE.md 의 shellcheck 명령 순서다.
  - shellcheck 는 두 러너 모두 공식 릴리스 v0.11.0 을 받아 sha256 으로 확인한다. ubuntu 러너에 깔린 판(0.9.0)과 로컬 판이 달라서 러너마다 경고가 달라지지 않게 하려는 것이다(6절의 출처 20).
  - 테스트 목록은 `.check.toml` 의 줄을 실행할 때 읽는다. shellcheck 명령은 워크플로에 적혀 있으므로 CLAUDE.md 의 줄과 두 곳에 있다.
- ⑩ 뒤: 자체 CI 에 zizmor job 을 더한다. 대상은 이 저장소의 `.github/workflows/` 다.
- ③: `tests/invariants.sh` 를 새 구조에 맞춘다.
  - 스킬 수는 1이다.
  - 진입점 표의 목적 이름 집합이 목적 폴더 집합과 같아야 한다.
  - 목적 폴더마다 `PROCEDURE.md` 가 있어야 한다. ④ 부터는 `PROCEDURE.md` 에 「카드」 절이 있고 일곱 칸 제목이 모두 있어야 한다.
  - SKILL.md 와 PROCEDURE.md 가 가리키는 `<목적>/(scripts|templates)/…` 경로가 실제로 있어야 한다.
  - `scripts/*.sh` 와 훅 템플릿에 실행 비트가 있어야 한다.
  - 루트 사본이 새 경로의 템플릿과 같아야 한다.
  - 본문이 `../` 나 저장소 루트의 `docs/` 를 가리키면 안 된다. 지금 검사는 `../` 만 보아서 `docs/decisions.md` 참조를 놓친다.
  - 매니페스트 description 대조는 유지한다.
- ③: CLAUDE.md 의 구조 절과 shellcheck 글롭(`.github/workflows/test.yml` 의 shellcheck 줄도 같이), README 의 설치 경로, wiki 페이지의 관련 파일 경로를 새 구조로 고친다. ADR 0006 을 더하고 0002 를 superseded 로 표시한다(3.10). 각 목적의 세부 문서는 그 목적의 PR 에서 고친다.

### 3.10 ADR (결정 21)

- **자리와 이름.** `docs/adr/NNNN-<영어-kebab-slug>.md`. 번호는 네 자리로 차례대로 매기고 다시 쓰지 않는다. 파일 이름에 날짜를 넣지 않는다. 목록은 `docs/adr/README.md` 에 번호, 제목, 상태를 한 줄씩 둔다.
- **형식.** Nygard 형식을 따르고 본문은 한국어로 쓴다(6절의 출처 11). 절은 다섯이다.
  - 제목: 결정을 짧은 명사구로 쓴다.
  - 상태: `제안`, `승인`, `폐기`, `대체됨(→ NNNN)` 중 하나와 날짜.
  - 맥락: 결정을 부른 힘을 중립적으로 적는다.
  - 결정: "~한다"로 끝나는 완결된 문장으로 적는다.
  - 결과: 좋은 것, 나쁜 것, 중립인 것을 모두 적는다. 버린 대안과 그 이유도 여기에 둔다.
- **뒤집힌 결정.** 지우지 않는다. 상태를 `대체됨(→ NNNN)` 으로 바꾸고, 새 ADR 의 맥락에서 옛 ADR 을 가리킨다.
- **규칙은 두지 않는다.** 선택 조건이나 순서 같은 실행 규칙은 `SKILL.md` 에만 두고, ADR 에는 그 규칙을 **왜** 그렇게 정했는지만 적는다. 같은 규칙을 두 곳에 두면 한쪽만 고쳐져 어긋난다.
- **② 에서 옮길 것** (`docs/decisions.md` 에서):

| 번호 | 제목 | 옮겨 올 곳 |
|---|---|---|
| 0001 | 저장소 층만 다룬다 | 1절과 7절(언어별 도구 체인, `.gitignore` 전체를 다루지 않는 이유) |
| 0002 | 목적별로 좁은 스킬 다섯을 둔다 | 2절(항목별 아홉 개와 층별 세 개를 버린 이유) |
| 0003 | 겹치는 파일과 설정의 소유를 정한다 | 3절(워크플로 파일, 브랜치 보호, `.gitignore` 의 `.private/` 한 줄) |
| 0004 | 테스트 없는 저장소에 CI 를 만들지 않는다 | 4절의 해당 문단(빈 CI 가 보호를 껍데기로 만드는 이유) |
| 0005 | 팀 저장소의 공유 자산은 제안만 한다 | 5절 첫 규칙 |

  - 4절의 선택 표와 호출 순서는 `SKILL.md` 에 이미 있으므로 옮기지 않는다. 순서의 **이유** 문장은 0003 에 둔다.
  - 5절의 "스킬 본문은 자기 폴더만으로 완결된다"는 CLAUDE.md 의 규칙으로 이미 있으므로 옮기지 않는다.
  - 6절(끝난 할 일 목록)은 옮기지 않는다.
  - 출처 절은 해당 ADR 의 맥락으로 옮긴다.
- **새 결정을 옮길 PR**

| 번호 | 제목 | 더하는 PR | 이 스펙의 결정 |
|---|---|---|---|
| 0006 | 스킬 하나에 목적별 폴더를 둔다(0002 를 대체) | ③ | 1 |
| 0007 | 설명 카드로 두 번 확인받고 변경은 브랜치와 PR 로 올린다 | ④ | 17, 18 |
| 0008 | 판정은 검증된 도구와 GitHub API 에 맡기고 가드만 bash 와 git 으로 둔다 | ⑩·⑪·⑫ 중 먼저 병합되는 것 | 2, 3, 6, 7, 8, 20 |
| 0009 | GitHub 설정은 계획을 먼저 보이고 --apply 로만 바꾼다 | ⑩ | 9 |
| 0010 | main 보호는 룰셋으로 하고 필수 검사는 사람이 고른다 | ⑬ | 4, 5, 19 |
| 0011 | 팀 저장소에도 파일 변경은 확인 후 PR 로 올리고, 푸시할 수 없으면 패치로 물러난다(0005 를 일부 고침) | ④ | 18(3.2.3 의 6) |
| 0012 | 가드는 PR 검사로 모두에게 걸고, 로컬 훅은 저장소가 이미 쓰는 도구에 얹는다 | ⑧ | 24, 25 |

  - 0011 이 0005 를 고치는 방식: 0005 의 상태는 `승인` 으로 두고, 0011 의 맥락에서 0005 를 가리키며 "파일 변경은 PR 로 올려도 되고, GitHub 설정은 여전히 제안만 한다"고 좁힌다.
  - 나머지 결정(10~16)은 코드와 테스트, CLAUDE.md, 매니페스트에 이미 드러나므로 ADR 로 옮기지 않는다. ⑭ 에서 이 판정을 다시 확인한다.

### 3.11 wiki 와 README (결정 22, 23)

- **네 문서의 역할.** Diátaxis 의 네 문서 종류(6절의 출처 13)에 대응시켜 나눈다. 한 사실은 한 문서에만 둔다.

| 문서 | 담는 것 | Diátaxis |
|---|---|---|
| `README.md` | 무엇인지, 설치, 첫 실행, 목적 다섯의 한 줄 요약, wiki 링크 | tutorial |
| `PROCEDURE.md` 의 카드 | 세팅 중에 사용자에게 보이는 설명(3.2.2) | how-to |
| `docs/wiki/*.md` | 구현된 기능이 무엇을 하고 어떻게 동작하는지 | reference |
| `docs/adr/*.md` | 왜 그렇게 만들었는지, 버린 대안 | explanation |

- **페이지.** `docs/wiki/README.md`(목차)와 기능 페이지 일곱이다. 이름은 스킬 구조와 무관한 목적 이름으로 정해, ③ 에서 폴더가 바뀌어도 페이지 이름은 그대로 둔다.
  - `privacy.md`, `license.md`, `ci.md`, `secure.md`, `contrib.md`
  - `setup-flow.md`: 진입점의 실측, 확인 흐름, 변경 전달
  - `development.md`: 이 저장소의 구조, 테스트, 자체 CI, 기여 방법
- **페이지의 절.** 순서대로 다음과 같다. 제목은 전역 규칙에 따라 명사형으로 쓴다(② 에서 질문형이던 제목을 바꿨다).
  1. 하는 일(두세 문장)
  2. 동작(트리거에서 결과까지 단계별)
  3. 바꾸는 것(파일, GitHub 설정, 다른 사람에게 미치는 영향)
  4. 한계와 알려진 문제
  5. 관련 파일(저장소 경로)
  6. 관련 ADR(번호와 제목 링크)
  7. 확인한 외부 사실(출처와 확인일. 전역 규칙에 따라 링크한 문서를 열어 확인한 것만 적는다)
- **쓰지 않는 것.** 이유는 ADR 링크로만 둔다. 카드 문구와 실행 규칙(선택 조건, 순서)은 옮겨 적지 않고 `PROCEDURE.md` 와 `SKILL.md` 를 링크한다. 앞으로 할 계획은 쓰지 않는다. 계획은 SPEC.md 에만 둔다.
- **갱신.** 기능을 바꾸는 PR 은 그 기능의 wiki 페이지를 같은 PR 에서 고친다. 코드와 설명이 같은 리뷰를 거치게 하려는 것이다.
- **낡음을 막는 검사.** ② 에서 `tests/invariants.sh` 에 다음을 더한다.
  - 목적마다 `docs/wiki/<목적>.md` 가 있고, `docs/wiki/README.md` 가 모든 페이지를 가리킨다.
  - wiki 페이지에 백틱으로 적힌 저장소 경로(`plugin/`, `tests/`, `docs/` 로 시작하는 것)가 실제로 있다. `.githooks/` 와 `.github/` 는 보지 않는다. privacy 페이지의 `.githooks/team-patterns` 처럼 대상 저장소에 놓일 경로와 글자만으로 갈리지 않기 때문이다(② 에서 확인).
  - wiki 페이지가 가리키는 ADR 번호의 파일이 `docs/adr/` 에 있다.
  - `docs/adr/README.md` 가 모든 ADR 을 가리킨다.
- **README.** 목표는 100줄 안팎이고, 존댓말(합니다체)로 새로 쓴다. 지금 README 의 스킬별 절은 ② 에서 해당 wiki 페이지로 **옮기기만** 한다. 옮기면서 내용을 고치지 않는다. 낡은 문장(예: "Skills (2)")은 README 에 남는 부분이면 ② 에서 고치고, wiki 로 옮긴 부분이면 그 기능의 PR 이나 ⑭ 에서 고친다.

## 4. PR 순서

| # | 제목 | 라벨 | 선행 | 완료 조건 |
|---|---|---|---|---|
| ① | `ci: 테스트와 shellcheck 를 ubuntu 와 macOS 에서 돌린다` | 없음(`ci` 에 맞는 라벨이 없다. PR 본문에 적는다) | 없음 | 두 러너에서 초록. 이 스펙 문서 포함 |
| ② | `docs: 문서를 README·wiki·ADR 로 나눈다` | `documentation` | 없음 | 3.10 의 ADR 0001~0005 와 `docs/adr/README.md`. 3.11 의 `docs/wiki/` 페이지와 목차. README 를 100줄 안팎으로 줄임. `docs/decisions.md` 삭제. `CLAUDE.md:6` 이 `docs/wiki/` 와 `docs/adr/` 를 가리키게 고침. `repo-setup/SKILL.md:92` 의 `docs/decisions.md` 참조 삭제. invariants 의 wiki·ADR 검사. 내용을 새로 쓰지 않고 옮기기만 한다 |
| ③ | `refactor(skill)!: 좁은 스킬 다섯을 repo-setup 의 목적별 폴더로 합친다` | `breaking`(새로 만든다) | PR #1, ①, ② | 동작 변화 없이 파일 이동, frontmatter, 진입점, invariants, 문서, 0.2.0. `setup.sh` 를 `script/setup` 으로 옮김(이 저장소의 사본 포함, 이전 판 사용자에게 옮기는 안내). ADR 0006. wiki 페이지의 관련 파일 경로 갱신. 기계적 이동과 내용 변경을 섞지 않는다 |
| ④ | `feat(setup): 목적마다 설명 카드로 확인받고 변경을 브랜치와 PR 로 올린다` | `enhancement` | ③ | 3.2 의 공통 실측 추가, 3.2.1~3.2.3. 다섯 PROCEDURE.md 에 「카드」 절(각 목적 PR 에서 내용을 다듬는다). ADR 0007, 0011 |
| ⑤ | `fix(privacy): 추가된 줄만 검사하고 공용 계정 경로를 막지 않는다` | `bug` | ③ | 3.3 의 ⑤ |
| ⑥ | `feat(privacy): 커밋 메시지도 가드가 검사한다` | `enhancement` | ③ | 3.3 의 ⑥ |
| ⑦ | `fix(privacy): 훅이 아닌 파일에 실행 비트를 붙이지 않는다` | `bug` | ③ | 3.3 의 ⑦ |
| ⑧ | `feat(privacy): PR 마다 CI 에서 가드를 돌린다` | `enhancement` | ⑤, ⑥ | 3.3 의 ⑧. ADR 0012 |
| ⑨ | `feat(privacy): 이미 쓰는 훅 도구에 가드를 얹고 Node 저장소에는 husky 를 더한다` | `enhancement` | ④, ⑧ | 3.3 의 ⑨ |
| ⑩ | `feat(secure)!: 워크플로 검사를 zizmor 로, CodeQL 을 default setup 으로 바꾼다` | `enhancement`, `breaking` | ④ | 3.6, 3.7. ADR 0009, 그리고 ⑩·⑪·⑫ 중 먼저 병합되면 0008 |
| ⑪ | `fix(license): 알아보지 못한 본문에 이름을 붙이지 않는다` | `bug` | ③ | 3.4 |
| ⑫ | `fix(ci): 테스트가 실제로 돈 것을 보고 워크플로를 놓는다` | `bug` | ④ | 3.5 |
| ⑬ | `feat(contrib)!: 브랜치 보호를 룰셋으로 옮기고 골격 셋을 뺀다` | `enhancement`, `breaking` | ⑧, ⑫ | 3.7, 3.8. ADR 0010 |
| ⑭ | `docs: 구조 변경을 마무리하며 낡은 문서를 정리한다` | `documentation` | ①~⑬ 모두 | CLAUDE.md 의 테스트 건수와 낡은 문장(예: "repo-privacy 가 템플릿 둘을 본문에 품는다") 제거. 2절의 결정이 모두 wiki, ADR, 코드·테스트 중 한 곳으로 옮겨졌는지 표로 확인한 뒤 SPEC.md 삭제. wiki 페이지가 모두 지금 구현과 맞는지 확인 |

- 모든 PR 은 저장소 규칙대로 **테스트를 먼저 쓰고 RED 를 확인한 뒤** 구현한다.
- ③ 부터 기능을 바꾸는 PR 은 그 기능의 `docs/wiki/` 페이지를 같은 PR 에서 고친다(3.11). 표의 "ADR" 은 그 PR 이 더하는 ADR 이다.
- PR 본문은 main 에 그대로 남을 글로 쓴다. 제목은 `type(scope): 요약` 이다.
- ② 는 ③ 보다 먼저 병합한다. ③ 이 0002 를 대체하는 ADR 을 더하기 때문이다.
- ⑨·⑩·⑫ 는 ④ 뒤에 온다. 카드와 확인 흐름, 세팅 PR 에서 CI 를 돌리는 방식이 ④ 에서 정해지기 때문이다.
- ⑧ 은 ⑤·⑥ 뒤에 온다. CI 가 로컬 훅과 같은 검사(추가된 줄, 커밋 메시지)를 돌리기 때문이다. ⑨ 는 ⑧ 뒤에 온다. husky 를 더하는 카드가 "설치하지 않은 팀원은 PR 검사가 잡는다"를 전제로 하기 때문이다.
- ⑬ 은 ⑧ 과 ⑫ 뒤에 온다. 필수 검사 후보에 가드 검사와 테스트 검사가 모두 있어야 하기 때문이다.
- ⑤·⑥·⑦·⑪ 은 ③ 뒤라면 서로 순서가 없다. ⑭ 는 맨 마지막이다.

## 5. 범위 밖

- 언어별 도구 체인과 `.gitignore` 전체. ADR 0001 과 0003 을 유지한다.
- Codex, Antigravity 에서의 실제 실행 검증. `npx skills` 탐색 경로 불변식만 유지한다.
- 조직 수준 룰셋, GHAS 와 Code Security 구매·설정.
- zizmor 말고 다른 워크플로 린터(actionlint 등)와 자동 고정 도구(pinact 등).
- 이미 커밋된 이력의 검사와 재작성(작성자 이메일 등). privacy 카드에 "이력은 검사하지 않는다"고만 적는다.
- 가드 예외 목록을 설정으로 늘리는 기능.
- 모노레포에서 패키지마다 다른 테스트 명령을 워크플로 여러 개로 나누는 일. 후보 명령이 여럿이면 사람에게 하나를 고르게 하고, 나머지는 보고만 한다.
- Git Bash 가 아닌 Windows 네이티브 셸에서의 실행.
- 실제 조직 저장소에서의 종단 검증. 이 계정에는 조직이 없다. 팀 저장소 판별과 "푸시할 수 없으면 패치로 물러난다"는 가짜 gh 테스트로 확인하고, 이 사실을 wiki 의 한계 절에 적는다.
- 포크해서 PR 을 올리는 방식.
- 컴퓨터당 한 번 켜는 방식(git 템플릿 폴더 `init.templateDir`). 2026-09-22 사용자 결정으로 쓰지 않는다.
- CI 에서 개인 패턴을 검사하는 일(예: 패턴을 저장소 시크릿에 넣는 방식). CI 는 내장 홈 경로와 팀 패턴만 본다.
- 훅 도구가 없는 저장소에 lefthook 이나 pre-commit 프레임워크를 새로 들이는 일. 이미 쓰는 저장소에 얹기만 한다.

## 6. 확인한 외부 사실

모두 2026-09-22 에 확인했다. "공식 문서"는 링크한 문서를 열어 해당 문장을 확인했다는 뜻이고, "실측"은 이 저장소에서 명령을 돌린 결과다.

1. **공식 문서**, Claude Code [Skills](https://code.claude.com/docs/en/skills): `disable-model-invocation` 은 "Set to `true` to prevent Claude from automatically loading this skill."(번역: `true` 로 두면 Claude 가 이 스킬을 자동으로 불러오지 못한다.) 같은 문서의 표에서 Skill 도구로 부르는 것도 막히고, 시도하면 "Claude Code blocks the call"(번역: Claude Code 가 호출을 막는다)이라고 적혀 있다. 지원 파일에 대해서는 "Skills can include multiple files in their directory."(번역: 스킬은 자기 폴더 안에 여러 파일을 둘 수 있다.)
2. **공식 문서**, [zizmor audits](https://docs.zizmor.sh/audits/): 규칙 41개 가운데 `unpinned-uses`, `excessive-permissions`(워크플로 수준과 job 수준), `dangerous-triggers`(`pull_request_target`, `workflow_run`, `issue_comment`), `impostor-commit`, `ref-version-mismatch`, `artipacked`, `template-injection` 이 있다. `unpinned-uses` 는 자동 수정을 지원하지 않는다("Auto-fixes available: ❌").
3. **공식 문서**, [zizmor usage](https://docs.zizmor.sh/usage/): 입력으로 `my-action/action.yml` 같은 composite action 정의를 받는다. `--min-severity`, `--min-confidence`, `--persona`(regular, pedantic, auditor)가 있다. 종료 코드 11~14 는 가장 높은 발견의 심각도이고, SARIF 형식은 이 종료 코드를 끈다. 온라인 모드는 `GH_TOKEN` 같은 토큰이 있을 때 켜진다.
4. **공식 문서**, [About code scanning](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning): "If you want to use code scanning on private repositories, you need a GitHub Code Security license."(번역: 비공개 저장소에서 코드 스캐닝을 쓰려면 GitHub Code Security 라이선스가 필요하다.)
5. **공식 문서**, [Code scanning REST](https://docs.github.com/en/rest/code-scanning/code-scanning#update-a-code-scanning-default-setup-configuration): `PATCH /repos/{owner}/{repo}/code-scanning/default-setup` 의 본문은 `state`, `query_suite`, `languages` 이고, "Response if the repository is archived or if GitHub Advanced Security is not enabled"(번역: 저장소가 보관됐거나 GitHub Advanced Security 가 켜져 있지 않을 때의 응답) 가 403 이다.
6. **공식 문서**, [Repository rules REST](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset): `bypass_mode` 는 `always`, `pull_request`, `exempt` 셋이다. "pull_request means that an actor can only bypass rules on pull requests."(번역: pull_request 는 행위자가 풀 리퀘스트에서만 규칙을 우회할 수 있다는 뜻이다.) `required_status_checks` 의 항목은 `context`(필수)와 `integration_id`(선택)다. `non_fast_forward`, `deletion`, `pull_request` 규칙이 있다.
7. **공식 문서**, [Creating a default community health file](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file): 조직뿐 아니라 개인 계정도 기본값을 둘 수 있다. "The `.github` repository must be public."(번역: `.github` 저장소는 공개여야 한다.) 우선순위는 `.github` 폴더, 루트, `docs` 폴더 순이다. 목록에 CODEOWNERS 는 없다.
8. **공식 문서**, [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions): 공개 저장소의 표준 러너는 무료다. 비공개 저장소에는 GitHub Free 가 2,000분, Pro 가 3,000분을 포함한다. 분당 요금은 Linux 2코어 $0.006, macOS $0.062 다.
9. **실측**, Claude Code 의 `AskUserQuestion` 도구 스키마: 질문 하나의 선택지는 2~4개다(2026-09-22 세션에 주어진 스키마의 `minItems: 2`, `maxItems: 4`). 공개 문서에서 확인한 값은 아니다.
10. **실측**(이 저장소, 비공개였던 시점)
    - `gh api repos/IsthisLee/repo-setup/code-scanning/default-setup` → HTTP 403 "Code scanning is not enabled for this repository."
    - `gh api repos/IsthisLee/repo-setup/rulesets` → HTTP 200, 0개. 만들 수 있다는 증거는 아니다.
    - `gh api repos/IsthisLee/repo-setup/community/profile` → 응답은 왔지만 `files` 에 `security` 키가 없다.
    - 그 뒤 `gh repo edit --visibility public` 으로 공개로 바꿨다. 공개하기 전에 전체 이력(커밋 17개)에서 홈 경로, 흔한 비밀 형식, `.private/`, 개인 패턴이 추가된 줄이 모두 0건임을 확인했다.
11. **공식 문서가 아닌 원전**, Michael Nygard, [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)(2011): 절은 Title, Context, Decision, Status, Consequences 다섯이다. "ADRs will be numbered sequentially and monotonically. Numbers will not be reused."(번역: ADR 은 차례대로, 줄어들지 않게 번호를 매긴다. 번호는 다시 쓰지 않는다.) "If a decision is reversed, we will keep the old one around, but mark it as superseded."(번역: 결정이 뒤집히면 옛것을 지우지 않고 대체됐다고 표시한다.) 상태는 proposed, accepted, deprecated, superseded 넷이다.
12. **공식 문서**, Claude Code [Best practices](https://code.claude.com/docs/en/best-practices): 인터뷰 프롬프트 예시가 "write a complete spec to SPEC.md"(번역: 완전한 스펙을 SPEC.md 에 써라)로 끝나고, "Once the spec is complete, start a fresh session to execute it."(번역: 스펙이 완성되면 그것을 실행할 새 세션을 시작하라.)라고 적혀 있다. 스펙 파일을 끝난 뒤 어떻게 할지는 다루지 않는다. 그래서 결정 16 의 "끝나면 지운다"는 이 저장소가 정한 규칙이다.
13. **공식 문서가 아닌 원전**, [Diátaxis](https://diataxis.fr/): "Diátaxis identifies four distinct needs, and four corresponding forms of documentation"(번역: Diátaxis 는 서로 다른 네 가지 필요와 그에 대응하는 네 가지 문서 형태를 구별한다). 네 형태는 tutorials(배우기 위한 문서), how-to guides(과제를 이루기 위한 문서), reference(찾아보기 위한 문서), explanation(이해를 깊게 하기 위한 문서)다.
14. **공식 문서**, GitHub [Adding or editing wiki pages](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages): GitHub 의 Wiki 기능은 `git clone https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.wiki.git` 으로 받는 별도 저장소이고, 기본 브랜치에 푸시한 변경이 바로 반영된다. PR 을 거친다는 설명은 없다. 그래서 설계 문서는 GitHub Wiki 가 아니라 저장소 안 `docs/wiki/` 에 둔다. 코드와 같은 PR 에서 리뷰되고, 작업 트리에서 일하는 에이전트와 invariants 가 볼 수 있어야 하기 때문이다.
15. **공식 문서**, [husky How To](https://typicode.github.io/husky/how-to.html): `package.json` 에 `"prepare": "husky"` 를 두면 의존성을 설치한 뒤 자동으로 돌아 훅이 켜진다. 훅은 `.husky/` 폴더에 파일로 둔다. "To avoid installing Git Hooks on CI servers or in Docker, use `HUSKY=0`."(번역: CI 서버나 Docker 에서 git 훅을 설치하지 않으려면 `HUSKY=0` 을 쓴다.) `husky` 가 `core.hooksPath` 를 쓴다는 문장은 이 문서에서 찾지 못했다.
16. **공개 저장소**, GitHub [Scripts To Rule Them All](https://github.com/github/scripts-to-rule-them-all): "Set of boilerplate scripts describing the normalized script pattern that GitHub uses in its projects."(번역: GitHub 이 자기 프로젝트에서 쓰는 표준화된 스크립트 패턴을 설명하는 기본 스크립트 모음.) `script/setup` 은 "Used to set up a project in an initial state. This is typically run after an initial clone"(번역: 프로젝트를 처음 상태로 세팅하는 데 쓴다. 보통 처음 클론한 뒤에 실행한다).
17. **공식 문서**, [pre-commit](https://pre-commit.com/): 클론한 뒤 각자 `pre-commit install` 을 실행해야 하고, 이를 자동으로 하려면 `git config --global init.templateDir ~/.git-template` 와 `pre-commit init-templatedir ~/.git-template` 를 쓰라고 안내한다. 로컬 훅은 `repo: local` 로 정의하고 bash 스크립트의 `language` 는 `unsupported_script` 다. `default_install_hook_types: [pre-commit, commit-msg]` 나 `pre-commit install --hook-type commit-msg` 로 commit-msg 단계를 켠다.
18. **공식 문서**, [lefthook](https://lefthook.dev/): 언어와 무관한 단일 실행 파일이고 npm, pip, gem, go, Homebrew 등으로 설치한다. `lefthook install` 이 "installs the configured hooks into `.git/hooks/`"(번역: 설정한 훅을 `.git/hooks/` 에 설치한다). npm 으로 설치할 때 `lefthook install` 이 자동으로 도는지는 이 문서에서 확인하지 못했다.
19. **실측**, git 2.53.0 의 `man githooks` 와 `man git-init`: 훅은 `$GIT_DIR/hooks` 나 `core.hooksPath` 가 가리키는 폴더에서만 찾는다. `git init`(과 `git clone`)은 템플릿 폴더의 파일을 새 `$GIT_DIR` 로 복사하고, 템플릿 폴더는 `--template`, `$GIT_TEMPLATE_DIR`, `init.templateDir`, 기본 폴더 순으로 정해진다. "Running git init in an existing repository is safe. It will not overwrite things that are already there."(번역: 이미 있는 저장소에서 git init 을 실행해도 안전하다. 이미 있는 것을 덮어쓰지 않는다.) 설정만으로 훅을 거는 `hook.<이름>.command` 는 이 판의 `man git-config` 에서 찾지 못했다. 그래서 클론만으로 저장소 안의 훅이 켜지는 구성은 없고, 켜는 단계가 어딘가에 반드시 있다.
20. **공개 저장소**, GitHub [actions/runner-images](https://github.com/actions/runner-images): README 의 표에서 `ubuntu-latest` 는 Ubuntu 24.04(x64)이고 `macos-latest` 는 macOS 26 Arm64 다. `images/ubuntu/Ubuntu2404-Readme.md` 에는 Bash 5.2.21 과 apt 패키지 `shellcheck` `0.9.0-1` 이 있다. `images/macos/macos-26-arm64-Readme.md` 에는 Bash 3.2.57 이 있고 shellcheck 는 없다. 그리고 **실측**으로, shellcheck 공식 릴리스 v0.11.0 의 `linux.x86_64`·`darwin.aarch64` tar.gz 자산을 받아 잰 sha256 이 릴리스 API 의 `digest` 값과 같았다.
21. **실측**, Claude Code 2.1.278 의 플러그인 업데이트(③ 에서 확인). 설정 폴더를 `CLAUDE_CONFIG_DIR` 로 격리하고 `claude plugin marketplace add IsthisLee/repo-setup` 으로 main(0.1.0)을 설치하니 `claude plugin details` 가 `Skills (6)` 을 보였다. 마켓플레이스 복제본을 ③ 의 커밋으로 옮긴 뒤 `claude plugin update repo-setup@repo-setup` 은 "updated from 0.1.0 to 0.2.0" 을 내고 `Skills (1)  repo-setup` 이 되었다. 캐시는 판 번호별 폴더(`cache/repo-setup/repo-setup/0.1.0/`, `0.2.0/`)이고 0.1.0 폴더는 남았다. `claude plugin marketplace update` 가 main 을 받아 오는 단계는 이 시험에서 거치지 않았다. `file://` 주소는 마켓플레이스 출처로 받지 않았다("Invalid marketplace source format").
22. **실측**, `skills` CLI 1.7.0(③ 에서 확인). 가짜 홈의 임시 프로젝트에 옛 판(main)을 `add <로컬 사본> -y -a claude-code` 로 설치하니 `.claude/skills/` 에 스킬 여섯이 놓였다. 새 판을 같은 방식으로 설치하면 `repo-setup` 은 목적 폴더가 든 새 구조로 바뀌고 실행 비트도 보존되지만, 옛 스킬 다섯의 폴더와 `skills-lock.json` 항목은 남았다. `remove repo-privacy repo-license repo-ci repo-secure repo-contrib -y` 가 다섯을 지웠고, 전역 설치에서도 `-g` 를 붙여 같은 결과가 나왔다. GitHub 에서 받는 `add IsthisLee/repo-setup` 은 새 판이 main 에 들어가기 전이라 시험하지 않았다.

## 7. 구현 전에 확인할 것 (아직 확인하지 않음)

- zizmor: `zizmor.yml` 에서 `unpinned-uses` 정책을 쓰는 정확한 형식, 설정 파일을 찾는 위치, 예외를 적는 형식, `impostor-commit`·`ref-version-mismatch` 가 온라인 모드를 요구하는지, 공식 설치 명령, 대상 CI 에서 돌리는 방법(공식 액션인지 패키지 설치인지)과 버전 고정 방법, 규칙마다 에이전트가 고칠 수 있는지를 가를 근거.
- 룰셋: `RepositoryRole` 의 저장소 관리자 `actor_id`, 개인 계정의 공개 저장소에서 룰셋을 만들 수 있는지, check-runs 의 `app.id` 가 `integration_id` 로 그대로 통하는지, 직접 푸시가 거절될 때의 실제 메시지, check-run 과 워크플로 파일을 이어 주는 가장 확실한 API.
- 코드 스캐닝 default setup: `languages` 를 빼면 GitHub 이 언어를 고르는지, 응답이 202 인지와 되읽기에 걸리는 시간, 고급 설정 워크플로가 있을 때의 응답.
- secret scanning: 쓸 수 없는 저장소에서 `PATCH` 가 내는 상태 코드와 메시지, push protection 이 동료의 푸시를 거절할 때의 메시지.
- dependabot: 생태계마다 한 번에 여는 PR 수의 기본 상한.
- GitHub 라이선스 템플릿: 지원할 키마다의 자리표시자 목록(`[year]`, `[fullname]` 외).
- husky: 지금 판의 설치 명령과 `.husky/` 훅 파일 형식, `husky` 가 `core.hooksPath` 를 쓰는지(공식 문서에서는 확인하지 못했고, 이 저장소 `setup.sh` 주석의 실측 기록만 있다), `HUSKY=0` 의 동작, git 저장소 밖에서 `npm install` 할 때의 동작.
- pre-commit 프레임워크: `repo: local` 훅의 `language` 값(2026-09-22 문서에서는 `unsupported_script`), commit-msg 단계에 걸 때의 `stages` 값, 커밋할 때 스테이징하지 않은 변경을 잠시 치웠다 되돌리는 동작이 가드의 인덱스 검사와 부딪히지 않는지.
- lefthook: 지금 판의 `lefthook.yml` 형식(문서 예시는 `jobs`), commit-msg 훅에 메시지 파일 경로를 넘기는 방법.
- CI 가드: `pull_request` 이벤트에서 기준 커밋과 머리 커밋을 얻는 방법과 `actions/checkout` 의 `fetch-depth`, 포크에서 온 PR 에서의 동작, main 푸시에서 범위를 정하는 방법(`github.event.before`).

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

### 8.2 가드 (⑤⑥⑦ 뒤, 로컬 임시 저장소)

`privacy/templates/` 의 파일을 새 임시 저장소에 복사하고 `script/setup` 를 돌린 뒤, 실제 `git commit` 으로 확인한다.

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

- `script/setup --verify` 는 `검증 통과` 와 exit 0 을 내야 하고, pre-commit 과 commit-msg 를 모두 탐침해야 한다.
- `.githooks/team-patterns` 가 있는 저장소에서 `script/setup` 를 돌린 뒤 `git status --porcelain` 에 모드 변경이 없어야 한다.

### 8.3 처음 세팅하는 경로 (⑬ 뒤, 공개 임시 저장소)

1. 사용자에게 확인받은 뒤 `gh repo create IsthisLee/repo-setup-e2e --public --clone` 을 실행한다. 저장소에는 pytest 테스트 하나를 가진 작은 파이썬 프로젝트만 두고, LICENSE 와 워크플로는 두지 않는다.
2. 그 저장소에서 `/repo-setup` 을 인자 없이 돌린다.
3. 확인 흐름을 확인한다.
   - 목적을 고르기 전에 다섯 카드가 모두 나오고, 각 카드에 일곱 칸이 있으며, 숫자 칸에 실측값이 들어 있다.
   - 목적 고르기는 두 질문(로컬 층, GitHub 층)으로 나온다.
   - 파일 쓰기, 푸시, GitHub 설정 변경마다 확인 질문이 따로 나온다.
4. 변경 전달을 확인한다. `repo-setup/<날짜>` 브랜치에 목적별 커밋이 있고, PR 하나가 열리며, main 에는 커밋이 없다.
5. 목적별 결과를 확인한다.

| 목적 | 명령 | 기대 |
|---|---|---|
| privacy | `script/setup --verify` | `검증 통과`, exit 0 |
| privacy(PR 검사) | 가짜 홈 경로(`/Users` 뒤에 `example` 을 실행할 때 조립)를 담은 커밋을 새 브랜치에 푸시하고 PR 을 연다 | `guard.yml` 이 실패하고, 출력에 파일과 줄 번호가 나오며 패턴 값은 나오지 않는다. 그 PR 은 닫고 브랜치를 지운다 |
| license | `check-license.sh --expect mit --year 2026 --holder <이름>` | exit 0. 병합한 뒤 `gh api repos/IsthisLee/repo-setup-e2e/license --jq .license.spdx_id` → `MIT` |
| ci | `wait-run.sh tests.yml "$(git rev-parse HEAD)"` | 세팅 PR 의 실행에서 exit 0. `check-test-run.sh` 가 1 이상 |
| secure | `gh api repos/IsthisLee/repo-setup-e2e --jq '.security_and_analysis \| .secret_scanning.status, .secret_scanning_push_protection.status'` | `enabled` 두 줄 |
| secure | `gh api repos/IsthisLee/repo-setup-e2e/code-scanning/default-setup --jq .state` | `configured` |
| secure | `GH_TOKEN="$(gh auth token)" zizmor --min-severity=low .github/` | exit 0. zizmor 워크플로 실행도 성공 |

6. 세팅 PR 을 병합하기 전에 `/repo-setup contrib` 를 부르면, 룰셋을 걸지 않고 "병합한 뒤 다시 부른다"를 보고해야 한다.
7. 병합한 뒤 `/repo-setup contrib` 를 부른다.

| 확인 | 기대 |
|---|---|
| `ruleset.sh --list --commit <main 의 최신 SHA>` | tests.yml 의 check 가 워크플로 경로와 함께 나오고, zizmor 워크플로의 check 는 `paths` 필터 표시와 함께 기본으로 빠져 있음 |
| `gh api repos/IsthisLee/repo-setup-e2e/rules/branches/main --jq '[.[].type] \| sort'` | `deletion`, `non_fast_forward`, `pull_request`, `required_status_checks` 가 모두 있음 |
| 빈 커밋을 main 으로 직접 `git push` | 거절. 거절 메시지를 기록해 3.2.2 예시 카드의 문구를 바꾼다 |
| 같은 커밋을 PR 로 올림 | 필수 검사가 이름대로 나타나고, 통과한 뒤 병합 가능 |

### 8.4 활발한 저장소를 흉내 낸 경로 (⑬ 뒤, 공개 임시 저장소)

1. 사용자에게 확인받은 뒤 `gh repo create IsthisLee/repo-setup-e2e-active --public --clone` 을 실행하고 다음을 미리 만든다.
   - 테스트가 있는 프로젝트, MIT LICENSE
   - 기존 워크플로 둘. 하나는 `pull_request` 에서 테스트를 돌리고 액션을 태그로 참조하며 `permissions` 가 없다. 다른 하나는 `paths: [docs/**]` 필터가 있는 문서 검사다.
   - main 에 PR 없이 직접 푸시한 커밋 3개
   - 열린 PR 2개. 하나는 문서만 고치고, 하나는 코드를 고친다.
   - 작업 트리에 추적 파일의 수정 하나
2. `/repo-setup` 을 인자 없이 돌린다.

| 확인 | 기대 |
|---|---|
| 시작 | 작업 트리의 수정 때문에 멈추고, 커밋하거나 치우라고 안내함. 수정을 치운 뒤 다시 부르면 진행 |
| license | 기존 LICENSE 를 다시 쓰지 않고, 카드에 이미 있다고 나옴 |
| ci | tests.yml 을 새로 만들지 않고, 기존 워크플로가 PR 에서 테스트를 돈다고 보고함 |
| secure | 기존 워크플로의 zizmor 발견이 규칙별로 묶여 나옴. 에이전트가 고친 변경은 별도 커밋이고 파일과 줄 수가 보고됨. 로컬 zizmor 가 0건이 된 뒤에만 zizmor 워크플로가 PR 에 들어감 |
| contrib | `ruleset.sh --list` 에서 문서 검사 워크플로의 check 는 `paths` 필터 표시와 함께 기본으로 빠짐. `impact:` 에 열린 PR 2개와 멈출 PR 번호, PR 없이 들어온 커밋 3개가 나옴 |

3. 두 임시 저장소는 사람이 `gh auth refresh -s delete_repo` 를 직접 실행한 뒤, 삭제 직전에 다시 확인받고 `gh repo delete <저장소> --yes` 로 지운다.

### 8.5 이미 도구가 있는 실제 저장소 (⑬ 뒤, 이 저장소)

이 저장소에서 `/repo-setup` 을 돌린다. 확인 흐름은 8.3 과 같다.

| 확인 | 기대 |
|---|---|
| `check-license.sh`(인자 없음) | exit 0, MIT. LICENSE 를 다시 쓰지 않음 |
| `.github/workflows/test.yml` | 내용이 그대로이고 tests.yml 을 새로 만들지 않음 |
| `script/setup` | 이미 걸린 `.githooks` 를 멱등으로 통과 |
| `secret-scanning.sh`, `code-scanning.sh` | 적용 뒤 되읽기 일치, exit 0 |
| `ruleset.sh --list --commit <main 의 최신 SHA>` 와 적용 | ubuntu 와 macOS 두 check 가 필수 후보로 나오고, 고른 뒤 `gh api repos/IsthisLee/repo-setup/rules/branches/main` 에 네 규칙이 있음 |

이 저장소에서는 main 으로 직접 푸시해 보는 시험을 하지 않는다. 설정이 틀렸다면 그 커밋이 main 에 남기 때문이다. 되읽기로만 확인한다.

### 8.6 로컬 훅을 켜는 방식 (⑨ 뒤, 로컬 임시 저장소)

GitHub 없이 로컬 임시 저장소 넷을 만들어 privacy 만 돌린다(`/repo-setup privacy`). npm 이 있어야 한다.

| 저장소 | 기대 |
|---|---|
| `package.json` 만 있고 훅 도구 없음 | husky 가 devDependency 로 들어가고 잠금 파일은 npm 이 다시 만든다. `package.json` 에 `"prepare": "husky"`. 새로 클론해 `npm install` 만 하고 홈 경로가 든 커밋을 시도하면 차단된다. `script/setup` 은 놓이지 않는다 |
| 이미 husky 를 씀(`.husky/pre-commit` 에 `npm test`) | 기존 줄은 그대로 두고 가드를 부르는 줄만 더해진다. 차단 시험이 통과한다 |
| 이미 pre-commit 프레임워크를 씀 | `.pre-commit-config.yaml` 에 `repo: local` 훅 둘이 더해진다. `pre-commit install` 뒤 차단 시험이 통과한다(pre-commit 이 설치돼 있을 때만. 없으면 이 줄은 건너뛰고 그 사실을 기록한다) |
| 아무것도 없음 | `script/setup` 이 놓이고, 실행한 뒤 차단 시험이 통과한다 |

네 경우 모두 스킬 폴더의 `privacy/templates/setup --verify` 를 대상 저장소 루트에서 돌려 `검증 통과` 와 exit 0 이 나와야 한다. 같은 저장소에서 `HUSKY=0 npm install` 을 하면 훅이 설치되지 않는 것도 확인한다(공식 문서의 동작).

## 9. 진행 상황

| # | 상태 | PR |
|---|---|---|
| PR #1 | 병합(2026-09-22, 두 러너에서 177건 통과) | https://github.com/IsthisLee/repo-setup/pull/1 |
| ① | 병합(2026-09-22) | https://github.com/IsthisLee/repo-setup/pull/2 |
| ② | 병합(2026-09-22) | https://github.com/IsthisLee/repo-setup/pull/3 |
| ③ | 진행 중 | |
| ④ ~ ⑭ | 대기 | |
