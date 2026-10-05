# 예시 API (Example API) — 학습용

> 버전: v1 · 상태: 초안 · 호출: 게임 클라이언트(UE)·API 도구 → 웹서버

**학습용 예시입니다. 실제 기능이 아닙니다.** 명세를 쓰는 법과, 웹서버에서 요청 하나가 Controller → Service → Repository → DB를 지나 응답이 되는 흐름을 보여 주려고 둡니다. 첫 실제 API(S1, 로그인)가 병합되면 웹서버의 예시 코드·테이블과 함께 이 문서와 예시 JSON을 지웁니다.

- 웹서버 쪽 따라 하기: PW01WebServer `docs/guides/example-api.md`
- 경로·시각·오류 응답 형식: [README.md 공통 규칙](README.md#공통-규칙)

## 엔드포인트

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/api/v1/examples` | 예시 만들기 |
| GET | `/api/v1/examples/{id}` | 예시 하나 조회 |

## 인증

없음 (학습용)

## 예시 만들기 — `POST /api/v1/examples`

요청 (길이 제한은 예시 값입니다)

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `name` | string | 예 | 공백만으로는 안 됨, 50자 이하. 같은 이름은 하나만 만들 수 있음 |
| `description` | string | 아니오 | 200자 이하 |

예시: `examples/example-create-request.json`

응답

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 201 | 만듦. `Location` 헤더에 새 예시의 경로 | 예시 본문(아래 표) |
| 400 | 검증 실패, 읽을 수 없는 본문, 모르는 필드 | 오류 응답(`VALIDATION_FAILED`, `INVALID_REQUEST_BODY`) |
| 409 | 같은 이름이 이미 있음 | 오류 응답(`EXAMPLE_NAME_DUPLICATED`) |

예시 본문

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | number (정수) | 서버가 만든 식별자 |
| `name` | string | |
| `description` | string 또는 null | 보내지 않았으면 null |
| `createdAt` | string | 만든 시각(UTC) |

예시: `examples/example-create-response.json`, 검증 실패 `examples/example-error-validation.json`

## 예시 조회 — `GET /api/v1/examples/{id}`

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 찾음 | 예시 본문(위 표) |
| 400 | `id`가 정수가 아님 | 오류 응답(`VALIDATION_FAILED`) |
| 404 | 없음 | 오류 응답(`EXAMPLE_NOT_FOUND`) |

예시: `examples/example-error-not-found.json`

## 오류

| 코드 | 상황 | 게임 쪽 처리 |
|---|---|---|
| `EXAMPLE_NOT_FOUND` | 없는 `id`로 조회 | 학습용이라 없음 |
| `EXAMPLE_NAME_DUPLICATED` | 이미 있는 이름으로 만들기 | 학습용이라 없음 |

공통 오류 코드는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-05 | 학습용 예시 명세 작성 |
