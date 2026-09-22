# 0003. 겹치는 파일과 설정의 소유를 정한다

- 상태: 승인 (2026-09-22)

## 맥락

목적 다섯 개는 서로 다른 것을 세팅하지만, 경계에서 같은 파일이나 설정을 건드리는 곳이 세 군데 있다.

- `.github/workflows/*.yml` 은 테스트 워크플로와 호스트 보안 층이 함께 건드린다.
- 브랜치 보호는 검증 방법이 호스트 보안 층과 같은 API 호출이지만, 혼자 쓰는 저장소에는 의미가 없는
  협업 장치다.
- `.gitignore` 전체는 범위 밖이지만([0001](0001-repository-layer-only.md)), `.private/` 를 무시하는
  줄은 가드의 일부다.

## 결정

목적마다 소유하는 것과 성공 판정을 아래처럼 정한다.

| 스킬 | 소유하는 것 | 성공 판정 | 순서 |
|---|---|---|---|
| `repo-privacy` | 커밋 훅, 패턴 출처 세 곳, `core.hooksPath`, `.gitignore` 의 `.private/` 한 줄 | 홈 경로가 든 커밋이 실제로 막힌다 | 1 |
| `repo-license` | `LICENSE`, 매니페스트의 `license` 필드, SPDX 헤더 | 파일과 매니페스트가 같은 라이선스를 말한다 | 2 |
| `repo-ci` | 테스트 워크플로 파일, 매트릭스 | 워크플로가 실제로 한 번 돌아 통과한다 | 3 |
| `repo-secure` | secret scanning, push protection, 코드 스캐닝, `dependabot.yml`, 액션 SHA 고정, 토큰 권한 | GitHub API 가 `enabled` 를 돌려준다. 워크플로에 태그 참조가 없다 | 4 |
| `repo-contrib` | CONTRIBUTING, 이슈·PR 템플릿, CODEOWNERS, `SECURITY.md`, 브랜치 보호 | 파일이 놓였다. 보호 규칙 API 응답이 맞다 | 5 |

- 워크플로 파일은 `repo-ci` 가 만들고, `repo-secure` 는 이미 있는 파일의 액션 고정과 `permissions`
  만 고친다. CodeQL 워크플로는 `repo-secure` 가 자기 파일(`codeql.yml`)로 따로 만든다.
- 브랜치 보호는 `repo-contrib` 이 갖는다. 목적 쪽을 따랐다.
- `.private/` 를 무시하는 줄은 `repo-privacy` 가 그 한 줄만 책임진다.

호출 순서는 `repo-privacy` → `repo-license` → `repo-ci` → `repo-secure` → `repo-contrib` 이다.
순서 자체는 진입점 `plugin/skills/repo-setup/SKILL.md` 에 있고, 여기에는 이유만 둔다.

- 가드가 맨 앞이다. 뒤 단계가 만드는 파일도 가드를 거쳐야 한다.
- `repo-ci` 가 `repo-secure` 보다 앞이다. 워크플로 파일을 `repo-ci` 가 만들고 `repo-secure` 가 고치기
  때문이다.
- `repo-contrib` 이 맨 뒤다. 브랜치 보호에 CI 상태 검사를 필수로 걸려면 CI 가 먼저 있어야 한다.

## 결과

- 같은 파일을 두 목적이 새로 만드는 일이 없다. 워크플로 파일을 만드는 쪽은 하나다.
- 순서가 소유 관계에 묶인다. `repo-secure` 를 `repo-ci` 보다 먼저 부르면 고칠 워크플로가 아직 없다.
- 브랜치 보호의 검증은 `repo-secure` 와 같은 API 호출이지만 `repo-contrib` 의 테스트에 둔다.
