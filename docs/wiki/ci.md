# 테스트 워크플로 (ci)

스킬 `repo-ci` 가 맡는다. 세팅 절차는 `plugin/skills/repo-ci/SKILL.md` 에 있다.

## 하는 일

테스트가 푸시마다 돌게 하고 실제로 한 번 돌려 확인한다.

로컬에서만 도는 테스트는 잊힌다. 자동으로 도는 자리는 푸시와 풀 리퀘스트다.

## 동작

**테스트가 없으면 워크플로를 만들지 않는다**([0004](../adr/0004-no-ci-without-tests.md)). 그래서 테스트
명령이 있는지를 사람 눈이 아니라 `templates/find-test-command.sh` 가 판정한다. `npm init` 이 넣는 기본
자리표시자는 테스트로 보지 않는다.

**파일을 놓은 것은 검증이 아니다.** 실제로 한 번 돌려 통과를 본 뒤에야 끝났다고 말한다.
액션을 SHA 로 고정하는 것은 `repo-secure` 가 맡는다.

## 바꾸는 것

- 대상 저장소에 `.github/workflows/tests.yml` 을 새로 놓는다. 원본은
  `plugin/skills/repo-ci/templates/tests.yml` 이다.
- 이미 워크플로가 있으면 덮지 않고, 실측한 테스트 명령과 어긋나는 곳만 알린다.

## 한계와 알려진 문제

스킬 본문에 적힌 것 말고 이 페이지로 옮겨 온 한계는 없다.

## 관련 파일

- `plugin/skills/repo-ci/SKILL.md`
- `plugin/skills/repo-ci/templates/find-test-command.sh`
- `plugin/skills/repo-ci/templates/tests.yml`
- `tests/ci/unit.sh`

## 관련 ADR

- [0003. 겹치는 파일과 설정의 소유를 정한다](../adr/0003-ownership-of-overlapping-files.md)
- [0004. 테스트 없는 저장소에 CI 를 만들지 않는다](../adr/0004-no-ci-without-tests.md)

## 확인한 외부 사실

이 페이지로 옮겨 온 외부 사실은 없다.
