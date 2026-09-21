---
name: repo-privacy
description: Install a pre-commit guard that blocks personal information (home paths, email addresses, internal domains, private repository names) from being committed, then prove it blocks by attempting a commit. Writes .githooks/pre-commit and setup.sh and sets core.hooksPath. Use it when starting a public repository or porting the guard to another project. 공개 저장소에 개인 정보(홈 경로, 이메일, 사내 도메인, 사적인 저장소 이름)가 커밋되는 것을 막는 pre-commit 가드를 깔고, 실제로 막히는지 커밋을 시도해 확인한다. .githooks/pre-commit 과 setup.sh 를 두고 core.hooksPath 를 건다. 새 공개 저장소를 시작할 때, 세션 프로필이 커밋 가드가 꺼졌다고 알릴 때, 다른 프로젝트로 가드를 옮길 때 쓴다.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# 개인 정보 가드

$ARGUMENTS 에 가드를 깐다(기본값은 현재 저장소). 깔고 나서 **실제로 막히는지 증명한다.**

윗줄에 달러 기호가 붙은 대문자 자리표시자가 그대로 보이면, 인자를 넘기지 않는 환경이다.
그때는 현재 저장소에 깐다.

내가 쓰는 언어로 답한다.

## 왜 필요한가

훅 파일을 커밋해 두어도 그것만으로는 아무 일도 일어나지 않는다. git 은 훅을 `$GIT_DIR/hooks` 에서 찾고,
그 위치를 바꾸는 `core.hooksPath` 는 `.git/config` 에 저장되어 **클론과 함께 전달되지 않는다.** 그래서
새로 클론한 곳과 새 워크트리에서는 가드가 꺼진 상태이고, **막히는 일이 없으므로 아무도 눈치채지 못한다.**
조용히 꺼지는 이 상태가 이 스킬이 푸는 문제다.

패턴 목록은 저장소 밖에 둔다. **패턴 파일에 든 값을 읽어서 답, 커밋, 문서에 옮겨 적지 마라.** 그 값들이
바로 가드가 기록에 남지 않게 하려는 것이다. 개수와 파일 경로만 보고한다.

## 필요한 것

`git` 과 `bash` 만 있으면 된다. Windows 에서는 Git Bash 를 뜻하고, 둘 다 없으면 그 사실을 알리고 멈춘다.
나머지(Node, 패키지 매니저, 특정 호스트)는 선택이다. 모노레포라면 훅은 루트에만 놓인다. git 에는 패키지별
훅 경로가 없다.

## 팀 저장소일 때

혼자 쓰는 저장소와 팀 저장소는 **고쳐도 되는 것이 다르다.** 팀 저장소에서는 2·6·7단계가 **남들이 함께 쓰는
자산**을 건드린다. 그 세 단계는 **실행하지 말고 무엇을 하면 좋을지 제안만 하고, 사람이 팀과 합의하게 한다.**

| 단계 | 건드리는 것 | 팀 저장소에서 |
|---|---|---|
| 2 | `.gitignore` | 제안만. 팀 관례에 개인 폴더 이름을 혼자 넣지 않는다 |
| 6 | `CLAUDE.md`·`CONTRIBUTING.md` | 제안만. 팀 규칙 문서다 |
| 7 | 저장소 보안 설정(`gh api -X PATCH`) | **절대 실행하지 않는다.** 조직 정책이고 관리자 권한이 필요하다 |

1·3·4·5단계는 그대로 해도 된다. 훅 파일과 `setup.sh` 는 새 파일이고, `core.hooksPath` 는 내 `.git/config`
에만 쓰이므로 남에게 영향이 없다. 다만 그 두 파일을 **커밋할지는 팀에 물어야 한다.** 커밋하지 않고
자기 작업 트리에만 두어도 가드는 동작한다.

**패턴을 어디에 적을지가 특히 중요하다.** 공용 파일 `~/.config/git-guard/patterns` 는 이 기계의 **모든
저장소에 함께 적용된다.**

| 두는 곳 | 커밋되나 | 팀에 전달되나 | 무엇을 적나 |
|---|---|---|---|
| `.githooks/team-patterns` | **된다** | **된다** | 사내 도메인, 고객사 이름처럼 팀이 함께 막아야 하고 그 저장소 안에서는 이미 알려진 값 |
| `~/.config/git-guard/patterns` | 안 됨 | 안 됨 | 내 개인 패턴. 이 기계의 모든 저장소에 적용된다 |
| `.private/guard-patterns` | 안 됨 | 안 됨 | 그 저장소에만 해당하고 남에게 보일 수 없는 값 |

