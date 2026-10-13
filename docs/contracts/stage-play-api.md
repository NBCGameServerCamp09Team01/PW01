# 스테이지 플레이 API (Stage Play API)

> 버전: v1.2 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Robbie · 웹서버 담당: Sang-Hyun-Kim (리뷰: Robbie)

계정이 스테이지에 들어갈 때 서버가 **스테이지 플레이 ID**를 발급하고, 그 플레이가 진행 중인지·끝났는지를 서버가 관리합니다. 결과 제출은 이 ID로 합니다([result-api.md](result-api.md)). **계정 하나는 진행 중인 플레이를 하나만** 가질 수 있습니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증). 아래 API는 모두 인증이 필요합니다
- 스테이지 키·열림·잠김: [stage-api.md](stage-api.md)

## 낱말

| 낱말 | 뜻 |
|---|---|
| 스테이지 플레이 | 계정이 스테이지 하나를 **한 번** 플레이하는 것. 입장(시작)부터 결과(클리어·실패)까지 |
| `stagePlayId` | 스테이지 플레이 ID. UUID 소문자·하이픈 36자(예: `3f2b8c1e-7a4d-4e2f-9b10-6c5d4e3f2a1b`). 서버가 발급합니다. 경로로 받을 때는 대문자도 받고 소문자로 맞춥니다 |
| 진행 중 | 시작했고 아직 결과·포기·만료가 없는 상태. 계정당 하나 |
| 마감 | 결과를 낼 수 있는 마지막 시각. 시작 + 24시간 |
| 체크포인트 | 진행 중인 플레이의 판 안 값(골드·아이템·판 강화·체력·판 통계 등). 웨이브를 클리어할 때마다 게임이 올리고(덮어씀), 이어하기 때 받아 그 웨이브 다음부터 시작합니다. 판이 끝나면 지웁니다 |

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| P1 | POST | `/accounts/me/stage-plays` | 필요 | 201 + `Location` | 스테이지 플레이 시작 |
| P2 | GET | `/accounts/me/stage-plays/current` | 필요 | 200 / 없으면 204 | 내 진행 중 플레이 |
| P3 | GET | `/accounts/me/stage-plays/{stagePlayId}` | 필요 | 200 | 내 플레이 하나 |
| P4 | POST | `/accounts/me/stage-plays/{stagePlayId}/abandon` | 필요 | 200 | 포기(실패로 끝냄) |
| P5 | GET | `/stage-plays?status=IN_PROGRESS` | 필요 | 200 | 모든 계정의 진행 중 플레이 목록 |
| C1 | PUT | `/accounts/me/stage-plays/{stagePlayId}/checkpoint` | 필요 | 200 | 체크포인트 저장(덮어씀) |
| C2 | GET | `/accounts/me/stage-plays/{stagePlayId}/checkpoint` | 필요 | 200 / 없으면 204 | 체크포인트 받기 |

- `me`는 토큰의 계정입니다. 응답에 `accountId`가 있어 누구의 플레이인지 보입니다.
- 결과 제출 `POST /accounts/me/stage-plays/{stagePlayId}/result`와 결과 다시 받기 `GET` 같은 경로는 [result-api.md](result-api.md)에 있습니다.

## 스테이지 플레이(P1~P4 응답 `data`)

| 필드 | 타입 | 설명 |
|---|---|---|
| `stagePlayId` | string | 스테이지 플레이 ID |
| `accountId` | string | 주인 계정 ID(숫자를 문자열로) |
| `stageId` | string | 스테이지 키 |
| `difficulty` | integer | 난이도. **0 = 난이도 조절 없음(기본)**. 지금은 0만 |
| `waveCount` | integer | 시작 때의 서버 웨이브 수. 결과 검사 기준입니다(마감 사이에 서버 정의가 바뀌어도 그대로) |
| `status` | string | `IN_PROGRESS` · `CLEARED` · `FAILED` · `EXPIRED` |
| `endReason` | string \| null | 끝난 이유. `RESULT`(결과 제출) · `ABANDONED`(포기) · `EXPIRED`(마감 지남). 진행 중이면 `null`(칸은 늘 있음) |
| `startedAt` | string | 시작 시각 |
| `expiresAt` | string | 마감 |
| `endedAt` | string \| null | 끝난 시각. 진행 중이면 `null` |

