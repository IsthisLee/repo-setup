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

목적마다 같은 실측을 반복하면 느리고 결과가 갈린다. 그래서 공통 실측을 여기서 한 번 하고 물려준다.

이 SKILL.md 가 있는 폴더를 **스킬 폴더**라 부른다. 목적마다 `<목적>/PROCEDURE.md` 가 있고, 절차 문서가
가리키는 `<목적>/scripts/…` 와 `<목적>/templates/…` 는 스킬 폴더 기준 경로다. `scripts/` 의 파일은 그
자리에서 실행하고, `templates/` 의 파일은 대상 저장소로 복사한다. 스크립트는 대상 저장소의 루트를 현재
폴더로 두고 `bash "<스킬 폴더>/license/scripts/check-license.sh"` 처럼 돌린다.

## 1. 실측한다

**추측하지 않는다.** 아래를 실제로 돌리고, 결과를 사용자에게 보인 뒤 다음으로 간다.

```bash
git rev-parse --show-toplevel            # git 저장소인가. 아니면 멈춘다
git remote -v                            # 호스트: GitHub · GitLab · Bitbucket · 없음
git config core.hooksPath                # 이미 다른 훅 관리자가 잡고 있나
find "$(git rev-parse --git-common-dir)/hooks" -type f -perm -u+x ! -name '*.sample'   # .git/hooks 에 도는 훅이 있나
ls -a                                    # 이미 있는 것: .gitignore · LICENSE · .github/ · CI 설정
```

GitHub 원격이 있으면 이것도 본다.

```bash
gh repo view --json owner,viewerPermission,visibility,isInOrganization \
  --jq '{owner: .owner.login, perm: .viewerPermission, visibility, org: .isInOrganization}'
gh api user --jq '.login'
```

여기서 정해지는 것이 넷이다.

| 축 | 판별 | 무엇이 갈리나 |
|---|---|---|
| 공개/비공개 | `visibility` | 공개면 홈 경로·이메일이 실제 위험. 비공개면 자격증명 쪽이 우선 |
| 개인/팀 | `org` 가 `true`, `owner` 가 내 로그인과 다름, `perm` 이 `ADMIN` 아님 중 하나라도 | **팀이면 공유 자산을 고치지 않고 제안만 한다** |
| 호스트 | `git remote -v` | 서버 층 명령이 갈린다. 없으면 로컬 층만 |
| 기존 도구 | `core.hooksPath`, `.git/hooks`, 파일 목록 | 덮어쓰지 않고 얹는다 |

판별이 안 되면 **팀 저장소이고 공개라고 간주한다.** 모르는 쪽에서 안전한 선택이다.

## 2. 무엇이 필요한지 정한다

실측 결과와 용도를 맞춰 **해당하는 것만** 고른다. 해당하지 않는 것을 넣지 않는다. 개인 실험 저장소에
CODEOWNERS 를 넣을 일이 없다.

고른 것과 **뺀 것을 이유와 함께** 사용자에게 보인다. 용도가 모호하거나 되돌리기 어려운 항목이 섞이면
선택지를 만들어 사용자에게 확정받는다(Claude Code 라면 `AskUserQuestion` 을 쓴다). 항목마다
그것이 무엇을 바꾸고 무엇을 감수하는지 적는다.

## 3. 고른 목적의 절차를 따른다

**순서대로 따른다.** 순서에는 이유가 있고, 바꾸면 뒤 단계가 앞 단계의 결과를 못 본다.

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

고른 목적마다 스킬 폴더의 `<목적>/PROCEDURE.md` 를 읽고 그 단계를 따른다. 절차 문서의 실측 단계에서는
1단계에서 이미 잰 것을 다시 재지 않는다.

목록에 없는 세팅이 필요하면
**직접 하지 말고 그 사실을 보고한다.** 여기서 즉흥으로 만들면 테스트도 근거도 없는 세팅이
들어간다. 필요하면 목적을 새로 더하는 것이 순서다.

## 4. 보고한다

근거와 함께 적는다.

- **1단계 실측값** — 네 축의 실제 값. 판별을 못 한 축이 있으면 그 사실과 무엇으로 간주했는지.
- **한 것** — 어떤 목적을 따랐고 그 결과가 무엇인지. 그 절차가 검증을 요구하면 그 결과까지.
- **건너뛴 것과 이유** — 이 칸이 비어 있으면 안 된다. 사용자는 빠진 것을 알아야 한다.
- **사람이 해야 할 것** — 팀 합의가 필요한 것, 권한이 없어 못 한 것, 값을 사람만 아는 것.

**검증 결과 없이 세팅됐다고 보고하지 않는다.** 설정을 걸었다고 적용된 것이 아니다.
