---
name: repo-setup
description: Set up a git repository for its intended purpose. Measures visibility, ownership (personal or team), host, and existing tooling before acting, then applies only the steps that actually fit and calls the narrow skills in order, reporting what was done and what was skipped with reasons. Use it for requests like "set up this repo", "prepare a public repository", or "new repo setup". git 저장소를 용도에 맞게 세팅한다. 공개 여부, 소유(개인/팀), 호스트, 이미 깔린 도구를 먼저 실측하고, 그 저장소에 해당하는 세팅만 골라 좁은 스킬을 순서대로 호출한다. 무엇을 했고 무엇을 왜 건너뛰었는지 함께 보고한다. "저장소 세팅해줘", "공개 저장소 준비", "새 저장소 세팅" 같은 요청에 쓴다.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
---

# 저장소 세팅

$ARGUMENTS 용도로 이 저장소를 세팅한다. 용도를 안 적었으면 1단계 실측 결과를 보이고 물어본다.

윗줄에 달러 기호가 붙은 대문자 자리표시자가 그대로 보이면, 인자를 넘기지 않는 환경이다. 그때는
사용자가 바로 앞에서 한 말에서 용도를 읽고, 그래도 없으면 1단계 실측 결과를 보인 뒤 물어본다.

내가 쓰는 언어로 답한다.

## 이 스킬이 하는 일

**세팅을 직접 하지 않는다.** 실측해서 무엇이 필요한지 정하고, 좁은 스킬을 호출하고, 결과를 모아 보고한다.
**단계를 새로 만들지 마라. 이미 있는 것을 호출하라.**

좁은 스킬마다 같은 실측을 반복하면 느리고 결과가 갈린다. 그래서 공통 실측을 여기서 한 번 하고 물려준다.

## 1. 실측한다

**추측하지 않는다.** 아래를 실제로 돌리고, 결과를 사용자에게 보인 뒤 다음으로 간다.

```bash
git rev-parse --show-toplevel            # git 저장소인가. 아니면 멈춘다
git remote -v                            # 호스트: GitHub · GitLab · Bitbucket · 없음
git config core.hooksPath                # 이미 다른 훅 관리자가 잡고 있나
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
| 기존 도구 | `core.hooksPath`, 파일 목록 | 덮어쓰지 않고 얹는다 |

판별이 안 되면 **팀 저장소이고 공개라고 간주한다.** 모르는 쪽에서 안전한 선택이다.

## 2. 무엇이 필요한지 정한다

실측 결과와 용도를 맞춰 **해당하는 것만** 고른다. 해당하지 않는 것을 넣지 않는다. 개인 실험 저장소에
CODEOWNERS 를 넣을 일이 없다.

고른 것과 **뺀 것을 이유와 함께** 사용자에게 보인다. 용도가 모호하거나 되돌리기 어려운 항목이 섞이면
선택지를 만들어 사용자에게 확정받는다(Claude Code 라면 `AskUserQuestion` 을 쓴다). 항목마다
그것이 무엇을 바꾸고 무엇을 감수하는지 적는다.

## 3. 좁은 스킬을 호출한다

**순서대로 부른다.** 순서에는 이유가 있고, 바꾸면 뒤 단계가 앞 단계의 결과를 못 본다.

| 스킬 | 고르는 조건 | 빼는 조건 | 순서 | 선행 |
|---|---|---|---|---|
| `repo-privacy` | 항상 | 없음. 남의 훅 관리자가 잡고 있으면 덮지 않고 공존 한 줄을 안내한다 | 1 | 없음 |
| `repo-license` | `LICENSE` 가 없고 공개이거나 배포물이다 | 비공개 개인 실험 | 2 | 없음 |
| `repo-ci` | 테스트 명령이 실측되고 워크플로가 없다 | 테스트가 없으면 만들지 않는다 | 3 | 없음 |

가드가 맨 앞인 이유는 **뒤 단계가 만드는 파일도 가드를 거쳐야 하기 때문**이다.

**테스트가 없는 저장소에 CI 를 만들지 않는다.** 빈 CI 는 아무것도 검사하지 않으면서 통과
표시만 주고, 그 표시를 브랜치 보호의 필수 검사로 걸면 보호가 껍데기가 된다.

호출할 때 1단계 실측 결과를 함께 넘긴다. 그 스킬이 같은 측정을 다시 하지 않아도 되게 한다.

목록에 없는 세팅(브랜치 보호, secret scanning, CODEOWNERS 등)이 필요하면
**직접 하지 말고 그 사실을 보고한다.** 여기서 즉흥으로 만들면 테스트도 근거도 없는 세팅이
들어간다. 필요하면 좁은 스킬을 새로 만드는 것이 순서다. 무엇을 만들지는
`docs/decisions.md` 에 적혀 있다.

## 4. 보고한다

근거와 함께 적는다.

- **1단계 실측값** — 네 축의 실제 값. 판별을 못 한 축이 있으면 그 사실과 무엇으로 간주했는지.
- **한 것** — 어떤 스킬을 불렀고 그 결과가 무엇인지. 그 스킬이 검증을 요구하면 그 결과까지.
- **건너뛴 것과 이유** — 이 칸이 비어 있으면 안 된다. 사용자는 빠진 것을 알아야 한다.
- **사람이 해야 할 것** — 팀 합의가 필요한 것, 권한이 없어 못 한 것, 값을 사람만 아는 것.

**검증 결과 없이 세팅됐다고 보고하지 않는다.** 설정을 걸었다고 적용된 것이 아니다.
