# 호스트 보안 층 (secure)

진입점 `repo-setup` 의 목적 `secure` 다. 세팅 절차는 `plugin/skills/repo-setup/secure/PROCEDURE.md` 에 있다.

## 하는 일

호스트의 보안 기능을 켜고 액션을 SHA 로 고정한다.

커밋 훅은 커밋 시점만 본다. 이미 푸시된 것, 남이 자기 기계에서 푸시한 것, `--no-verify` 로 넘긴
것은 호스트 층만 잡는다. 두 층은 서로를 대체하지 않는다.

## 동작

액션은 남의 코드를 내 자격증명과 함께 돌린다. 태그는 옮길 수 있어서 같은 `@v5` 가 어제와 다른
코드를 가리킬 수 있고, **그 사실이 diff 에 남지 않는다.** 그래서 40자 SHA 로 고정한다.

**건 것으로 끝내지 않는다.** 되읽어 값이 바뀌었는지 본다. 호출이 200 을 돌려주고도 값이 안 바뀌는
항목을 실제로 겪었고, 그런 경우 바뀌었다고 적지 않는다.

## 바꾸는 것

- GitHub 설정: secret scanning 과 push protection 을 켠다(`gh api -X PATCH repos/OWNER/REPO`).
- 대상 저장소에 `.github/dependabot.yml` 과 CodeQL 워크플로 `codeql.yml` 을 놓는다. 원본은
  `plugin/skills/repo-setup/secure/templates/` 에 있다.
- 이미 있는 워크플로를 포함해 모든 워크플로의 `uses:` 를 SHA 로 바꾸고 옆에 태그를 주석으로 남긴다.
- 팀 저장소에서는 파일 변경을 세팅 PR 로 올리고, GitHub 설정은 바꾸지 않고 계획만 보인다.

## 한계와 알려진 문제

스킬 본문의 「아는 한계」 절에 있다.

## 관련 파일

- `plugin/skills/repo-setup/secure/PROCEDURE.md`
- `plugin/skills/repo-setup/secure/scripts/check-workflow-security.sh`
- `plugin/skills/repo-setup/secure/templates/dependabot.yml`
- `plugin/skills/repo-setup/secure/templates/codeql.yml`
- `tests/secure/unit.sh`

## 관련 ADR

- [0003. 겹치는 파일과 설정의 소유를 정한다](../adr/0003-ownership-of-overlapping-files.md)
- [0005. 팀 저장소의 공유 자산은 제안만 한다](../adr/0005-team-repos-propose-only.md)
- [0011. 팀 저장소에도 파일 변경은 확인 후 PR 로 올리고, 푸시할 수 없으면 패치로 물러난다](../adr/0011-team-repos-file-changes-by-pr.md)

## 확인한 외부 사실

이 페이지로 옮겨 온 외부 사실은 없다.
