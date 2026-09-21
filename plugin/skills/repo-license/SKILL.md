---
name: repo-license
description: Decide and declare a repository's license consistently. Checks for an existing LICENSE file and the license field in every manifest, and when they disagree or are missing, fetches the canonical text and makes the declarations agree, verifying the result with a bundled checker. It never picks a license on the user's behalf, because that is a legal decision. 저장소의 라이선스를 정하고 일관되게 박는다. LICENSE 파일과 매니페스트의 license 필드를 대조하고, 어긋나거나 없으면 전문을 받아 맞춘 뒤 검사기로 확인한다. 라이선스는 법적 결정이라 대신 고르지 않는다. "라이선스 넣어줘", "공개 저장소 라이선스", "LICENSE 가 없다" 같은 요청에 쓴다.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
---

# 라이선스

$ARGUMENTS 저장소의 라이선스를 정하고 박는다(기본값은 현재 저장소).

윗줄에 달러 기호가 붙은 대문자 자리표시자가 그대로 보이면, 인자를 넘기지 않는 환경이다.
그때는 현재 저장소를 대상으로 삼는다.

내가 쓰는 언어로 답한다.

## 왜 필요한가

**라이선스가 없는 공개 저장소는 「아무도 쓸 수 없는 공개 저장소」다.** 명시하지 않으면 기본값은
저작권 전부 보유이고, 코드가 보인다는 것과 쓸 수 있다는 것은 다르다. 공개해 둔 의도와 정반대의
상태가 조용히 유지된다.

**선언이 한 곳에 있지 않다.** `LICENSE` 파일과 `package.json`·`pyproject.toml`·`Cargo.toml` 의
`license` 필드가 따로 있고, 하나만 고치면 나머지가 낡는다. 어긋나도 아무것도 깨지지 않으므로
사람이 알아채지 못한다.

## 이 스킬이 하지 않는 것

- **대신 고르지 않는다.** 라이선스는 법적 결정이다. 선택지와 차이를 보이고 사람이 정한다.
- **법률 자문을 하지 않는다.** 아래 요약은 고르기 위한 참고이지 의견이 아니다.
- **저작권자와 연도를 추측하지 않는다.** 사람에게 확인받는다.
- **이미 있는 `LICENSE` 를 덮지 않는다.** 바꾸는 것은 배포된 판에 영향을 주므로 사람이 정한다.
- 전문을 손으로 옮겨 적지 않는다. 한 글자만 달라져도 그 라이선스가 아니게 된다.

## 팀 저장소일 때

라이선스는 회사의 결정이지 개인의 결정이 아니다. **파일을 만들지 말고 현재 상태와 어긋난 곳만
보고한다.** `check-license.sh` 를 돌려 대조하는 것까지는 해도 된다. 읽기만 하기 때문이다.

## 단계

1. **실측한다.** `repo-setup` 이 실측값을 넘겨줬으면 다시 재지 않는다. 받은 값을 쓰고 무엇을 받아
   썼는지 보고에 적는다.

   ```bash
   ls LICENSE LICENSE.md LICENSE.txt COPYING 2>/dev/null
   find . -maxdepth 3 \( -name .git -o -name node_modules \) -prune -o -type f \
     \( -name package.json -o -name pyproject.toml -o -name Cargo.toml \
        -o -name plugin.json -o -name marketplace.json \) -print
   ```

   매니페스트는 루트에만 있지 않다. 두 층 플러그인 저장소는 한 단계 아래에 둔다.

2. **이미 있으면 대조만 한다.** 이 스킬 폴더의 `templates/check-license.sh` 를 저장소 루트에서
   돌린다. 종료 코드가 0 이면 여기서 끝이고, 그 사실을 보고한다.

   ```bash
   bash templates/check-license.sh; echo "종료 코드 $?"
   ```

   **1 이면 고치지 말고 먼저 묻는다.** 파일이 맞는지 매니페스트가 맞는지는 사람만 안다. 둘 중
   어느 쪽으로 맞출지 확정받은 뒤에 고친다.

