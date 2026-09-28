# 시스템 전체 구조

> 상태: **초안**. 구성 요소와 흐름은 팀 확인 후 확정합니다. 확정되지 않은 부분은 `TBD`로 표시했습니다.

## 구성 요소

| 구성 요소 | 저장소 | 기술 | 역할 |
|---|---|---|---|
| 게임 클라이언트 | ProjectWarrior | Unreal Engine 5.8.3 | 플레이어가 실행하는 게임 |
| 데디케이티드 서버(DS) | ProjectWarrior | Unreal Engine 5.8.3 | 게임 세션 진행 (TBD: 운영 방식) |
| 웹서버 | PW01WebServer | Spring Boot | DS 등록·조회, 게임 결과 저장, 기타 API |
| Redis | PW01WebServer `compose.yaml` (로컬) | Redis | DS 목록, 세션 등 빠르게 바뀌는 상태 |
| DB | PW01WebServer `compose.yaml` (로컬) | TBD (로컬은 MySQL) | 계정, 결과 등 영구 데이터 |
| 인프라 | Infra (예정, 미작성) | TBD | 배포 환경 |

## 흐름 (초안)

```
[게임 클라이언트] ──HTTP──▶ [웹서버] ──▶ [DB]
        │                     │
        │ 접속                 └──▶ [Redis]
        ▼                     ▲
       [DS] ───HTTP(등록·결과)──┘
```

1. DS가 뜨면 웹서버에 자신을 등록합니다 → [ds-registry-api.md](contracts/ds-registry-api.md)
2. 클라이언트는 웹서버에서 접속할 DS를 받아 접속합니다 (TBD)
3. 게임이 끝나면 DS가 웹서버에 결과를 보냅니다 → [result-api.md](contracts/result-api.md)
4. 웹서버는 상태를 Redis에 두고 → [redis-keys.md](contracts/redis-keys.md), 영구 데이터는 DB에 저장합니다

## 정해야 할 것

- [ ] DS 실행·종료 방식 (로컬 수동 실행 / 서버에서 자동 실행)
- [ ] 클라이언트 인증 방식
- [ ] 운영 DB 종류
- [ ] 배포 환경 (Infra 저장소를 만들지 여부)
