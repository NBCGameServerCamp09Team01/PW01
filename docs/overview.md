# 시스템 전체 구조

> 상태: **초안**. 싱글 게임 + 웹 백엔드 구조로 다시 썼습니다(2026-10-05). 확정되지 않은 부분은 `TBD`로 표시했습니다.

## 구성 요소

| 구성 요소 | 저장소 | 기술 | 역할 |
|---|---|---|---|
| 게임 클라이언트 | ProjectWarrior | Unreal Engine 5.8.3 | 플레이어가 실행하는 싱글 게임. 계정·결과·성장 요청을 웹서버에 보냄 |
| 웹서버 | PW01WebServer | Spring Boot 4.1, Java 21 | 게임이 호출하는 API. 요청 검증·판정과 저장 |
| Redis | PW01WebServer `compose.yaml` (로컬) | Redis 7.4 | 세션·중복 방지 키 등 빠르게 바뀌는 상태 |
| DB | PW01WebServer `compose.yaml` (로컬) | MySQL 8.4 (운영: TBD) | 계정, 결과 등 영구 데이터 |
| 인프라 | Infra (예정, 미작성) | TBD | 배포 환경 |

## 흐름 (초안)

```
[게임 클라이언트] ──HTTP──▶ [웹서버] ──▶ [DB]
                              │
                              └──▶ [Redis]
```

1. 게임 클라이언트가 웹서버 API를 호출합니다. 요청·응답 형식은 [contracts/](contracts/README.md)가 기준입니다.
2. 게임이 끝나면 게임 클라이언트가 웹서버에 결과를 보냅니다 → [result-api.md](contracts/result-api.md)
3. 웹서버는 빠르게 바뀌는 상태를 Redis에 두고 → [redis-keys.md](contracts/redis-keys.md), 영구 데이터는 DB에 저장합니다.

## 정해야 할 것

- [ ] 클라이언트 인증 방식
- [ ] 운영 DB 종류
- [ ] 배포 환경 (Infra 저장소를 만들지 여부)