- **회사에 속한 패턴은 `.githooks/team-patterns` 에 적는다.** 이 파일만 커밋되므로 팀원 전부에게 전달된다.
  개인 공용 파일에 넣으면 개인 저장소 작업에도 따라다니고, `.private/` 에 넣으면 팀원에게 가지 않는다.
- **`team-patterns` 에 자격증명은 절대 넣지 않는다.** 커밋되는 파일이고, 저장소가 공개로 바뀌면 그 목록도
  공개된다. 도메인이나 이름 같은 식별자만 적는다.
- 개인 공용 파일에 든 패턴이 회사 저장소 커밋을 막을 수 있다. 영문 모를 차단이 나면 이쪽을 먼저 본다.

## 단계

순서대로 한다. 5단계를 건너뛰지 않는다. 팀 저장소라면 2·6·7단계는 제안으로 바꾼다.

1. **손대기 전에 저장소를 살핀다.** 넷을 모두 실측한다. 어느 것도 추측하지 않는다.
   `repo-setup` 이 이 스킬을 부르면서 실측값을 넘겨줬으면 **다시 재지 않는다.** 받은 값을 그대로 쓰고
   무엇을 받아 썼는지 보고에 적는다. 단독으로 불렸으면 여기서 직접 잰다.
   - `git rev-parse --show-toplevel` 로 git 저장소인지 본다. 아니면 멈춘다.
   - `git config core.hooksPath` 를 읽는다. **이미 다른 값이 있으면 다른 훅 관리자가 잡고 있는 것이다.**
     이 설정은 값을 하나만 가지므로 덮으면 그쪽 훅이 조용히 죽는다. 그때는 4b 로 간다.
   - `git remote -v` 로 호스트를 본다. GitHub, GitLab, Bitbucket, 또는 없음. 7단계가 여기서 갈린다.
   - GitHub 원격이 있으면 한 번에 본다.

     ```bash
     gh repo view --json owner,viewerPermission,visibility,isInOrganization \
       --jq '{owner: .owner.login, perm: .viewerPermission, visibility, org: .isInOrganization}'
     gh api user --jq '.login'
     ```

     공개면 홈 경로와 이메일이 실제 위험이고, 비공개면 우선순위가 자격증명 쪽으로 옮겨 간다.
     **`org` 가 `true` 이거나 `owner` 가 내 로그인과 다르거나 `perm` 이 `ADMIN` 이 아니면 팀 저장소다.**
     그러면 아래 「팀 저장소일 때」를 따른다. 원격이 없거나 GitHub 이 아니어서 판별이 안 되면 **팀 저장소로
     간주한다.** 모르는 쪽에서 안전한 선택이다.

2. **무시 규칙을 먼저 넣는다.**(팀 저장소면 제안만) 대상 저장소의 `.gitignore` 에 `.private/` 가 있는지 확인하고 없으면 넣는다.
   패턴 파일을 만들기 **전에** 해야 한다. 이 줄이 없으면 패턴 파일이 커밋 대상으로 잡힌다.

3. **파일 둘을 복사한다.** 이 스킬 폴더의 `templates/pre-commit` 을 대상 저장소의
   `.githooks/pre-commit` 으로, `templates/setup.sh` 를 저장소 루트의 `setup.sh` 로 복사한다.
   **내용을 새로 쓰지 않는다.** 복사한 뒤 실행 비트를 확인한다. 그 저장소에만 있는 내부 문서
   폴더가 있으면 훅의 `case` 문에 덧붙인다. 없으면 기본값 `.private/*` 그대로 둔다.

4. **켠다.** 길이 둘이고, 1단계가 어느 쪽인지 알려 준다.

   **4a. `core.hooksPath` 를 아무도 잡고 있지 않다.** `./setup.sh` 를 돌린다. 이 기계의 첫 저장소라면
   `./setup.sh --init-patterns` 를 돌리고, 만들어진 `~/.config/git-guard/patterns` 를 **사람이 직접 채우게
   한다.** 그 파일의 내용은 절대 대신 쓰지 않는다. 무엇이 민감한지는 사람만 안다. 두 번째 저장소부터는
   공용 목록이 이미 있으므로 `./setup.sh` 만 돌리면 된다.

   **4b. 다른 관리자가 잡고 있다**(husky, lefthook, pre-commit, simple-git-hooks). `--force` 를 **쓰지 말고**,
   `core.hooksPath` 를 손으로 고치지도 않는다. 그쪽 관리자의 `pre-commit` 에 한 줄을 넣어 둘 다 돌게 한다.

   ```bash
   "$(git rev-parse --show-toplevel)"/.githooks/pre-commit || exit 1
   ```

   husky 라면 그 파일은 `.husky/pre-commit` 이고, lefthook 이라면 `lefthook.yml` 의 명령 항목이다. 이 길로
   갔다는 사실과 이유를 보고에 적는다. `--force` 는 기존 관리자를 버리기로 사람이 정했을 때만 쓴다.