**상태 규칙**

| 상태 | 언제 | `endReason` |
|---|---|---|
| `IN_PROGRESS` | 시작함 | `null` |
| `CLEARED` | 클리어 결과가 저장됨 | `RESULT` |
| `FAILED` | 실패 결과가 저장됨 / 포기함 | `RESULT` / `ABANDONED` |
| `EXPIRED` | 마감이 지났는데 결과가 없음. 그 플레이를 다시 읽거나 새로 시작할 때 서버가 바꿉니다 | `EXPIRED` |

- 한 방향입니다: `IN_PROGRESS` → 나머지 셋 중 하나. 끝난 플레이는 다시 진행 중이 되지 않습니다.
- 결과를 받을 수 있는 플레이는 `IN_PROGRESS`이면서 마감 전인 것뿐입니다.
- `IN_PROGRESS`에서 벗어나면(결과·포기·만료) 그 플레이의 체크포인트를 지웁니다([C1·C2](#c1c2-체크포인트)).

예시: `examples/stage-play-response.json`

## P1. 시작 — `POST /accounts/me/stage-plays`

| 요청 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `requestId` | string(UUID) | 예 | 다시 보낼 때 **같은 값**. 같은 값이면 처음 플레이를 그대로 돌려줍니다 |
| `stageId` | string | 예 | 고른 스테이지 키(1~64자) |
| `difficulty` | integer | 아니오 | 없으면 0(조절 없음). 지금은 0만 받습니다 |

처리 순서
1. 같은 `requestId`로 시작한 플레이가 있으면 → 그 플레이(201). 단 `stageId`가 다르면 409 `IDEMPOTENCY_KEY_REUSED`
2. 진행 중 플레이가 있으면 → 마감이 지났으면 `EXPIRED`로 바꾸고 계속, 아니면 409 `STAGE_PLAY_IN_PROGRESS`
3. 스테이지 확인 → 없으면 404 `STAGE_NOT_FOUND`, 잠겼으면 403 `STAGE_LOCKED`([stage-api.md](stage-api.md))
4. 발급: ID, 스테이지, 그때의 웨이브 수, 난이도, 마감. 응답 헤더 `Location: /accounts/me/stage-plays/{stagePlayId}`

- 같은 계정이 동시에 두 번 시작해도 진행 중 플레이는 하나만 생깁니다.
- 409 `STAGE_PLAY_IN_PROGRESS`를 받으면 게임은 P2로 진행 중 플레이를 받습니다. 그 플레이의 **보관 결과가 있으면 포기하지 말고 결과부터** 보냅니다. 없으면 P4로 포기한 뒤 다시 P1을 부릅니다. 진행 중 플레이는 로그인 때 [이어하기](#이어하기)에서 이미 묻기 때문에, 이 409는 그 확인이 실패했거나 그 사이 다른 기기에서 새 판을 시작한 경우에만 생깁니다.

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 201 | 시작함(같은 `requestId` 재전송도 201, 같은 내용) | 성공 응답 |
| 400 | 요청 값이 틀림 | `VALIDATION_FAILED`·`INVALID_REQUEST_BODY` |
| 401 | 인증 실패 | auth-api.md 네 코드 |
| 403 | 잠긴 스테이지 | `STAGE_LOCKED` |
| 404 | 없는 스테이지 | `STAGE_NOT_FOUND` |
| 409 | 진행 중 플레이 있음 / 같은 키에 다른 스테이지 | `STAGE_PLAY_IN_PROGRESS` / `IDEMPOTENCY_KEY_REUSED` |
| 503 | MySQL·Redis에 닿지 못함 | `SERVICE_UNAVAILABLE`, `retryable: true` |

예시: `examples/stage-play-start-request.json`, `examples/stage-play-response.json`, `examples/stage-play-error-in-progress.json`

## P2. 내 진행 중 플레이 — `GET /accounts/me/stage-plays/current`

- 있으면 200 + 스테이지 플레이, 없으면 **204**(본문 없음).
- 마감이 지난 진행 중 플레이는 이때 `EXPIRED`로 바뀌고 204가 됩니다.
- 쓰는 곳: 로그인 직후(보관 결과 재전송이 끝난 뒤, [이어하기](#이어하기)), P1에서 409를 받았을 때.

예시: `examples/stage-play-current-response.json`(200). 204는 본문이 없습니다.

## P3. 내 플레이 하나 — `GET /accounts/me/stage-plays/{stagePlayId}`

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 찾음(마감이 지난 진행 중이면 `EXPIRED`로 바뀐 상태) | 스테이지 플레이 |
| 400 | `stagePlayId`가 UUID 모양이 아님 | `VALIDATION_FAILED`(`errors[0].field = "stagePlayId"`) |
| 404 | 없는 플레이, **남의 플레이** | `STAGE_PLAY_NOT_FOUND` |

## P4. 포기 — `POST /accounts/me/stage-plays/{stagePlayId}/abandon`

- 본문 없음. 진행 중 플레이를 `FAILED` + `endReason: ABANDONED`로 끝냅니다. **결과·보상은 남기지 않습니다.** 체크포인트도 지웁니다.
- 이미 포기한 플레이에 다시 오면 200(같은 응답). 결과·만료로 끝난 플레이면 409 `STAGE_PLAY_NOT_IN_PROGRESS`.

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 포기함(재전송 포함) | 스테이지 플레이 |
| 400 | `stagePlayId`가 UUID 모양이 아님 | `VALIDATION_FAILED` |
| 404 | 없는 플레이, 남의 플레이 | `STAGE_PLAY_NOT_FOUND` |
| 409 | 이미 결과·만료로 끝남 | `STAGE_PLAY_NOT_IN_PROGRESS` |

예시: `examples/stage-play-abandon-response.json`, `examples/stage-play-error-not-in-progress.json`

## P5. 모든 계정의 진행 중 플레이 — `GET /stage-plays?status=IN_PROGRESS`

- 로그인한 누구나 부를 수 있습니다. `status`는 지금 `IN_PROGRESS`만 받고, 없으면 `IN_PROGRESS`입니다(다른 값은 400 `VALIDATION_FAILED`, `errors[0].field = "status"`).
- 최근 시작 순, 최대 50개. 마감이 지난 것은 빠집니다.

| 응답 `data` 필드 | 타입 | 설명 |
|---|---|---|
| `items` | array | 진행 중 플레이 |
| `items[].stagePlayId` | string | |
| `items[].accountId` | string | |
| `items[].nickname` | string | 계정 닉네임 |
| `items[].stageId` | string | |
| `items[].startedAt` | string | |

## C1·C2. 체크포인트

진행 중인 플레이 하나의 **마지막 체크포인트**를 서버가 들고 있습니다. 게임은 웨이브를 클리어할 때마다 올리고(C1), 이어하기 때 받습니다(C2).

- 판 안 값 `state`는 **게임이 정하는 JSON 객체**입니다. 서버는 객체인지와 크기만 확인하고 내용은 읽지 않은 채 그대로 저장·돌려줍니다. 그래서 게임이 판 안 값의 칸을 바꿔도 서버는 바뀌지 않습니다(칸을 바꾸면 게임이 `contentVersion`을 올립니다).
- 플레이당 하나이고 **덮어씁니다.** `requestId`를 받지 않습니다. 같은 요청이 두 번 와도 결과가 같고, 웨이브가 뒤로 가는 저장만 막습니다.
- 저장소는 Redis `pw01:play-checkpoint:<stagePlayId>`이고, 플레이 마감이 지나면 사라집니다([redis-keys.md](redis-keys.md#키-목록)).
- **판이 끝나면 지웁니다**: 결과 저장(R1), 포기(P4), 만료(`EXPIRED`로 바뀔 때). 지우기에 실패해도 결과·포기는 성공으로 처리합니다(마감 때 사라짐).

### C1. 저장 — `PUT /accounts/me/stage-plays/{stagePlayId}/checkpoint`

| 요청 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `contentVersion` | integer | 예 | 판 안 값 모양의 버전(1 이상). 게임이 정합니다. 이어하기 때 게임의 지금 버전과 다르면 게임은 체크포인트를 쓰지 않고 처음부터 합니다 |
| `clearedWave` | integer | 예 | 방금 클리어한 웨이브 번호. **1 이상, 플레이의 `waveCount` 미만**(마지막 웨이브를 클리어하면 체크포인트 대신 결과를 냅니다) |
| `elapsedSeconds` | number | 예 | 그때까지의 플레이 시간(초, 0 이상). 이어한 판의 결과 `playTimeSeconds` = 이 값 + 이어한 뒤 시간 |
| `state` | object | 예 | 판 안 값. 직렬화한 크기가 설정 값(`pw01.play-checkpoint.max-state-size`, 처음 64KB) 이하 |

`state` 안(참고, 게임이 정함. 지금 게임 `contentVersion` 1의 모양)

| 칸 | 내용 |
|---|---|
| `gold` | 골드 |
| `items[]` | `itemPath`(아이템 에셋 경로), `quantity` |
| `upgrades[]` | `upgradeId`(강화 태그), `upgradePath`(강화 에셋 경로), `level` |
| `attributes` | `currentHealth`, `currentStamina`, `currentBalance` |
| `stageTimeSeconds` | 스테이지 시작 기준 경과 시간(판 통계의 웨이브 시각을 잇는 데 씀) |
| `stageRecord` | 판 통계(합계·웨이브·구매·사망·적) |

처리 순서
1. 내 플레이인가 → 아니면 404 `STAGE_PLAY_NOT_FOUND`(남의 플레이도 404)
2. 진행 중인가 → 마감이 지났으면 `EXPIRED`로 바꾸고 409 `STAGE_PLAY_EXPIRED`, 끝난 플레이면 409 `STAGE_PLAY_NOT_IN_PROGRESS`
3. 요청 값 → 틀리면 400 `VALIDATION_FAILED`(`clearedWave` 범위, `elapsedSeconds` < 0, `contentVersion` < 1, `state`가 객체가 아니거나 너무 큼)
4. 저장된 체크포인트의 `clearedWave`보다 **작으면** 409 `CHECKPOINT_OUT_OF_ORDER`. **같으면 덮어씁니다**(같은 요청을 다시 보낸 경우)
5. 저장. 4와 5는 한 번에 합니다(Redis 스크립트). 만료 = 플레이 `expiresAt`까지

| 응답 `data` 필드 | 타입 | 설명 |
|---|---|---|
| `stagePlayId` | string | |
| `clearedWave` | integer | 저장한 값 |
| `contentVersion` | integer | |
| `elapsedSeconds` | number | |
| `savedAt` | string | 서버가 저장한 시각 |

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 저장함(덮어씀 포함) | 성공 응답(`state`는 돌려주지 않음) |
| 400 | 요청 값·`stagePlayId` 모양이 틀림 | `VALIDATION_FAILED`·`INVALID_REQUEST_BODY` |
| 401 | 인증 실패(다른 곳 로그인으로 쫓겨난 기기의 늦은 저장도 여기서 막힘) | auth-api.md 네 코드 |
| 404 | 없는 플레이, 남의 플레이 | `STAGE_PLAY_NOT_FOUND` |
| 409 | 마감 지남 / 끝난 플레이 / 웨이브가 뒤로 감 | `STAGE_PLAY_EXPIRED` / `STAGE_PLAY_NOT_IN_PROGRESS` / `CHECKPOINT_OUT_OF_ORDER` |
| 503 | MySQL·Redis에 닿지 못함 | `SERVICE_UNAVAILABLE`, `retryable: true` |

- 게임은 C1이 실패해도 판을 멈추지 않고, 체크포인트를 **디스크에 보관하지 않습니다**. 다음 웨이브를 클리어할 때 새로 올립니다. 이어하기는 서버에 마지막으로 저장된 체크포인트로 합니다.

예시: `examples/stage-play-checkpoint-put-request.json`, `examples/stage-play-checkpoint-put-response.json`, `examples/stage-play-error-checkpoint-out-of-order.json`

### C2. 받기 — `GET /accounts/me/stage-plays/{stagePlayId}/checkpoint`

| 응답 `data` 필드 | 타입 | 설명 |
|---|---|---|
| `stagePlayId` | string | |
| `clearedWave` | integer | |
| `contentVersion` | integer | |
| `elapsedSeconds` | number | |
| `savedAt` | string | |
| `state` | object | C1로 올린 그대로 |

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 있음 | 성공 응답 |
| 204 | 없음: 한 번도 올리지 않음(1웨이브 도중 끊김), 판이 끝나 지움, 마감이 지나 사라짐 | 없음 |
| 400 | `stagePlayId`가 UUID 모양이 아님 | `VALIDATION_FAILED` |
| 404 | 없는 플레이, 남의 플레이 | `STAGE_PLAY_NOT_FOUND` |
| 503 | Redis에 닿지 못함 | `SERVICE_UNAVAILABLE`, `retryable: true` |

예시: `examples/stage-play-checkpoint-response.json`(200). 204는 본문이 없습니다.

## 이어하기

판 도중 게임이 꺼지거나(강제 종료·크래시) 로그인 상태가 끝나면(다른 곳 로그인 등) 서버의 플레이는 `IN_PROGRESS`로 남습니다. 다음 로그인 때 게임이 그 플레이를 이어 할지 묻습니다.

**로그인 뒤 순서**

1. 로그인 성공 → 계정 값 적용
2. 보관 결과 재전송([README.md 재전송 규칙](README.md#재전송-규칙))이 끝날 때까지 기다림
3. P2
   - 204: 메인메뉴
   - 200이고 그 플레이의 보관 결과가 아직 디스크에 있음(재전송이 재시도 가능한 실패로 남음): 묻지 않고 메인메뉴. 결과가 먼저입니다
   - 200: 4로
   - 실패(연결 실패·5xx): 묻지 않고 메인메뉴. 다음 시작의 409 처리(P1)가 정리합니다
4. C2
   - 200이고 `contentVersion`이 게임의 지금 버전과 같음: **체크포인트에서 이어하기**
   - 204, 버전이 다름, 실패: **처음부터 이어하기**
5. "진행 중인 스테이지가 있습니다. 이어하시겠습니까?" → [이어하기] / [포기]
   - 스테이지 이름, 남은 시간(`expiresAt` − 지금)
   - 체크포인트에서: "〔`clearedWave` + 1〕웨이브부터 이어서 합니다" + 골드·체력 요약(`state`에서)
   - 처음부터: "처음(1웨이브)부터 다시 시작합니다"

**선택별 처리**

| 선택 | 게임 | 서버 |
|---|---|---|
| 이어하기(체크포인트에서) | **P1을 부르지 않고** 같은 `stagePlayId`로 그 스테이지를 엽니다. `state`의 판 안 값을 넣고 **`clearedWave` + 1 웨이브 앞 쉬는 시간부터** 시작합니다. 이어서 클리어하는 웨이브마다 C1을 계속 올립니다 | 바뀌는 것 없음 |
| 이어하기(처음부터) | **P1을 부르지 않고** 같은 `stagePlayId`로 **처음(1웨이브)부터** 다시 합니다. 판 안 값은 처음 값입니다 | 바뀌는 것 없음 |
| 포기 | P4 → 메인메뉴. 200·404·409는 메인메뉴, 연결 실패·5xx는 안내 후 메인메뉴(다음 로그인 때 다시 묻습니다) | `FAILED` + `ABANDONED`, 체크포인트 지움 |

**규칙**

- 결과는 **같은 `stagePlayId`**로 냅니다. 결과 검사의 경과 시간과 마감은 원래 `startedAt`·`expiresAt` 기준이고, 이어한 판의 플레이 시간은 늘 그보다 짧으므로 검사를 통과합니다.
- 이어한 판의 `playTimeSeconds`: 체크포인트에서 이었으면 `elapsedSeconds` + 이어한 뒤 시간, 처음부터면 다시 한 판의 시간. 랭킹도 이 값으로 매깁니다.
- 이어한 판의 `reachedWave`·통계는 실제로 도달한 웨이브와 판 전체 값입니다(체크포인트에서 이었으면 `state.stageRecord`부터 이어서 셈).
- 이어하는 횟수는 제한하지 않습니다(마감까지). 웨이브 도중 꺼서 직전 체크포인트로 다시 하는 것도 막지 않습니다.
- 판 도중 사용자가 스스로 나가는 메뉴(일시정지 → 나가기)는 P4를 보냅니다. 앱 종료·세션 종료는 P4를 보내지 않습니다(다음 로그인 때 묻습니다).
- 이어한 판 도중 마감이 지나면 결과는 409 `STAGE_PLAY_EXPIRED`입니다(보통 판과 같음).
- 체크포인트는 웨이브 **클리어 직후** 한 번 올립니다. 쉬는 시간에 산 아이템·강화는 다음 웨이브를 클리어할 때 함께 올라갑니다(그 전에 꺼지면 사기 전 값으로 돌아감).

흐름도: [docs/flows/play-checkpoint.md](../flows/play-checkpoint.md)

## 오류

이 명세만의 오류 코드입니다. 스테이지 오류는 [stage-api.md 오류](stage-api.md#오류), 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `STAGE_PLAY_NOT_FOUND` | 404 | 없는 플레이, 남의 플레이(결과 제출 포함) | false | 안내 후 메인메뉴(버그) |
| `STAGE_PLAY_IN_PROGRESS` | 409 | 진행 중 플레이가 있는데 시작함 | false | P2 → 보관 결과가 있으면 결과 제출, 없으면 P4 → P1 |
| `STAGE_PLAY_NOT_IN_PROGRESS` | 409 | 끝난 플레이를 포기함, 포기한 플레이에 결과를 냄 | false | 다시 보내지 않음, 메인메뉴 |
| `STAGE_PLAY_EXPIRED` | 409 | 마감이 지난 플레이에 결과를 냄 | false | 다시 보내지 않음, 안내 후 메인메뉴 |
| `IDEMPOTENCY_KEY_REUSED` | 409 | 같은 `requestId`에 다른 `stageId` | false | 버그. 새 `requestId`로 다시 시작 |
| `CHECKPOINT_OUT_OF_ORDER` | 409 | 저장된 체크포인트보다 작은 `clearedWave`를 올림 | false | 다시 보내지 않음. 판은 그대로 진행(버그 또는 늦게 도착한 요청) |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-09 | 초안: 판 시작(`POST /runs`)을 계정 밑 스테이지 플레이로 바꿈. P1 시작, P2 내 진행 중, P3 하나 조회, P4 포기, P5 모든 계정 진행 중 목록, 상태 4개와 `endReason`, 계정당 진행 중 하나, 오류 다섯 개 |
| v1.1 | 2026-10-13 | 이어하기(1차) 절: 로그인 뒤 재전송 → P2 → 이어하기(같은 `stagePlayId`, 처음부터)/포기(P4). P1 409·P2 "쓰는 곳" 설명 고침. P2·P4 예시 추가. 서버 동작·칸은 그대로 |
| v1.2 | 2026-10-13 | 체크포인트 C1 저장(`PUT`, 덮어씀, `clearedWave` 범위·순서 검사, `state`는 게임이 정하는 JSON 객체)·C2 받기(`GET`, 없으면 204). 판이 끝나면(R1·P4·만료) 체크포인트 지움. 오류 `CHECKPOINT_OUT_OF_ORDER`. "이어하기" 절: P2 → C2 → 체크포인트에서(다음 웨이브 쉬는 시간부터)/처음부터, 이어한 판의 `playTimeSeconds` = `elapsedSeconds` + 이어한 뒤 |