3. **없으면 고르게 한다.** 아래를 보이고 사람이 정한다. **추천을 한 줄 붙이되 대신 정하지 않는다.**

   | 식별자 | 한 줄 | 언제 고르나 |
   |---|---|---|
   | `MIT` | 짧고 제약이 거의 없다. 저작권 표시만 남기면 된다 | 널리 쓰이길 바라고 조건을 따지고 싶지 않을 때 |
   | `Apache-2.0` | MIT 에 특허 조항과 기여자 조건을 더한 것 | 회사가 쓸 가능성이 있거나 특허 위험을 줄이고 싶을 때 |
   | `BSD-3-Clause` | MIT 에 이름을 홍보에 쓰지 말라는 조항을 더한 것 | 내 이름이나 조직명이 마케팅에 쓰이는 것을 막고 싶을 때 |
   | `GPL-3.0` | 고쳐서 배포하면 같은 조건으로 공개해야 한다 | 파생물도 공개로 남기를 바랄 때 |
   | 없음 | 저작권 전부 보유. 남이 쓸 수 없다 | 비공개이거나 아직 정하지 않았을 때 |

   「없음」을 골랐고 저장소가 공개라면, **그 상태가 뜻하는 바를 한 줄로 알리고 넘어간다.**
   모르고 그 상태에 있는 것과 알고 그 상태에 있는 것은 다르다.

4. **전문을 받는다.** 손으로 적지 않는다.

   ```bash
   gh api /licenses/mit --jq '.body' > LICENSE
   # gh 가 없으면
   curl -fsSL https://api.github.com/licenses/mit | python3 -c 'import json,sys;sys.stdout.write(json.load(sys.stdin)["body"])' > LICENSE
   ```

   `/licenses` 로 받을 수 있는 목록을 볼 수 있고, 인증 없이도 된다(2026-09-22 확인).

5. **저작권자와 연도를 채운다.** 전문에 `[year]`·`[fullname]` 자리가 있으면 **사람에게 확인받아**
   채운다. 사용자 이름이나 git 설정에서 가져와 임의로 넣지 않는다.

   **이름과 이메일은 개인 정보다.** 이 저장소에 `repo-privacy` 가드가 깔려 있고 개인 패턴 목록에
   그 값이 들어 있으면 커밋이 막힌다. 막히면 가드를 끄지 말고, 어떤 이름으로 공개할지 사람에게
   다시 묻는다.

6. **매니페스트를 맞춘다.** 있는 매니페스트마다 `license` 필드를 4단계에서 정한 SPDX 식별자로
   맞춘다. 필드가 없으면 더한다. **매니페스트의 다른 값은 건드리지 않는다.**

7. **검증한다.** 다시 돌려 종료 코드가 0 인지 본다. **이 결과 없이 끝났다고 보고하지 않는다.**

   ```bash
   bash templates/check-license.sh; echo "종료 코드 $?"
   ```

## 아는 한계

- `check-license.sh` 는 `pyproject.toml` 의 `license = {text = "MIT"}` 형태를 읽지 못하고
  건너뛴다. 그 저장소에서는 눈으로 대조하고 그 사실을 보고에 적는다.
- 매니페스트는 세 단계까지만 찾는다. 더 깊은 곳에 있으면 눈으로 대조한다.
- 알아보는 라이선스는 열두 가지다. 그 밖의 본문에는 **이름을 붙이지 않고 알아보지 못했다고 한다.**
  틀린 이름이 붙으면 아무도 다시 보지 않는다.

## 템플릿

| 파일 | 하는 일 |
|---|---|
| `templates/check-license.sh` | `LICENSE` 본문과 매니페스트의 `license` 필드가 같은지 본다. 0 맞음 · 1 어긋남 · 2 git 저장소 아님 |

## 보고

무엇을 근거로 무엇을 했는지 적는다.

- **실측값** — 있던 `LICENSE` 와 매니페스트의 `license` 값. 진입점에서 받아 쓴 것이 있으면 그 사실.
- **사람이 고른 것** — 어떤 식별자를 왜 골랐는지. 고르지 않고 남겨 뒀으면 그 사실.
- **7단계의 종료 코드.** 이것이 없으면 끝났다고 적지 않는다.
- **하지 않은 것과 이유** — 팀 저장소라 제안만 했다면 그 사실과 근거.
