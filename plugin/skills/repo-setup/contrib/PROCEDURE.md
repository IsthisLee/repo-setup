# 협업 준비

대상 저장소를 남이 들어올 수 있게 연다.

## 왜 필요한가

**취약점이 공개 이슈로 올라온다.** 신고처가 적혀 있지 않으면 사람은 보이는 곳에 적는다. 그
순간부터 고치기 전까지 누구나 볼 수 있다.

**기여 안내가 없으면 기여가 오지 않거나, 와서 되돌아간다.** 무엇을 돌려야 하고 커밋을 어떻게
쓰는지는 저장소마다 다른데, 그것을 적어 두지 않으면 사람마다 다르게 하고 리뷰에서 매번 같은 말을
반복하게 된다.

**기본 브랜치가 열려 있으면 실수로 직접 푸시된다.** 검사를 붙여 놨어도 우회된다.

## 이 목적이 하지 않는 것

- **해당하지 않는 저장소에 넣지 않는다.** 혼자 쓰는 비공개 실험에 CODEOWNERS 를 넣을 일이 없다.
- **이미 있는 문서를 덮지 않는다.** 남이 쓴 안내를 조용히 갈아 끼우지 않는다. 대조해서 차이만 알린다.
- **CODEOWNERS 에 사람이나 팀 이름을 추측해 넣지 않는다.** 틀리면 엉뚱한 사람에게 리뷰가 간다.
- **팀 저장소에서 보호 규칙을 직접 걸지 않는다.** 모두의 작업 방식을 바꾸는 일이다.

## 팀 저장소일 때

**현재 상태를 읽어 무엇이 빠졌는지만 보고한다.** 문서는 만들어 풀 리퀘스트로 올리는 것까지 하고,
병합과 보호 규칙은 팀이 정한다. `check-contrib.sh` 는 읽기만 하므로 그대로 돌려도 된다.

## 단계

1. **실측한다.** 진입점이 이미 잰 값이 있으면 다시 재지 않는다.

   ```bash
   bash "<스킬 폴더>/contrib/scripts/check-contrib.sh"                       # 무엇이 이미 있나
   gh api repos/OWNER/REPO/branches/BRANCH/protection     # 보호 규칙. 404 면 안 걸린 것
   gh api repos/OWNER/REPO/rulesets                       # 규칙셋 쪽을 쓰는 저장소도 있다
   ```

   GitHub 은 이 파일들을 한 곳에서만 찾지 않는다. 루트와 `.github/` 를 모두 보고 CODEOWNERS 는
   `docs/` 까지 본다. **한 곳만 보고 없다고 판단해 덮으면 남이 쓴 문서가 사라진다.**

2. **해당하는 것만 고른다.**

   | 항목 | 언제 넣나 | 언제 빼나 |
   |---|---|---|
   | `SECURITY.md` | 공개 저장소라면 사실상 항상 | 비공개 개인 실험 |
   | `CONTRIBUTING` | 남이 PR 을 보낼 수 있을 때 | 혼자 쓰는 저장소 |
   | 이슈·PR 서식 | 남이 이슈를 올릴 때 | 이슈를 꺼 둔 저장소 |
   | `CODEOWNERS` | 리뷰 담당을 나눌 사람이 둘 이상일 때 | 혼자 쓰는 저장소 |
   | 브랜치 보호 | 기본 브랜치에 직접 푸시를 막고 싶을 때 | 혼자 쓰고 직접 푸시가 편한 저장소 |

   **뺀 것과 이유를 반드시 보고한다.** 넣지 않기로 한 것도 결정이다.

3. **골격을 놓고 자리표시자를 채운다.** 자리표시자는 **실측값이나 사람에게 물은 값**으로만 채운다.
   비워 두면 거짓 안내가 남는다.

   | 자리표시자 | 무엇으로 |
   |---|---|
   | `__SETUP_COMMAND__` | 그 저장소의 설치 명령. `privacy` 목적을 적용했으면 `script/setup` |
   | `__TEST_COMMAND__` | `ci` 목적의 실측기가 알려 준 명령 |
   | `__COMMIT_CONVENTION__` | 그 저장소의 커밋 규칙. 없으면 사람에게 묻는다 |
   | `__CONTACT__` | 취약점 신고처. **추측하지 않는다.** 사람에게 묻는다 |
   | `__SUPPORTED__` | 지원하는 판. 모르면 「최신 판만 지원합니다」로 두되 사람에게 확인받는다 |
   | `__DEFAULT_OWNER__` | 리뷰 담당. **추측하지 않는다** |

4. **기본 브랜치를 보호한다.** 혼자 쓰는 저장소와 팀 저장소의 답이 다르다.

   - **혼자 쓰는 저장소**: 검사 통과만 요구하고 리뷰 승인은 요구하지 않는다. 승인을 요구하면
     자기 PR 을 자기가 병합할 수 없어 막힌다.
   - **팀 저장소**: 직접 걸지 않고 무엇을 걸면 좋을지 제안한다.

   ```bash
   gh api -X PUT repos/OWNER/REPO/branches/BRANCH/protection --input - <<'JSON'
   {
     "required_status_checks": { "strict": true, "contexts": ["test"] },
     "enforce_admins": false,
     "required_pull_request_reviews": null,
     "restrictions": null
   }
   JSON
   ```

   `contexts` 에는 `ci` 목적이 만든 작업 이름을 넣는다. **없는 이름을 넣으면 영원히 통과하지
   않는다.** CI 가 없으면 이 항목을 비우고, 그 사실을 보고한다.

   **이 호출을 실제로 돌려 본 적은 없다.** 읽기 호출이 닿는 것만 확인했다(`Branch not protected`
   404, `rulesets` 는 빈 목록). 그러므로 **건 뒤에 반드시 되읽어 확인한다.**

5. **검증한다.**

   ```bash
   bash "<스킬 폴더>/contrib/scripts/check-contrib.sh" <2단계에서 고른 항목들>
   gh api repos/OWNER/REPO/branches/BRANCH/protection --jq '{checks: .required_status_checks, admins: .enforce_admins}'
   ```

   **이 결과 없이 끝났다고 보고하지 않는다.**

## 템플릿

| 파일 | 하는 일 |
|---|---|
| `contrib/scripts/check-contrib.sh` | GitHub 이 보는 자리를 모두 훑어 무엇이 있는지 본다. 항목 이름을 인자로 주면 그것만 본다 |
| `contrib/templates/CONTRIBUTING.md` | 기여 안내 골격. 자리표시자 셋 |
| `contrib/templates/SECURITY.md` | 취약점 신고 골격. 자리표시자 둘 |
| `contrib/templates/pull_request_template.md` | PR 서식. 왜·무엇·근거·확인하지 못한 것 |
| `contrib/templates/ISSUE_TEMPLATE/bug_report.md` | 버그 신고 서식 |
| `contrib/templates/CODEOWNERS` | 리뷰 담당 골격. 자리표시자 하나 |

## 보고

- **1단계 실측값** — 이미 있던 것과 보호 규칙의 현재 상태.
- **넣은 것과 뺀 것** — 뺀 것은 이유와 함께. 이 칸이 비어 있으면 안 된다.
- **채우지 못한 자리표시자** — 사람에게 물어야 하는 값이 남아 있으면 무엇인지.
- **5단계 결과.** 이것이 없으면 끝났다고 적지 않는다.
