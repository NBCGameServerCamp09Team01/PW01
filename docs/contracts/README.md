# 명세(Contracts) 목록

게임(ProjectWarrior)과 웹서버(PW01WebServer)가 함께 지키는 약속입니다. **코드보다 명세를 먼저 고칩니다.**

| 명세 | 현재 버전 | 상태 | 게임 담당 | 웹서버 담당 |
|---|---|---|---|---|
| [auth-api.md](auth-api.md) | v1 | 초안 | Juunnmmoo | Robbie (리뷰: Sang-Hyun-Kim) |
| [account-api.md](account-api.md) | v1 | 초안 | Juunnmmoo | Robbie (리뷰: Sang-Hyun-Kim) |
| [result-api.md](result-api.md) | v0 | 작성 전 | Juunnmmoo | Robbie |
| [stage-api.md](stage-api.md) | v1.1 | 초안 | Sang-Hyun-Kim | Sang-Hyun-Kim (리뷰: Robbie) |
| [stage-play-api.md](stage-play-api.md) | v1 | 초안 | Robbie | Sang-Hyun-Kim (리뷰: Robbie) |
| [realtime-api.md](realtime-api.md) | v1 | 초안 | Juunnmmoo | Juunnmmoo (리뷰: Sang-Hyun-Kim 배정) |
| [redis-keys.md](redis-keys.md) | v1.1 | 합의 | — | Sang-Hyun-Kim (리뷰: Robbie) |
| [example-api.md](example-api.md) | v1 | 초안 | — | Sang-Hyun-Kim (리뷰: Robbie) |

- 상태: `작성 전` → `초안` → `합의` → `구현됨`
- 요청·응답 JSON 예시는 [examples/](examples/) 에 둡니다.
- `example-api.md`는 학습용 예시입니다. 첫 실제 API(S1)가 병합되면 웹서버 예시 코드와 함께 지웁니다. 예시는 옛 경로(`/api/v1/examples`)를 그대로 씁니다(아래 경로 규칙보다 먼저 만들어짐).

## 공통 규칙

> 상태: 합의(10/7 저녁, 성공 응답·요청 번호·`retryable`·`retryAfterSeconds` 추가). 모든 API에 적용합니다. 바꿀 때는 이 절을 먼저 고치고 게임·웹서버 담당 모두에게 리뷰를 받습니다.

| 항목 | 규칙 |
|---|---|
| 경로 | 기능 이름부터 바로 씁니다(예: `/auth/login`, `/accounts/me`). 경로에 `/api`·버전(`/v1`)을 넣지 않습니다. 호환되지 않는 변경을 경로로 나눌지는 〔정할 것〕입니다 |
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

- 학습용 예시 API(`/api/v1/examples`)는 이 규칙보다 먼저 만들어 `data`로 감싸지 않습니다. S1 병합 때 지웁니다.

### 오류 응답

```json
{
  "code": "VALIDATION_FAILED",
  "message": "요청 값이 올바르지 않습니다.",
  "path": "/api/v1/examples",
  "retryable": false,
  "errors": [
    { "field": "name", "message": "이름을 입력해야 합니다." }
  ]
}
```

- 위 예시의 `path`는 학습용 예시 API의 옛 경로입니다.

| 필드 | 설명 |
|---|---|
| `code` | 기계가 읽는 오류 코드(대문자와 `_`). 게임은 이 값으로 화면 문구를 고릅니다 |
| `message` | 사람이 읽는 설명 |
| `path` | 요청 경로 |
| `retryable` | 같은 요청을 다시 보내도 되는지. 서버 쪽 문제(`500`·`503`)는 `true`, 나머지는 `false`. 게임은 `true`일 때만 정한 횟수만큼 다시 보냅니다 |
| `errors` | 검증 오류(`VALIDATION_FAILED`)일 때만 붙습니다. 필드별 오류 전부 |
| `retryAfterSeconds` | `429`일 때만 붙습니다. 다시 시도할 수 있기까지 남은 초. 같은 값이 표준 헤더 `Retry-After`에도 붙습니다 |

### 오류 코드

| 코드 | HTTP | 상황 |
|---|---|---|
| `VALIDATION_FAILED` | 400 | 요청 값(본문 필드, 경로·쿼리 값) 검증 실패 |
| `INVALID_REQUEST_BODY` | 400 | JSON을 읽을 수 없음, 모르는 필드, 타입이 맞지 않음 |
| `NOT_FOUND` | 404 | 없는 경로 |
| `METHOD_NOT_ALLOWED` | 405 | 허용되지 않은 HTTP 메서드 |
| `INTERNAL_ERROR` | 500 | 서버 내부 오류. 원인은 서버 로그에만 남깁니다 |
| `SERVICE_UNAVAILABLE` | 503 | MySQL·Redis에 닿지 못함. 잠시 뒤 다시 보내면 될 수 있습니다 |

- 위 표에 없는 HTTP 오류는 상태 이름을 코드로 씁니다(예: 415 → `UNSUPPORTED_MEDIA_TYPE`).
- 기능별 오류 코드(예: `EXAMPLE_NOT_FOUND`)는 각 명세의 "오류" 표에 적습니다.

## 변경 절차

1. `docs/…` 브랜치에서 명세를 고칩니다. 버전을 올리고 문서 아래 "변경 이력"에 한 줄 적습니다.
2. 게임·웹서버 담당자 모두에게 PR 리뷰를 받습니다.
3. 병합 후 각 저장소에서 구현합니다. 구현이 끝나면 위 표의 상태를 `구현됨`으로 바꿉니다.

## 버전 규칙

- 호환되는 추가(필드 추가 등): `v1` → `v1.1`
- 호환되지 않는 변경(필드 삭제·이름 변경·의미 변경): `v1` → `v2`. 양쪽이 동시에 배포되어야 합니다.
