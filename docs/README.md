# 문서 지도

팀 공통 문서의 목록입니다. 새 문서를 추가하면 이 표에도 적어 주세요.

| 문서 | 내용 | 상태 |
|---|---|---|
| [overview.md](overview.md) | 시스템 전체 구조 한 장 요약 | 초안 |
| [git-workflow.md](git-workflow.md) | 팀 규칙: 브랜치·커밋·LFS·맵 담당·작업 순서 | 확정 |
| [contracts/README.md](contracts/README.md) | 게임 ↔ 웹서버 명세 목록과 현재 버전 | 초안 |
| [contracts/result-api.md](contracts/result-api.md) | 결과 API | 작성 전 |
| [contracts/stat-api.md](contracts/stat-api.md) | 스탯 투자 API(묶음 올림·내림) | 구현됨 v1 |
| [contracts/skill-api.md](contracts/skill-api.md) | 스킬 해금 API(해금, 서버 진행도) | 초안 v1 |
| [contracts/redis-keys.md](contracts/redis-keys.md) | Redis 키 규칙 | 작성 전 |
| [contracts/ranking-api.md](contracts/ranking-api.md) | 랭킹 API(스테이지·지역 총합·전체 총합·진행 순위, 전체·주간) | 초안 v1 |
| [contracts/stage-play-api.md](contracts/stage-play-api.md) | 스테이지 플레이 API(시작·진행 중·포기, 이어하기 1차) | 초안 v1.1 |
| [contracts/examples/](contracts/examples/) | 요청·응답 JSON 예시 | 작성 전 |
| [flows/play-checkpoint.md](flows/play-checkpoint.md) | 진행 중 스테이지 이어하기 흐름도 | 초안 |
| 일정 | 마일스톤·마감 | 자리만 (추후 추가) |

## 다른 곳에 있는 문서

- 게임 쪽 문서: `ProjectWarrior/docs/` (ProjectWarrior 저장소)
- 웹서버 쪽 문서: `PW01WebServer/docs/` (PW01WebServer 저장소)
- AI 에이전트 규칙: 루트 [AGENTS.md](../AGENTS.md)
- 개인 문서: `docs_local/` (커밋되지 않음)

## 문서 규칙

- 두 저장소가 함께 지키는 약속은 `contracts/`에 둡니다. 한쪽 저장소 안에만 적지 않습니다.
- 명세를 바꿀 때는 버전과 변경 이력을 함께 고치고, 양쪽 담당자에게 PR 리뷰를 요청합니다.