5. **막히는지 증명한다.** 설정을 걸었다고 적용된 것이 아니다. 가드가 잡아야 할 패턴으로 탐침 파일을 만들어
   스테이징하고 실제로 커밋을 시도한다. **패턴 값이 대화 기록에 남지 않도록 출력은 버리고 종료 코드만 본다.**

   ```bash
   probe=$(grep -vE '^[[:space:]]*(#|$)' "${GIT_GUARD_PATTERNS:-${XDG_CONFIG_HOME:-$HOME/.config}/git-guard/patterns}" | head -1 | tr -d '\\')
   printf 'x %s y\n' "$probe" > guard-probe.txt && git add guard-probe.txt
   if git commit -q -m probe >/dev/null 2>&1; then echo "실패: 가드가 막지 않았다"; else echo "정상: 막혔다"; fi
   git reset -q HEAD -- guard-probe.txt; rm -f guard-probe.txt
   ```

   커밋이 성공하면 가드는 꺼진 것이다. 왜인지 알아내기 전에는 성공했다고 보고하지 않는다.

6. **에이전트에게 알린다.**(팀 저장소면 제안만) 그 저장소의 `CLAUDE.md`·`AGENTS.md`·`CONTRIBUTING.md` 의 개발 환경 절 첫 줄에
   `./setup.sh` 를 넣고, `--no-verify` 가 에이전트의 탈출구가 아니라는 것을 명시한다. 규칙 파일에 없는
   규칙은 서브에이전트에게 존재하지 않는 규칙이다.

7. **호스트에 서버 층이 있으면 켠다.**(팀 저장소면 실행하지 않는다) 로컬 훅은 홈 경로와 사내 도메인을 잡는 **유일한** 층이고, 4단계를
   돌리지 않은 곳에서는 꺼져 있다. 로컬에서 끌 수 없는 것을 더한다. 명령은 호스트마다 다르므로 1단계에서
   확인한 것을 쓴다.
   - **GitHub**: `gh api -X PATCH repos/OWNER/REPO -F 'security_and_analysis[secret_scanning][status]=enabled'`
     와 `secret_scanning_push_protection` 도 같은 방식으로. CodeQL 지원 언어가 있으면 분석을 붙이고,
     워크플로 YAML 도 보도록 `actions` 를 함께 넣는다.
   - **GitLab**: Secret Detection 은 저장소 설정이 아니라 CI 템플릿이다. `.gitlab-ci.yml` 에 추가한다.
   - **Bitbucket·자체 호스팅·원격 없음**: 대응하는 기능이 없을 수 있다. **있는 척하지 말고 없다고 적는다.**
     그러면 로컬 훅이 유일한 층이 되므로 5단계가 더 중요해진다.

## 보고

근거와 함께 적는다. 어떤 파일을 만들었는지, `core.hooksPath` 가 되읽혔는지, 각 패턴 출처에 몇 줄이 있는지
(**개수만. 값은 절대 적지 않는다**), 그리고 5단계의 종료 코드다. 끝내지 못한 단계가 있으면 어느 것이고
왜인지 적는다. **5단계 결과 없이는 설치됐다고 보고하지 않는다.** 팀 저장소로 판별했으면 그 사실과 근거(`org`·`owner`·`perm` 값)를 적고, 실행하지 않고 제안만 한 단계가 무엇인지 분명히 밝힌다.

## 템플릿

이 스킬 폴더 안에 실제 파일로 있다. **본문에 옮겨 적지 않는다.** 정본이 둘이 되면 한쪽이 낡는다.

| 파일 | 대상 저장소의 어디로 |
|---|---|
| `templates/pre-commit` | `.githooks/pre-commit` |
| `templates/setup.sh` | 저장소 루트의 `setup.sh` |

스킬이 깔릴 때 폴더가 통째로 복사되고 실행 비트도 보존된다. 복사한 뒤 `chmod +x` 가 필요하면
그 자리에서 채운다. 두 파일의 머리 주석에 무엇을 왜 하는지가 적혀 있으므로, 고치기 전에 읽는다.
