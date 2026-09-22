# 라이선스 (license)

진입점 `repo-setup` 의 목적 `license` 다. 세팅 절차는 `plugin/skills/repo-setup/license/PROCEDURE.md` 에 있다.

## 하는 일

라이선스를 정하고 `LICENSE` 와 매니페스트가 같은 말을 하게 한다.

라이선스 선언은 두 곳에 흩어진다. `LICENSE` 파일의 본문과 매니페스트의 `license` 필드다. 하나만
고치면 나머지가 낡는데, 어긋나도 아무것도 깨지지 않아서 사람이 알아채지 못한다.

## 동작

**대신 고르지 않는다.** 라이선스는 법적 결정이라 선택지와 차이를 보이고 사람이 정한다. 전문은
손으로 적지 않고 GitHub 라이선스 API 에서 받는다. 저작권자 이름과 연도도 추측하지 않고 묻는다.

함께 실리는 `license/scripts/check-license.sh` 가 선언을 대조한다. `bash` 와 `git` 만 있으면 되고,
종료 코드는 0 맞음, 1 어긋남, 2 git 저장소 아님이다.

## 바꾸는 것

- `LICENSE` 가 없을 때만 새로 만든다. 이미 있으면 덮지 않는다.
- 매니페스트(`package.json`, `pyproject.toml`, `Cargo.toml`, `plugin.json`, `marketplace.json`)의
  `license` 필드를 고른 SPDX 식별자로 맞춘다. 다른 값은 건드리지 않는다.
- 팀 저장소에서는 파일을 만들지 않고 어긋난 곳만 보고한다.

## 한계와 알려진 문제

- 알아보는 라이선스는 열두 가지이고 **그 밖의 본문에는 이름을 붙이지 않는다.** 틀린 이름이 붙으면
  아무도 다시 보지 않기 때문이다.
- 나머지 한계는 스킬 본문의 「아는 한계」 절에 있다.

## 관련 파일

- `plugin/skills/repo-setup/license/PROCEDURE.md`
- `plugin/skills/repo-setup/license/scripts/check-license.sh`
- `tests/license/unit.sh`

## 관련 ADR

- [0003. 겹치는 파일과 설정의 소유를 정한다](../adr/0003-ownership-of-overlapping-files.md)
- [0005. 팀 저장소의 공유 자산은 제안만 한다](../adr/0005-team-repos-propose-only.md)

## 확인한 외부 사실

이 페이지로 옮겨 온 외부 사실은 없다.
