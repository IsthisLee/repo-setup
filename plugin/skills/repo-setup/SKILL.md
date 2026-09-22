---
name: repo-setup
description: Set up a git repository for its intended purpose. Measures visibility, ownership (personal or team), host, and existing tooling before acting, then applies only the purposes that actually fit, in order - a pre-commit guard against personal information (privacy), a consistent license (license), a test workflow proven by a real run (ci), the host security layer and pinned actions (secure), and collaboration files with branch protection (contrib) - reporting what was done and what was skipped with reasons. Pass one purpose name to run only that purpose. Use it for requests like "set up this repo", "prepare a public repository", "add a license", or "new repo setup". git 저장소를 용도에 맞게 세팅한다. 공개 여부, 소유(개인/팀), 호스트, 이미 깔린 도구를 먼저 실측하고, 개인 정보 커밋 가드(privacy), 라이선스(license), 실제로 돌려 확인하는 테스트 워크플로(ci), 호스트 보안 층과 액션 고정(secure), 협업 파일과 브랜치 보호(contrib) 가운데 그 저장소에 해당하는 목적만 골라 순서대로 적용한다. 목적 이름 하나를 인자로 주면 그 목적만 돈다. 무엇을 했고 무엇을 왜 건너뛰었는지 함께 보고한다. "저장소 세팅해줘", "공개 저장소 준비", "라이선스 넣어줘", "새 저장소 세팅" 같은 요청에 쓴다.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
---

# 저장소 세팅

$ARGUMENTS 용도로 이 저장소를 세팅한다. 용도를 안 적었으면 1단계 실측 결과를 보이고 물어본다.

인자가 목적 이름(`privacy`, `license`, `ci`, `secure`, `contrib`) 하나이면 그 목적만 돈다. 이때도 1단계
공통 실측은 한다.

윗줄에 달러 기호가 붙은 대문자 자리표시자가 그대로 보이면, 인자를 넘기지 않는 환경이다. 그때는
사용자가 바로 앞에서 한 말에서 용도를 읽고, 그래도 없으면 1단계 실측 결과를 보인 뒤 물어본다.

내가 쓰는 언어로 답한다.

## 이 스킬이 하는 일

실측해서 무엇이 필요한지 정하고, 고른 목적의 절차 문서를 순서대로 따르고, 결과를 모아 보고한다.
**단계를 새로 만들지 마라. 절차 문서에 있는 것만 한다.**

**사람이 무엇에 동의하는지 알고 나서 바꾼다.** 목적을 고를 때 카드로 한 번 확인받고, 고른 목적 안에서
부작용이 있는 단계마다 한 번 더 확인받는다. 파일 변경은 기본 브랜치에 직접 커밋하지 않고 세팅 브랜치에
모아 PR 한 개로 올린다.

목적마다 같은 실측을 반복하면 느리고 결과가 갈린다. 그래서 공통 실측을 여기서 한 번 하고 물려준다.

이 SKILL.md 가 있는 폴더를 **스킬 폴더**라 부른다. 목적마다 `<목적>/PROCEDURE.md` 가 있고, 절차 문서가
가리키는 `<목적>/scripts/…` 와 `<목적>/templates/…` 는 스킬 폴더 기준 경로다. `scripts/` 의 파일은 그
자리에서 실행하고, `templates/` 의 파일은 대상 저장소로 복사한다. 스크립트는 대상 저장소의 루트를 현재
폴더로 두고 `bash "<스킬 폴더>/license/scripts/check-license.sh"` 처럼 돌린다.

## 1. 실측한다

**추측하지 않는다.** 아래를 실제로 돌리고, 결과를 사용자에게 보인 뒤 다음으로 간다.

```bash
git rev-parse --show-toplevel            # git 저장소인가. 아니면 멈춘다
git status --porcelain                   # 작업 트리. 아래 「시작 조건」을 본다
git remote -v                            # 호스트: GitHub · GitLab · Bitbucket · 없음
git config core.hooksPath                # 이미 다른 훅 관리자가 잡고 있나
find "$(git rev-parse --git-common-dir)/hooks" -type f -perm -u+x ! -name '*.sample'   # .git/hooks 에 도는 훅이 있나
ls -a                                    # 이미 있는 것: .gitignore · LICENSE · .github/ · CI 설정
```

GitHub 원격이 있으면 이것도 본다.

```bash
gh repo view --json owner,viewerPermission,visibility,isInOrganization,defaultBranchRef \
  --jq '{owner: .owner.login, perm: .viewerPermission, visibility, org: .isInOrganization, branch: .defaultBranchRef.name}'
gh api user --jq '.login'
```

