# 저장소 보안 층

대상 저장소의 보안 층을 켠다.

## 카드

진입점이 목적을 고르기 전에 이 카드를 보인다. `{…}` 는 진입점이 1단계에서 잰 값으로 채운다.

```text
호스트 보안 층 (secure)
1. 무엇: GitHub 이 비밀 형식(API 키 등)을 찾는 secret scanning 과 그런 푸시를 거절하는 push
   protection 을 켜고, 의존성 판올림(dependabot)과 코드 스캐닝(CodeQL)을 붙이고, 액션을 SHA 로 고정한다.
2. 이유: 이 저장소는 {공개 여부}이고, 켜진 보안 기능은 {security_and_analysis}, 기존 워크플로는 {워크플로 수}개다.
3. 바뀌는 것: GitHub 설정 secret scanning·push protection 이 enabled 가 된다. PR 과 무관하게 확인을
   받는 즉시 적용된다. 새 파일 .github/dependabot.yml 과 .github/workflows/codeql.yml, 기존 워크플로의
   uses: 를 SHA 로 고치는 변경(별도 커밋). 다른 사람: 비밀 형식이 든 푸시는 누구의 것이든 거절된다.
4. 겪는 일: dependabot 이 매주 의존성을 보고 올릴 판이 있으면 PR 을 연다. CodeQL 이 기본 브랜치
   푸시와 PR 마다, 그리고 매주 한 번 돈다.
5. 감수할 것: 비공개 저장소의 코드 스캐닝에는 GitHub Code Security 라이선스가 필요하다. 비밀이 아닌
   문자열이 비밀 형식으로 보여 푸시가 거절될 수 있다.
6. 되돌리기: 설정은 절차 2단계와 같은 API 에 disabled 를 보낸다. 파일과 SHA 고정은 되돌리는 PR 로 되돌린다.
7. 건너뛰면: 이미 푸시된 비밀과 --no-verify 로 넘긴 커밋을 잡는 층이 없고, 액션 태그가 다른 코드로
   옮겨져도 알 수 없다.
```

## 왜 필요한가

**커밋 훅은 커밋 시점만 본다.** 이미 푸시된 것, 남이 자기 기계에서 푸시한 것, `--no-verify` 로
넘긴 것은 로컬 훅이 손댈 수 없다. 호스트 층은 그 셋을 모두 본다. 두 층은 서로를 대체하지 않는다.

**액션은 남의 코드를 내 자격증명과 함께 돌린다.** 태그는 옮길 수 있어서 같은 `@v5` 가 어제와 다른
코드를 가리킬 수 있고, **그 사실이 diff 에 남지 않는다.** 40자 SHA 로 고정하면 바뀔 때 diff 에
드러난다.

**토큰 권한은 적지 않으면 저장소 기본값을 따라간다.** 읽기만 하면 되는 작업에 쓰기가 붙어 있고,
평소에는 아무 일도 없다가 한 번 잘못 돌 때 무엇이든 할 수 있다.

## 이 목적이 하지 않는 것

- **테스트 워크플로를 만들지 않는다.** `ci` 목적이 만든다. 이 목적은 이미 있는 워크플로의
  액션 고정과 권한만 고친다.
- **브랜치 보호를 걸지 않는다.** `contrib` 목적이 맡는다.
- **권한이 없으면 억지로 하지 않는다.** 실패를 결함으로 보고하지 않고 제안으로 바꾼다.
- **설정을 건 것으로 끝내지 않는다.** 되읽어 값이 바뀌었는지 본다.

## 팀 저장소일 때

호스트 설정은 저장소 관리자만 바꿀 수 있고, 바꾸면 팀 전체에 영향을 준다. **읽어서 현재 상태를
보고하고 무엇이 빠졌는지만 알린다.** 파일(`dependabot.yml`, `codeql.yml`)은 만들어 풀 리퀘스트로
올리는 것까지 하고 병합은 팀이 정한다.

## 단계

1. **실측한다.** 진입점이 이미 잰 값이 있으면 다시 재지 않는다.

   ```bash
   gh api repos/OWNER/REPO --jq '.security_and_analysis'   # 지금 켜진 것
   gh api repos/OWNER/REPO/languages                        # 어떤 언어가 있나
   ls .github/workflows/ 2>/dev/null                        # 이미 있는 워크플로
   ```

