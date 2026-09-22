# ADR

설계 결정 하나에 파일 하나를 둔다. 결정을 **왜** 그렇게 내렸는지와 버린 대안을 적는다. 선택 조건이나
순서 같은 실행 규칙은 스킬 본문(`plugin/skills/*/SKILL.md`)에만 두고 여기에 옮겨 적지 않는다. 구현된
기능이 무엇을 하는지는 [wiki](../wiki/README.md) 에 있다.

- 파일 이름은 `NNNN-<영어-kebab-slug>.md` 다. 번호는 차례대로 매기고 다시 쓰지 않는다.
- 절은 제목, 상태, 맥락, 결정, 결과 다섯이다(Michael Nygard 의 형식).
- 상태는 `제안`, `승인`, `폐기`, `대체됨(→ NNNN)` 중 하나와 날짜다.
- 뒤집힌 결정은 지우지 않는다. 상태를 `대체됨(→ NNNN)` 으로 바꾸고, 새 ADR 의 맥락에서 옛 ADR 을
  가리킨다.

| 번호 | 제목 | 상태 |
|---|---|---|
| 0001 | [저장소 층만 다룬다](0001-repository-layer-only.md) | 승인 |
| 0002 | [목적별로 좁은 스킬 다섯을 둔다](0002-five-narrow-skills-by-purpose.md) | 대체됨(→ 0006) |
| 0003 | [겹치는 파일과 설정의 소유를 정한다](0003-ownership-of-overlapping-files.md) | 승인 |
| 0004 | [테스트 없는 저장소에 CI 를 만들지 않는다](0004-no-ci-without-tests.md) | 승인 |
| 0005 | [팀 저장소의 공유 자산은 제안만 한다](0005-team-repos-propose-only.md) | 승인 |
| 0006 | [스킬 하나에 목적별 폴더를 둔다](0006-single-skill-with-purpose-folders.md) | 승인 |
