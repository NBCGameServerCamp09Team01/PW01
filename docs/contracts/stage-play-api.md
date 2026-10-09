# 스테이지 플레이 API (Stage Play API)

> 버전: v1 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Robbie · 웹서버 담당: Sang-Hyun-Kim (리뷰: Robbie)

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

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| P1 | POST | `/accounts/me/stage-plays` | 필요 | 201 + `Location` | 스테이지 플레이 시작 |
| P2 | GET | `/accounts/me/stage-plays/current` | 필요 | 200 / 없으면 204 | 내 진행 중 플레이 |
| P3 | GET | `/accounts/me/stage-plays/{stagePlayId}` | 필요 | 200 | 내 플레이 하나 |
| P4 | POST | `/accounts/me/stage-plays/{stagePlayId}/abandon` | 필요 | 200 | 포기(실패로 끝냄) |
| P5 | GET | `/stage-plays?status=IN_PROGRESS` | 필요 | 200 | 모든 계정의 진행 중 플레이 목록 |

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
- 409 `STAGE_PLAY_IN_PROGRESS`를 받으면 게임은 P2로 진행 중 플레이를 받습니다. 그 플레이의 **보관 결과가 있으면 포기하지 말고 결과부터** 보냅니다. 없으면 P4로 포기한 뒤 다시 P1을 부릅니다. 나중에 이어하기가 생기면 이 자리가 "이어하기 / 새로 하기" 선택이 됩니다.

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
- 쓰는 곳: 재접속·로그인 직후, P1에서 409를 받았을 때.

## P3. 내 플레이 하나 — `GET /accounts/me/stage-plays/{stagePlayId}`

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 찾음(마감이 지난 진행 중이면 `EXPIRED`로 바뀐 상태) | 스테이지 플레이 |
| 400 | `stagePlayId`가 UUID 모양이 아님 | `VALIDATION_FAILED`(`errors[0].field = "stagePlayId"`) |
| 404 | 없는 플레이, **남의 플레이** | `STAGE_PLAY_NOT_FOUND` |

## P4. 포기 — `POST /accounts/me/stage-plays/{stagePlayId}/abandon`

- 본문 없음. 진행 중 플레이를 `FAILED` + `endReason: ABANDONED`로 끝냅니다. **결과·보상은 남기지 않습니다.**
- 이미 포기한 플레이에 다시 오면 200(같은 응답). 결과·만료로 끝난 플레이면 409 `STAGE_PLAY_NOT_IN_PROGRESS`.

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 포기함(재전송 포함) | 스테이지 플레이 |
| 400 | `stagePlayId`가 UUID 모양이 아님 | `VALIDATION_FAILED` |
| 404 | 없는 플레이, 남의 플레이 | `STAGE_PLAY_NOT_FOUND` |
| 409 | 이미 결과·만료로 끝남 | `STAGE_PLAY_NOT_IN_PROGRESS` |

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

## 오류

이 명세만의 오류 코드입니다. 스테이지 오류는 [stage-api.md 오류](stage-api.md#오류), 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `STAGE_PLAY_NOT_FOUND` | 404 | 없는 플레이, 남의 플레이(결과 제출 포함) | false | 안내 후 메인메뉴(버그) |
| `STAGE_PLAY_IN_PROGRESS` | 409 | 진행 중 플레이가 있는데 시작함 | false | P2 → 보관 결과가 있으면 결과 제출, 없으면 P4 → P1 |
| `STAGE_PLAY_NOT_IN_PROGRESS` | 409 | 끝난 플레이를 포기함, 포기한 플레이에 결과를 냄 | false | 다시 보내지 않음, 메인메뉴 |
| `STAGE_PLAY_EXPIRED` | 409 | 마감이 지난 플레이에 결과를 냄 | false | 다시 보내지 않음, 안내 후 메인메뉴 |
| `IDEMPOTENCY_KEY_REUSED` | 409 | 같은 `requestId`에 다른 `stageId` | false | 버그. 새 `requestId`로 다시 시작 |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-09 | 초안: 판 시작(`POST /runs`)을 계정 밑 스테이지 플레이로 바꿈. P1 시작, P2 내 진행 중, P3 하나 조회, P4 포기, P5 모든 계정 진행 중 목록, 상태 4개와 `endReason`, 계정당 진행 중 하나, 오류 다섯 개 |
