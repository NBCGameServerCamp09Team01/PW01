# 명세(Contracts) 목록

게임(ProjectWarrior)과 웹서버(PW01WebServer)가 함께 지키는 약속입니다. **코드보다 명세를 먼저 고칩니다.**

| 명세 | 현재 버전 | 상태 | 게임 담당 | 웹서버 담당 |
|---|---|---|---|---|
| [auth-api.md](auth-api.md) | v1.1 | 초안 | Juunnmmoo | Robbie (리뷰: Sang-Hyun-Kim) |
| [account-api.md](account-api.md) | v1.3 | 초안 | Juunnmmoo | Robbie (리뷰: Sang-Hyun-Kim) |
| [stat-api.md](stat-api.md) | v1 | 구현됨 | Robbie | Robbie (리뷰: Sang-Hyun-Kim) |
| [skill-api.md](skill-api.md) | v1 | 초안 | Robbie | Robbie (리뷰: Sang-Hyun-Kim) |
| [result-api.md](result-api.md) | v1.2 | 초안 | Robbie | Robbie (리뷰: Sang-Hyun-Kim) |
| [stage-api.md](stage-api.md) | v1.3 | 초안 | Sang-Hyun-Kim | Sang-Hyun-Kim (리뷰: Robbie) |
| [stage-play-api.md](stage-play-api.md) | v1.3 | 초안 | Robbie | Sang-Hyun-Kim (리뷰: Robbie) |
| [realtime-api.md](realtime-api.md) | v1.3 | 초안 | Juunnmmoo | Juunnmmoo (리뷰: Sang-Hyun-Kim 배정) |
| [ranking-api.md](ranking-api.md) | v1 | 초안 | Sang-Hyun-Kim | Sang-Hyun-Kim (리뷰: Robbie) |
| [redis-keys.md](redis-keys.md) | v1.5 | 합의(v1.3 랭킹 절·v1.4 체크포인트 키·v1.5 서버 사이 전달 채널 초안) | — | Sang-Hyun-Kim (리뷰: Robbie) |

- 상태: `작성 전` → `초안` → `합의` → `구현됨`
- 요청·응답 JSON 예시는 [examples/](examples/) 에 둡니다.

## 공통 규칙