2. **secret scanning 과 push protection 을 켠다.** 켠 뒤 **반드시 되읽는다.**

   ```bash
   gh api -X PATCH repos/OWNER/REPO \
     -F 'security_and_analysis[secret_scanning][status]=enabled' \
     -F 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
   gh api repos/OWNER/REPO --jq '.security_and_analysis'
   ```

   **호출이 200 을 돌려줘도 값이 안 바뀌는 항목이 있다.** 실측으로 겪었다.
   `secret_scanning_non_provider_patterns` 는 `HTTP 200` 을 받고도 `disabled` 로 남았고, 원인을
   확인하지 못했다. **되읽어서 안 바뀌었으면 바뀌었다고 적지 말고, 그 사실과 웹 설정 화면에서
   확인해야 한다는 것을 보고한다.**

3. **의존성 판올림을 켠다.** 스킬 폴더의 `secure/templates/dependabot.yml` 을
   `.github/dependabot.yml` 로 복사하고, **그 저장소에 실제로 있는 생태계만 남긴다.** 없는 것을
   적으면 dependabot 이 조용히 아무것도 하지 않는데, 켜 둔 줄 알고 넘어가게 된다.

4. **코드 스캐닝을 붙인다.** 1단계의 언어 목록에서 CodeQL 이 지원하는 것만 고른다. 워크플로가
   하나라도 있으면 **`actions` 를 함께 넣는다.** 워크플로 YAML 자체가 분석 대상이 된다.
   `secure/templates/codeql.yml` 을 복사하고 자리표시자를 바꾼다.

5. **액션을 SHA 로 고정한다.** `ci` 목적이 놓은 것을 포함해 모든 워크플로가 대상이다.

   ```bash
   gh api repos/actions/checkout/commits/v5 --jq '.sha'
   ```

   주석 달린 태그에도 동작한다(2026-09-22 확인). **옆에 어느 태그였는지 주석으로 남긴다.** 숫자만
   남으면 나중에 아무도 읽지 못한다. `github/codeql-action` 의 `init` 과 `analyze` 는 **같은 SHA**
   여야 한다. 따로 올라가면 분석이 깨진다.

6. **검증한다.** 눈으로 훑지 않는다.

   ```bash
   bash "<스킬 폴더>/secure/scripts/check-workflow-security.sh"; echo "종료 코드 $?"
   ```

   0 이 아니면 무엇이 남았는지 그대로 보고한다. **이 결과 없이 끝났다고 적지 않는다.**

## 아는 한계

- 이 검사기는 최상위 `permissions` 가 있는지와 `write-all` 인지만 본다. 작업별 권한이 과한지는
  보지 않는다. 사람이 읽어야 한다.
- 호스트가 GitHub 이 아니면 2·4단계에 대응하는 기능이 없을 수 있다. **있는 척하지 말고 없다고
  적는다.** 그러면 커밋 훅이 유일한 층이 되므로 `privacy` 목적의 증명 단계가 더 중요해진다.

## 템플릿

| 파일 | 하는 일 |
|---|---|
| `secure/scripts/check-workflow-security.sh` | 액션 고정과 토큰 권한을 본다. 0 문제 없음 · 1 문제 있음 · 2 git 저장소 아님 |
| `secure/templates/dependabot.yml` | 의존성 판올림 골격. 해당하는 생태계만 남긴다 |
| `secure/templates/codeql.yml` | 코드 스캐닝 골격. 자리표시자 넷을 실측값으로 바꾼다 |

## 보고

- **1단계 실측값** — 켜기 전에 무엇이 켜져 있었는지.
- **되읽은 값** — 2단계에서 건 것마다 실제로 바뀐 값. **바뀌지 않은 것이 있으면 그 사실.**
- **6단계 종료 코드.** 이것이 없으면 끝났다고 적지 않는다.
- **하지 않은 것과 이유** — 권한이 없어 제안만 했다면 그 근거. 호스트에 없는 기능이면 그 사실.