**시작 조건.** `git status --porcelain` 에 `??` 로 시작하지 않는 줄이 있으면 추적 파일에 커밋하지 않은
변경이 있는 것이다. 그 줄을 보이고 **여기서 멈춘다.** 사람이 커밋하거나 치운 뒤 다시 부르게 한다. 세팅이
만드는 커밋에 남의 변경이 섞이지 않게 하려는 것이다. 추적되지 않은 파일(`??`)은 두어도 된다.

**기본 브랜치.** GitHub 원격이면 위 `gh repo view` 의 `branch` 를 쓴다. 원격은 있지만 GitHub 이 아니면
`git symbolic-ref --short refs/remotes/origin/HEAD` 에서 앞의 `origin/` 을 뗀다. 둘 다 안 되면 사람에게
묻는다. 지금 체크아웃된 브랜치를 기본 브랜치로 쓰지 않는다.

**활동량.** 카드의 숫자로 쓴다. 원격이 있으면 먼저 `git fetch --quiet origin` 을 한다.

```bash
gh pr list --state open --json number --jq length                         # 열린 PR 수
git rev-list --count --since="30 days ago" "origin/<기본 브랜치>"           # 최근 30일 커밋 수
find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | wc -l   # 기존 워크플로 수
```

셸 글롭(`ls .github/workflows/*.yml`)으로 세지 않는다. zsh 는 맞는 파일이 없는 글롭 하나 때문에 명령 전체를
실패시켜 0 을 낸다.

여기서 정해지는 축이 넷이다.

| 축 | 판별 | 무엇이 갈리나 |
|---|---|---|
| 공개/비공개 | `visibility` | 공개면 홈 경로·이메일이 실제 위험. 비공개면 자격증명 쪽이 우선 |
| 개인/팀 | `org` 가 `true`, `owner` 가 내 로그인과 다름, `perm` 이 `ADMIN` 아님 중 하나라도 | **팀이면 파일 변경은 확인을 받은 뒤 PR 로 올리고, GitHub 설정은 계획만 보인다** |
| 호스트 | `git remote -v` | 서버 층 명령이 갈린다. 없으면 로컬 층만 |
| 기존 도구 | `core.hooksPath`, `.git/hooks`, 파일 목록 | 덮어쓰지 않고 얹는다 |

판별이 안 되면 **팀 저장소이고 공개라고 간주한다.** 모르는 쪽에서 안전한 선택이다.

## 2. 카드로 확인받고 목적을 고른다

1. **실측 결과를 보인다.** 공개 여부, 소유, 호스트, 기본 브랜치, 작업 트리 상태, 활동량, 이미 있는 도구다.
2. **목적마다 카드를 보이고, 적용할 목적을 고르게 한다.** 카드는 각 `<목적>/PROCEDURE.md` 의 「카드」
   절에 있다. `{…}` 를 1단계에서 잰 값으로 채워 보인다. 카드 문구를 고쳐 쓰거나 여기에 옮겨 적지 않는다.
   - 아래 표의 고르는 조건에 맞지 않는 목적은 카드 첫 줄에 이유를 적고 기본으로 빼 둔다. 그래도 사람이
     고를 수 있다.
   - 인자로 목적 한 개를 골랐으면 그 목적의 카드만 보이고 적용할지 묻는다.
   - Claude Code 에서는 `AskUserQuestion` 을 두 번 쓴다. 질문 한 개에 선택지를 네 개까지만 받기 때문이다.
     로컬 층(`privacy`, `license`, `ci`)과 GitHub 층(`secure`, `contrib`)으로 나누고, 여러 개를 고를 수 있게
     묻는다. 다른 에이전트에서는 번호 목록으로 묻는다.
3. **고른 목적 안에서 부작용이 있는 단계마다 다시 확인받는다.** 단계마다 보여 줄 것은 아래와 같다.

   | 단계 | 확인받기 전에 보여 줄 것 |
   |---|---|
   | 새 파일 쓰기 | 경로와 전체 내용(길면 앞뒤와 자리표시자를 채운 값) |
   | 기존 파일 고치기 | `git diff` 형태의 차이와 고친 줄 수 |
   | 푸시와 PR 만들기 | 5단계의 푸시 직전 카드 |
   | GitHub 설정 바꾸기 | 설정 이름, 지금 값, 바꿀 값, 보낼 요청, 되돌리는 명령, 다른 사람에게 미치는 영향 |
   | 로컬에서 테스트 명령 실행 | 돌릴 명령과, 네트워크나 파일에 부작용이 있을 수 있다는 사실 |

카드의 칸은 일곱 개이고 이 순서다. 처음 보는 사람이 읽고 결정할 수 있고, 켠 뒤 겪을 일을 미리 알 수
있어야 한다.