> 상태: 합의(10/7 저녁, 성공 응답·요청 번호·`retryable`·`retryAfterSeconds` 추가. 10/12 [상태를 바꾸는 요청과 재전송](#상태를-바꾸는-요청과-재전송) 추가, 게임 담당 리뷰 전. 10/12 오류 본문의 기능별 추가 칸 추가(S4), 리뷰 전. 10/15 서버 주소·서버 상태 확인 `GET /health` 추가, 리뷰 전). 모든 API에 적용합니다. 바꿀 때는 이 절을 먼저 고치고 게임·웹서버 담당 모두에게 리뷰를 받습니다.

| 항목 | 규칙 |
|---|---|
| 경로 | 기능 이름부터 바로 씁니다(예: `/auth/login`, `/accounts/me`). 경로에 `/api`·버전(`/v1`)을 넣지 않습니다. 호환되지 않는 변경을 경로로 나눌지는 〔정할 것〕입니다 |
| 서버 주소 | 게임이 부르는 주소는 환경마다 **하나**입니다. 로컬은 `http://localhost:8080`, 배포는 로드 밸런서 주소 하나(`http`, 포트 80, 끝에 `/` 없음)입니다. 배포 서버가 여러 대여도 주소는 같고, 요청마다 로드 밸런서가 살아 있는 서버 하나로 보냅니다. WebSocket 주소는 같은 주소의 `ws://…/realtime`입니다 |
| 시각 | UTC. JSON에서는 `Z`가 붙은 ISO-8601 문자열이고, 초 아래는 밀리초까지 씁니다. 예: `"2026-10-05T03:00:00.123Z"` |
| 성공 | 본문은 아래 [성공 응답](#성공-응답) 모양(`{data, meta}`)입니다. `204`는 본문이 없습니다 |
| 오류 | HTTP 상태 코드와 함께 아래 [오류 응답](#오류-응답) 본문을 보냅니다 |
| 요청 번호 | 모든 응답에 헤더 `X-Request-Id`가 붙습니다. 성공 응답의 `meta.requestId`와 같은 값이고, 서버 로그에도 남습니다. 문의할 때 이 값을 알려 주면 로그를 찾을 수 있습니다 |
| ID | 계정 ID 같은 큰 정수는 JSON에서 **문자열**입니다(UE `FString`) |
| 모르는 필드 | 서버는 **요청**에 모르는 필드가 있으면 400(`INVALID_REQUEST_BODY`)으로 거절합니다. 게임은 **응답**에 모르는 필드가 있으면 무시합니다 |
| 필드 추가 | 응답 필드 추가는 호환되는 변경입니다(`v1` → `v1.1`). 요청 필드를 추가할 때는 서버를 먼저 배포합니다 |

### 성공 응답

```json
{
  "data": { "accountId": "1", "loginId": "warrior01", "nickname": "용사", "createdAt": "2026-10-07T03:00:00.123Z" },
  "meta": { "requestId": "0b6f3c1e-8a2d-4c6e-9f10-2a7b5d9e1c34" }
}
```

| 필드 | 설명 |
|---|---|
| `data` | 그 API의 결과. 모양은 각 명세에 적습니다 |
| `meta.requestId` | 요청 번호. 응답 헤더 `X-Request-Id`와 같습니다. 지금은 서버가 만듭니다. 상태를 바꾸는 요청에 게임이 본문 `requestId`(중복 방지 키)를 보내게 되면(S2부터) 그 값을 그대로 씁니다 |


### 오류 응답

```json
{
  "code": "VALIDATION_FAILED",
  "message": "요청 값이 올바르지 않습니다.",
  "path": "/auth/signup",
  "retryable": false,
  "errors": [
    { "field": "loginId", "message": "아이디는 영문·숫자 4~20자여야 합니다." }
  ]
}
```


| 필드 | 설명 |
|---|---|
| `code` | 기계가 읽는 오류 코드(대문자와 `_`). 게임은 이 값으로 화면 문구를 고릅니다 |
| `message` | 사람이 읽는 설명 |
| `path` | 요청 경로 |
| `retryable` | 같은 요청을 다시 보내도 되는지. 서버 쪽 문제(`500`·`503`)와 잠시 뒤 풀리는 충돌(`REQUEST_IN_PROGRESS`·`VERSION_CONFLICT`)은 `true`, 나머지는 `false`. 게임은 `true`일 때만 정한 횟수만큼 **같은 본문으로** 다시 보냅니다 |
| `errors` | 검증 오류(`VALIDATION_FAILED`)와, 기능 명세가 정한 칸 오류(예: `STAT_MAX_EXCEEDED`, `SKILL_UNKNOWN`)에 붙습니다. 필드별 오류 전부 |
| `retryAfterSeconds` | `429`일 때만 붙습니다. 다시 시도할 수 있기까지 남은 초. 같은 값이 표준 헤더 `Retry-After`에도 붙습니다 |
| (기능별 추가 칸) | 기능 명세가 그 오류 코드에 정한 칸만 붙습니다(예: [skill-api.md](skill-api.md) `SKILL_REQUIREMENTS_NOT_MET`의 `requirements`). 이름과 모양은 그 명세에 적고, 게임은 모르는 칸을 무시합니다 |

### 오류 코드

| 코드 | HTTP | 상황 |
|---|---|---|
| `VALIDATION_FAILED` | 400 | 요청 값(본문 필드, 경로·쿼리 값) 검증 실패 |
| `INVALID_REQUEST_BODY` | 400 | JSON을 읽을 수 없음, 모르는 필드, 타입이 맞지 않음 |
| `NOT_FOUND` | 404 | 없는 경로 |
| `METHOD_NOT_ALLOWED` | 405 | 허용되지 않은 HTTP 메서드 |
| `INTERNAL_ERROR` | 500 | 서버 내부 오류. 원인은 서버 로그에만 남깁니다 |
| `SERVICE_UNAVAILABLE` | 503 | MySQL·Redis에 닿지 못함. 잠시 뒤 다시 보내면 될 수 있습니다 |
| `REQUEST_IN_PROGRESS` | 409 | 같은 `requestId`의 처음 요청을 아직 처리 중(`retryable: true`). 아래 [재전송](#상태를-바꾸는-요청과-재전송) |
| `IDEMPOTENCY_KEY_REUSED` | 409 | 같은 `requestId`에 다른 본문(`retryable: false`, 게임 버그) |
| `VERSION_CONFLICT` | 409 | 같은 계정의 저장이 계속 부딪혀 저장하지 못함(`retryable: true`). 서버가 먼저 몇 번 다시 한 뒤입니다 |

- 위 표에 없는 HTTP 오류는 상태 이름을 코드로 씁니다(예: 415 → `UNSUPPORTED_MEDIA_TYPE`).
- 기능별 오류 코드(예: `ACCOUNT_LOGIN_ID_DUPLICATED`)는 각 명세의 "오류" 표에 적습니다.
### 재전송 규칙

> 상태: 초안(S5 오류 안내·끊김 복구). 게임이 실패한 요청을 다시 보내는 규칙입니다. 서버는 다시 온 요청도 처음과 같은 검사를 합니다. `requestId`·같은 본문·서버 응답·한 번만 반영하는 방법은 아래 [상태를 바꾸는 요청과 재전송](#상태를-바꾸는-요청과-재전송)을 따릅니다.

| 항목 | 규칙 |
|---|---|
| 다시 보내는 방법 | 상태를 바꾸는 요청은 **같은 `requestId`·같은 본문**으로 다시 보냅니다. 조회는 그대로 다시 보냅니다 |
| 다시 보내는 경우 | 응답이 없음(연결 실패·시간 초과), `retryable: true`(`500`·`503`·`VERSION_CONFLICT`·`REQUEST_IN_PROGRESS`), 위 [오류 응답](#오류-응답) 모양이 아닌 5xx(로드 밸런서의 502·503·504 등 — 본문이 없거나 HTML). 그 밖(`retryable: false`)은 다시 보내지 않습니다 |
| 다시 보내지 않는 경우 | `401`(로그인 상태를 끝냄, [auth-api.md](auth-api.md#인증-확인-순서와-실패-코드)), `429`(`retryAfterSeconds`가 지난 뒤 사용자가 다시 시도), 나머지 4xx |
| 횟수·간격 | 게임 설정 값(UE `DefaultGame.ini`의 `[/Script/ProjectWarrior.WarriorApiSettings]`). 기본: 서버 장애(`retryable: true`·5xx)는 자동 2번(1초, 3초 뒤), 응답이 없으면(서버 꺼짐) 자동 재시도 없이 → 플레이어에게 "다시 시도 / 게임 종료"를 한 번 묻습니다 |
| 보관 | 상태 변경 요청이 처음 실패하면 게임이 **계정별로 디스크에 보관**합니다(그 뒤 성공하면 지움). 묻기 뒤에도 실패하면 "게임을 종료합니다"를 안내하고 끝냅니다. 그 계정이 다시 로그인하면 같은 `requestId`·같은 본문으로 다시 보냅니다. 토큰은 보관하지 않습니다 |
| 보관 대상 | 지금은 결과 제출([result-api.md R1](result-api.md#r1-결과-제출--post-accountsmestage-playsstageplayidresult))만. 스테이지 플레이 시작·포기·체크포인트 저장은 보관하지 않습니다(남은 진행 중 플레이는 다음 시작의 409 처리가 정리, 체크포인트는 다음 웨이브 클리어 때 새로 올림) |
| 보관 유효 기간 | 결과 제출: 스테이지 플레이 마감(`expiresAt`, 시작 + 24시간)까지. 그 밖의 종류: 보관한 뒤 24시간(게임 설정 값). 지난 보관본은 보내지 않고 지웁니다 |
| 오래된 요청 | 서버는 기능별 코드로 거절합니다(결과: `STAGE_PLAY_EXPIRED`). 새 공통 코드는 두지 않습니다. 게임은 `retryable: false` 거절을 받으면 보관본을 지우고 이유를 보입니다 |
| 한 번만 반영 | 서버가 맡습니다. API별 방법은 아래 "API별 한 번만 반영하는 방법" 표 |
| 서버 상태 확인 | 게임은 타이틀에서 `GET /health`(인증 없음)로 서버를 확인하고, 응답이 없거나 200이 아니면 안내 후 종료합니다. 서버가 MySQL·Redis에 모두 닿으면 200 `{"status":"UP"}`, 하나라도 닿지 못하면 503 `{"status":"DOWN"}`입니다. 하위 상태(`components`)는 보이지 않으며, 이 본문은 위 [성공 응답](#성공-응답)·[오류 응답](#오류-응답) 모양이 아닙니다(게임은 상태 코드만 봅니다). 경로 규칙(기능 이름부터)의 예외입니다. 관리용 `/actuator/*`는 배포 환경에서 밖에 열지 않습니다(관리 포트, 서버 안에서만) |

### 상태를 바꾸는 요청과 재전송

포인트·진행처럼 계정 값을 바꾸는 요청은 응답을 받지 못해 다시 보내도 **한 번만** 반영됩니다. 게임과 서버가 아래 규칙을 같이 지킵니다.

**게임 규칙**

| 무엇 | 규칙 |
|---|---|
| `requestId` | 상태를 바꾸는 요청 본문에 넣습니다. UUID 소문자 36자. 서버는 소문자로 맞춰 비교합니다 |
| 새 동작 | 사용자가 새로 누른 동작(새 "적용", 새 시작)에는 **새 `requestId`** |
| 다시 보낼 때 | 연결 실패나 `retryable: true`일 때만, **같은 `requestId`와 같은 본문**으로, 정한 횟수만큼(게임 설정 값) |
| 거절 | `retryable: false`는 다시 보내지 않습니다. 화면에 알리고, 필요하면 계정 값을 다시 받습니다 |

**서버 응답**

| 경우 | 응답 |
|---|---|
| 같은 `requestId` + 같은 본문, 처음 요청이 성공함 | **처음 응답 그대로** |
| 같은 `requestId` + 같은 본문, 처음 요청이 아직 처리 중 | 409 `REQUEST_IN_PROGRESS`(`retryable: true`) |
| 같은 `requestId` + 다른 본문 | 409 `IDEMPOTENCY_KEY_REUSED`(`retryable: false`) |
| 처음 요청이 거절·실패(4xx·5xx)로 끝남 | 기억하지 않습니다. 같은 `requestId`로 다시 보내면 처음처럼 다시 판정합니다 |
| 기억이 사라진 뒤(시간 지남 등) 같은 요청 | 두 번 반영하지 않습니다. 200 + `saveStatus: ALREADY_SAVED` + 지금 값 |
| 서버가 기억 장소(Redis)에 닿지 못함 | 503 `SERVICE_UNAVAILABLE`(`retryable: true`) |

**API별 한 번만 반영하는 방법**

| API | 무엇으로 | 명세 |
|---|---|---|
| 스테이지 플레이 시작 | DB: 계정 + 시작 `requestId` | [stage-play-api.md](stage-play-api.md) |
| 결과 제출 | DB: 플레이 ID(한 플레이에 결과 하나) | [result-api.md](result-api.md) |
| 체크포인트 저장(C1) | Redis: 플레이당 하나를 덮어씀 + `clearedWave`가 뒤로 가지 않음. `requestId` 없음(같은 요청이 다시 와도 결과가 같음) | [stage-play-api.md C1](stage-play-api.md#c1-저장--put-accountsmestage-playsstageplayidcheckpoint) |
| 스탯 투자 | Redis 처음 응답 + DB 변경 내역 | [stat-api.md](stat-api.md) "한 번만 반영" |
| 스킬 해금 | 스탯 투자와 같은 방법(DB 마지막 방어: 계정 + 스킬 한 줄) | [skill-api.md](skill-api.md) "한 번만 반영" |
| 우편함(나중) | 스탯 투자와 같은 방법 | 그 명세 |

- Redis 키·명령 순서·기억 시간은 [redis-keys.md](redis-keys.md) `pw01:idem`에 있습니다.

## 변경 절차

1. `docs/…` 브랜치에서 명세를 고칩니다. 버전을 올리고 문서 아래 "변경 이력"에 한 줄 적습니다.
2. 게임·웹서버 담당자 모두에게 PR 리뷰를 받습니다.
3. 병합 후 각 저장소에서 구현합니다. 구현이 끝나면 위 표의 상태를 `구현됨`으로 바꿉니다.

## 버전 규칙

- 호환되는 추가(필드 추가 등): `v1` → `v1.1`
- 호환되지 않는 변경(필드 삭제·이름 변경·의미 변경): `v1` → `v2`. 양쪽이 동시에 배포되어야 합니다.
