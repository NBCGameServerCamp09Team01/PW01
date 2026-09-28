# 문서 지도

팀 공통 문서의 목록입니다. 새 문서를 추가하면 이 표에도 적어 주세요.

| 문서 | 내용 | 상태 |
|---|---|---|
| [overview.md](overview.md) | 시스템 전체 구조 한 장 요약 | 초안 |
| [git-workflow.md](git-workflow.md) | 팀 규칙: 브랜치·커밋·LFS·맵 담당·작업 순서 | 확정 |
| [contracts/README.md](contracts/README.md) | 게임 ↔ 웹서버 명세 목록과 현재 버전 | 초안 |
| [contracts/result-api.md](contracts/result-api.md) | 결과 API | 작성 전 |
| [contracts/ds-registry-api.md](contracts/ds-registry-api.md) | DS 등록 API | 작성 전 |
| [contracts/redis-keys.md](contracts/redis-keys.md) | Redis 키 규칙 | 작성 전 |
| [contracts/examples/](contracts/examples/) | 요청·응답 JSON 예시 | 작성 전 |
| 일정 | 마일스톤·마감 | 자리만 (추후 추가) |

## 다른 곳에 있는 문서

- 게임 쪽 문서: `ProjectWarrior/docs/` (ProjectWarrior 저장소)
- 웹서버 쪽 문서: `PW01WebServer/docs/` (PW01WebServer 저장소)
- AI 에이전트 규칙: 루트 [AGENTS.md](../AGENTS.md)
- 개인 문서: `docs_local/` (커밋되지 않음)

## 문서 규칙

- 두 저장소가 함께 지키는 약속은 `contracts/`에 둡니다. 한쪽 저장소 안에만 적지 않습니다.
- 명세를 바꿀 때는 버전과 변경 이력을 함께 고치고, 양쪽 담당자에게 PR 리뷰를 요청합니다.