| 칸 | 담는 것 |
|---|---|
| 무엇 | 한두 문장. 용어가 처음 나오면 그 자리에서 뜻을 붙인다 |
| 이유 | 이 저장소에서 필요한 이유. 실측값에 근거한다 |
| 바뀌는 것 | 파일(경로, 새로 만드는지 고치는지), GitHub 설정, 다른 사람에게 생기는 일 |
| 겪는 일 | 켠 뒤 운영 중에 마주칠 장면과 그때 할 일 |
| 감수할 것 | 비용, 속도, 오탐 가능성, 잠길 위험 |
| 되돌리기 | 정확한 명령이나 화면 경로. 되돌릴 수 없는 부분은 그렇다고 적는다 |
| 건너뛰면 | 무엇이 위험으로 남는지 |

- 숫자는 실측값을 쓴다. 추정이면 추정이라고, 잴 수 없었으면 확인하지 못했다고 적는다.
- 카드 한 개는 한 화면 안(16줄 이하)에 들어가야 한다. 채운 값 때문에 넘치면 세부를 「자세히」 한 줄로 접는다.

고르는 조건과 순서는 다음과 같다.

| 목적 | 고르는 조건 | 빼는 조건 | 순서 | 선행 |
|---|---|---|---|---|
| `privacy` | 항상 | 없음. 남의 훅 관리자가 잡고 있으면 덮지 않고 공존 한 줄을 안내한다 | 1 | 없음 |
| `license` | `LICENSE` 가 없고 공개이거나 배포물이다 | 비공개 개인 실험 | 2 | 없음 |
| `ci` | 테스트 명령이 실측되고 워크플로가 없다 | 테스트가 없으면 만들지 않는다 | 3 | 없음 |
| `secure` | 호스트가 GitHub 다 | 권한이 없으면 제안만 한다 | 4 | `ci` |
| `contrib` | 공개이고 기여를 받거나 팀 저장소다 | 개인 비공개 | 5 | `ci` |

가드가 맨 앞인 이유는 **뒤 단계가 만드는 파일도 가드를 거쳐야 하기 때문**이다.

**테스트가 없는 저장소에 CI 를 만들지 않는다.** 빈 CI 는 아무것도 검사하지 않으면서 통과
표시만 주고, 그 표시를 브랜치 보호의 필수 검사로 걸면 보호가 껍데기가 된다.

**`contrib` 이 맨 뒤다.** 브랜치 보호에 CI 상태 검사를 필수로 걸려면 CI 가 먼저 있어야
한다. 없는 검사 이름을 필수로 걸면 영원히 통과하지 않는다.

**`ci` 가 `secure` 보다 앞이다.** `ci` 가 워크플로 파일을 만들고
`secure` 가 그 파일의 액션 고정과 권한을 고친다. 뒤집으면 뒤에 만들어진 워크플로가
고정되지 않은 채로 남는다.

## 3. 세팅 브랜치를 만든다

고른 목적이 파일을 하나도 바꾸지 않으면 이 단계와 5단계를 건너뛴다.

```bash
git fetch origin
git switch -c "repo-setup/$(date +%Y-%m-%d)" "origin/<기본 브랜치>"
```

- 같은 이름의 브랜치가 로컬(`git rev-parse --verify --quiet refs/heads/<이름>`)이나 원격
  (`git ls-remote --exit-code --heads origin <이름>`)에 있으면 이름 뒤에 `-2`, `-3` 을 붙인다.
- 원격이 없는 저장소는 기본 브랜치에서 로컬 브랜치만 만든다. 병합은 사람에게 맡긴다.
- **기본 브랜치에는 직접 커밋하지 않는다.**

## 4. 고른 목적의 절차를 따른다

표의 순서대로 따른다. 순서에는 이유가 있고, 바꾸면 뒤 단계가 앞 단계의 결과를 못 본다.

- 고른 목적마다 스킬 폴더의 `<목적>/PROCEDURE.md` 를 읽고 그 단계를 따른다. 절차 문서의 실측 단계에서는
  1단계에서 이미 잰 것을 다시 재지 않는다.
- 부작용이 있는 단계마다 2단계의 표대로 보여 주고 확인받는다.
- **목적마다 커밋 한 개를 만든다.** 기존 워크플로를 고치는 변경(SHA 고정, 권한 좁히기)은 따로 커밋한다.
  커밋할 때는 그 목적이 만들거나 고친 경로만 이름으로 더한다. `git add -A` 는 쓰지 않는다.
- 커밋 메시지는 대상 저장소의 `git log` 관례를 따르고, 관례가 없으면 Conventional Commits 로 쓴다.
- 절차 문서의 「팀 저장소일 때」가 PR 로 올리라고 한 파일 변경은 이 브랜치에 커밋해 5단계의 PR 로 올린다.
  GitHub 설정은 팀 저장소에서 바꾸지 않고 계획만 보인다.

목록에 없는 세팅이 필요하면
**직접 하지 말고 그 사실을 보고한다.** 여기서 즉흥으로 만들면 테스트도 근거도 없는 세팅이
들어간다. 필요하면 목적을 새로 더하는 것이 순서다.

