---
name: repo-ci
description: Set up a test workflow that actually runs on every push and pull request, and prove it by watching one real run finish green. It measures the repository's own test command first and refuses to create a workflow when there is none, because an empty CI reports success while checking nothing. 푸시와 풀 리퀘스트마다 테스트가 자동으로 도는 워크플로를 놓고, 실제로 한 번 돌려 통과를 확인한다. 저장소의 테스트 명령을 먼저 실측하고, 테스트가 없으면 워크플로를 만들지 않는다. "CI 붙여줘", "테스트 자동으로 돌게", "GitHub Actions 세팅" 같은 요청에 쓴다.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
---

# 테스트 워크플로

$ARGUMENTS 저장소에 테스트 워크플로를 놓는다(기본값은 현재 저장소).

윗줄에 달러 기호가 붙은 대문자 자리표시자가 그대로 보이면, 인자를 넘기지 않는 환경이다.
그때는 현재 저장소를 대상으로 삼는다.

내가 쓰는 언어로 답한다.

## 왜 필요한가

**로컬에서만 도는 테스트는 잊힌다.** 돌리는 사람과 돌리지 않는 사람이 갈리고, 깨진 채로 병합된
뒤에야 드러난다. 자동으로 도는 자리는 푸시와 풀 리퀘스트다.

**빈 CI 는 있는 것보다 나쁘다.** 아무것도 검사하지 않으면서 초록 표시를 준다. 그 표시를 브랜치
보호의 필수 검사로 걸면 보호가 껍데기가 되고, 사람은 보호가 있다고 믿는다.

## 이 스킬이 하지 않는 것

- **테스트가 없으면 워크플로를 만들지 않는다.** 테스트를 쓰는 것이 먼저다. 그 사실을 보고한다.
- **기존 워크플로를 덮지 않는다.** 남이 돌리고 있는 것을 조용히 바꾸면 무엇이 달라졌는지 아무도
  모른다. 대조해서 차이만 알린다.
- **돌려 보지 않은 운영체제나 버전을 매트릭스에 넣지 않는다.** 매트릭스는 희망이 아니라 실측이다.
- **액션을 SHA 로 고정하지 않는다.** 그것은 `repo-secure` 가 맡는다. 이 스킬만 돌렸으면 **액션이
  고정되지 않은 상태라는 사실을 보고에 적는다.**

## 팀 저장소일 때

워크플로 파일은 공유 자산이다. **기본 브랜치에 직접 넣지 않는다.** 파일을 만들어 풀 리퀘스트로
올리는 것까지만 하고, 병합은 팀이 정한다. 실측과 대조는 읽기만 하므로 그대로 해도 된다.

## 단계

1. **실측한다.** `repo-setup` 이 넘겨준 값이 있으면 다시 재지 않는다.

   ```bash
   bash templates/find-test-command.sh          # 표준 출력이 명령, 표준 오류가 근거
   git symbolic-ref --short HEAD                # 기본 브랜치
   ls .github/workflows/ 2>/dev/null            # 이미 있는 것
   ```

2. **테스트 명령이 없으면 여기서 멈춘다.** 실측기가 1로 끝났다는 뜻이다. **워크플로를 지어내지
   않는다.** 무엇을 찾아봤고 왜 없다고 판단했는지 적고, 테스트를 먼저 쓰라고 알린다.

3. **이미 워크플로가 있으면 덮지 않는다.** 그 파일이 무엇을 언제 돌리는지 읽고, 지금 실측한
   테스트 명령과 어긋나는 곳만 알린다. 고칠지는 사람이 정한다.

4. **골격을 놓는다.** 이 스킬 폴더의 `templates/tests.yml` 을 `.github/workflows/tests.yml` 로
   복사하고 자리표시자를 1단계의 실측값으로 바꾼다.

   | 자리표시자 | 무엇으로 |
   |---|---|
   | `__DEFAULT_BRANCH__` | `git symbolic-ref` 가 알려 준 이름. `main` 이라고 단정하지 않는다 |
   | `__TEST_COMMAND__` | 실측기가 알려 준 명령 그대로 |
   | `__SETUP_STEPS__` | 언어별 준비 단계. 필요 없으면 그 줄을 통째로 지운다 |

5. **준비 단계를 채운다.** 테스트 명령이 도구를 요구하면 그 설치 단계를 넣는다. Node 라면
   `actions/setup-node`, Python 이라면 `actions/setup-python` 이다. **버전은 저장소가 실제로 쓰는
   것을 실측해 넣는다**(`.nvmrc`, `engines`, `python-requires`). 없으면 사람에게 묻는다.

6. **실제로 돌려 통과를 확인한다.** 파일을 놓은 것은 검증이 아니다.

   **푸시는 밖으로 나가는 일이다. 먼저 확인받는다.** 확인을 받았으면 푸시하고 결과를 본다.

   ```bash
   gh run list --workflow tests.yml --limit 1 --json databaseId,status,conclusion
   gh run watch "$(gh run list --workflow tests.yml --limit 1 --jq '.[0].databaseId' --json databaseId)" --exit-status
   ```

   **통과를 보기 전에는 세팅됐다고 보고하지 않는다.** 실패했으면 워크플로가 틀린 것인지 테스트가
   틀린 것인지 가려서 적는다. 둘은 고치는 사람이 다르다.

7. **액션 고정을 넘긴다.** `repo-secure` 가 이 파일의 `uses:` 를 SHA 로 바꾼다. 이 스킬은 하지
   않는다. 단독으로 불렸으면 그 사실을 보고에 적는다.

## 템플릿

| 파일 | 하는 일 |
|---|---|
| `templates/find-test-command.sh` | 테스트 명령을 실측한다. 0 찾음 · 1 못 찾음 · 2 git 저장소 아님 |
| `templates/tests.yml` | 워크플로 골격. 자리표시자 셋을 실측값으로 바꿔 쓴다 |

실측기가 보는 것은 순서대로 `.check.toml` 의 `test_command`, `package.json` 의 `scripts.test`,
`Makefile` 의 `test` 대상, `pyproject.toml` 의 pytest 설정, `Cargo.toml`, `go.mod` 다.
**`npm init` 이 넣는 기본 자리표시자는 테스트로 보지 않는다.**

## 보고

- **실측값** — 고른 테스트 명령과 어느 파일을 보고 골랐는지. 기본 브랜치 이름.
- **6단계의 실행 결과** — 워크플로 실행 번호와 결론. 이것이 없으면 끝났다고 적지 않는다.
- **하지 않은 것과 이유** — 테스트가 없어 멈췄다면 그 사실. 기존 워크플로가 있어 대조만 했다면
  어긋난 곳. 액션이 고정되지 않은 상태라는 사실.
