# 협업 준비 (contrib)

진입점 `repo-setup` 의 목적 `contrib` 다. 세팅 절차는 `plugin/skills/repo-setup/contrib/PROCEDURE.md` 에 있다.

## 하는 일

기여 안내와 신고처, 서식, 리뷰 담당을 놓고 기본 브랜치를 보호한다.

신고처가 적혀 있지 않으면 취약점이 공개 이슈로 올라온다. 그 순간부터 고치기 전까지 누구나 볼 수
있다. 기여 안내가 없으면 사람마다 다르게 하고 리뷰에서 매번 같은 말을 반복하게 된다.

## 동작

**GitHub 은 이 파일들을 한 곳에서만 찾지 않는다.** 루트와 `.github/` 를 모두 보고 CODEOWNERS 는
`docs/` 까지 본다. 한 곳만 보고 없다고 판단해 덮으면 남이 쓴 문서가 사라진다. 그래서
`contrib/scripts/check-contrib.sh` 가 GitHub 이 보는 자리를 모두 훑는다. 빈 `ISSUE_TEMPLATE` 폴더는
있는 것으로 보지 않는다. 폴더만 있으면 아무 서식도 뜨지 않기 때문이다.

**혼자 쓰는 저장소에 리뷰 승인을 요구하지 않는다.** 자기 PR 을 자기가 병합할 수 없어 막힌다.

## 바꾸는 것

- 해당하는 골격만 놓는다. `SECURITY.md`, `CONTRIBUTING.md`, PR 서식, 버그 신고 서식, `CODEOWNERS` 이고,
  원본은 `plugin/skills/repo-setup/contrib/templates/` 에 있다.
- GitHub 설정: 기본 브랜치 보호(`gh api -X PUT repos/OWNER/REPO/branches/BRANCH/protection`). 세팅 PR 이
  병합된 뒤에 `/repo-setup:repo-setup contrib` 를 다시 불러 건다.
- 팀 저장소에서는 협업 파일을 세팅 PR 로 올리고, 브랜치 보호는 걸지 않고 계획만 보인다.

## 한계와 알려진 문제

스킬 본문에 적힌 것 말고 이 페이지로 옮겨 온 한계는 없다.

## 관련 파일

- `plugin/skills/repo-setup/contrib/PROCEDURE.md`
- `plugin/skills/repo-setup/contrib/scripts/check-contrib.sh`
- `plugin/skills/repo-setup/contrib/templates/`
- `tests/contrib/unit.sh`

## 관련 ADR

- [0003. 겹치는 파일과 설정의 소유를 정한다](../adr/0003-ownership-of-overlapping-files.md)
- [0005. 팀 저장소의 공유 자산은 제안만 한다](../adr/0005-team-repos-propose-only.md)
- [0011. 팀 저장소에도 파일 변경은 확인 후 PR 로 올리고, 푸시할 수 없으면 패치로 물러난다](../adr/0011-team-repos-file-changes-by-pr.md)

## 확인한 외부 사실

이 페이지로 옮겨 온 외부 사실은 없다.