## 5. 푸시하고 PR 을 연다

**푸시 직전에 카드를 한 번 더 보인다.** 실측값으로 채운다.

- 올라갈 브랜치 이름과 커밋 목록(`git log --oneline "origin/<기본 브랜치>..HEAD"`)
- 이 PR 에서 도는 워크플로(`.github/workflows/` 에서 `pull_request` 트리거를 가진 파일 목록)
- 리뷰 요청이 누구에게 가는지(`CODEOWNERS` 가 있으면 바뀌는 파일에 걸리는 소유자)
- 비공개 저장소라면 계정이나 조직의 Actions 사용량을 쓴다는 사실
- 병합된 뒤 사람마다 해야 할 일. 가드를 적용했으면 각자 클론에서 `script/setup` 을 한 번 돌려야 로컬
  가드가 켜진다

확인을 받으면 푸시하고 PR 한 개를 연다.

```bash
git push -u origin "<세팅 브랜치>"
gh pr create --base "<기본 브랜치>" --head "<세팅 브랜치>" --title "<제목>" --body-file "<본문 파일>"
```

PR 본문에는 목적별로 한 것, 검증 결과, **PR 밖에서 바꾼 GitHub 설정과 되돌리는 명령**, 병합된 뒤 사람이
할 일(위 카드의 마지막 줄, `contrib` 을 다시 부르는 일)을 적는다. `ci` 의 실행 판정은 이 PR 에서 도는
실행으로 한다.

**푸시할 수 없으면 패치로 물러난다.** 포크해서 올리지 않는다.

- 1단계의 `perm` 이 `READ` 나 `TRIAGE` 면 푸시를 시도하지 않는다.
- 푸시가 거절되면(브랜치 이름 규칙, 서명된 커밋 필수, 푸시 제한 같은 정책) 거절 메시지를 그대로 보고한다.
- 두 경우 모두 로컬 브랜치와 커밋을 남기고, `git format-patch "origin/<기본 브랜치>..HEAD" -o <폴더>` 로 만든
  패치 파일의 경로를 알려 준다. 사람이 팀에 공유하거나 권한 있는 사람이 적용할 수 있다.

원격이 없는 저장소는 푸시하지 않고, 로컬 브랜치 이름과 병합할 명령을 보고한다.

## 6. GitHub 설정은 때에 맞춰 바꾼다

- 파일과 무관한 설정(secret scanning, push protection 등)은 그 목적의 절차 안에서 확인을 받으면 바로 바꾼다.
  PR 과 무관하게 즉시 적용되므로 PR 본문과 보고에 따로 적는다.
- **브랜치 보호는 세팅 PR 이 병합된 뒤에 건다.** 필수로 걸 검사를 만드는 워크플로가 기본 브랜치에 없을 때
  걸면 다른 PR 이 모두 멈추기 때문이다. `contrib` 에 이르면 확인한다.
  - 이번 실행에서 세팅 PR 을 열었으면 아직 병합 전이다. 걸지 않고, 「병합한 뒤
    `/repo-setup:repo-setup contrib` 를 다시 부른다」를 사람이 할 일로 보고한다.
  - 파일을 바꾸지 않은 실행이면 열린 세팅 PR 이 있는지 본다.

    ```bash
    gh pr list --state open --json headRefName --jq '[.[] | select(.headRefName | startswith("repo-setup/"))] | length'
    ```

    0 이 아니면 같은 이유로 걸지 않고 보고한다.
- 팀 저장소에서는 어떤 GitHub 설정도 바꾸지 않는다. 무엇을 바꾸면 좋을지 계획만 보인다.

## 7. 보고한다

근거와 함께 적는다.

- **1단계 실측값** — 네 축, 기본 브랜치, 작업 트리, 활동량의 실제 값. 판별을 못 한 축이 있으면 그 사실과
  무엇으로 간주했는지.
- **한 것** — 어떤 목적을 따랐고 그 결과가 무엇인지. 그 절차가 검증을 요구하면 그 결과까지. 세팅 PR 의
  주소와, PR 밖에서 바꾼 GitHub 설정.
- **건너뛴 것과 이유** — 이 칸이 비어 있으면 안 된다. 사용자는 빠진 것을 알아야 한다.
- **사람이 해야 할 것** — PR 병합, 병합한 뒤 `contrib` 다시 부르기, 팀원마다 `script/setup` 돌리기, 팀
  합의가 필요한 것, 권한이 없어 못 한 것, 값을 사람만 아는 것.
- **되돌리는 법** — 세팅 PR 을 닫거나 되돌리는 법과, 바꾼 GitHub 설정마다 카드의 「되돌리기」 칸.

**검증 결과 없이 세팅됐다고 보고하지 않는다.** 설정을 걸었다고 적용된 것이 아니다.
