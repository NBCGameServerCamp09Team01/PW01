# 인증 API (Auth API)

> 버전: v1 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Juunnmmoo · 웹서버 담당: Robbie (리뷰: Sang-Hyun-Kim)

첫 흐름(S1)의 회원가입·로그인·접속 점검·로그아웃입니다. 메인화면 값 조회는 [account-api.md](account-api.md)에 있습니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- Redis 키·스크립트·명령 순서: [redis-keys.md](redis-keys.md) v1
- 아래 "응답 `data`" 표는 성공 응답의 `data` 안쪽 모양입니다. 실제 본문은 `{ "data": { … }, "meta": { "requestId": "…" } }`입니다.

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| A1 | POST | `/auth/signup` | 없음 | 201 | 회원가입 |
| A2 | POST | `/auth/login` | 없음 | 200 | 로그인. 토큰과 메인화면 값을 받음 |
| A4 | POST | `/auth/heartbeat` | 필요 | 200 | 접속 점검(임시). 세션을 연장 |
| A5 | POST | `/auth/logout` | 필요 | 204 | 로그아웃 |

## 인증

불투명 토큰 + Redis 세션입니다. JWT가 아닙니다.

- 로그인 응답의 `data.accessToken`을 인증이 필요한 요청마다 헤더에 싣습니다: `Authorization: Bearer <accessToken>`
- 토큰은 32바이트 난수를 URL-safe Base64(패딩 없음)로 쓴 **43자**입니다. 게임은 토큰 안을 읽지 않고 그대로 보냅니다. 토큰은 로그인할 때만 바뀝니다.
- 서버는 토큰 원문을 저장하지 않습니다. Redis에는 SHA-256 해시만 둡니다.
- 인증이 필요한 경로: `/accounts/**`, `/auth/heartbeat`, `/auth/logout`

### 세션 수명과 연장

| 항목 | 규칙 |
|---|---|
| 수명 | 10분(설정 `pw01.auth.session.ttl`) |
| 연장 | **인증이 필요한 요청이 인증을 통과할 때마다** 그 시점부터 다시 10분이 됩니다. 접속 점검(A4)만이 아니라 `/accounts/me`도 연장합니다 |
| 만료 시각 | 로그인 응답과 접속 점검 응답의 `sessionExpiresAt`. 그 뒤 다른 인증 요청을 보내면 더 늘어나지만, 그 응답에는 만료 시각이 없습니다 |
| 만료되면 | 다음 인증 요청이 401 `AUTH_SESSION_NOT_FOUND`. 다시 로그인합니다 |
| 플레이 중 | 스테이지 중에는 다른 HTTP 요청이 없으므로 **접속 점검을 계속 보내야** 세션이 살아 있습니다. 값의 관계: **세션 수명 > 점검 간격 × 허용 연속 실패 횟수**([redis-keys.md 값의 관계](redis-keys.md#값의-관계)) |
| 나중 | UE WebSocket이 붙으면 연장은 WebSocket Ping/Pong이 맡고 A4는 지웁니다 |

### 계정당 세션 하나

- 같은 계정으로 다른 곳에서 로그인하면 **새 로그인이 이깁니다**. 이전 토큰은 다음 요청에서 401 `AUTH_SESSION_REPLACED`입니다.
- 이전 토큰이 `AUTH_SESSION_REPLACED`를 받는 것은 이전 세션이 끝날 때까지(마지막 연장부터 10분)입니다. 그 뒤에는 `AUTH_SESSION_NOT_FOUND`입니다.
- 계정을 제재할 때는 그 계정의 세션을 끊습니다(redis-keys v1 "제재를 손으로 걸 때", 제재 기능은 아직 없음). 다음 인증 요청은 401 `AUTH_SESSION_NOT_FOUND`이고, 다시 로그인하면 403 `ACCOUNT_SUSPENDED`입니다.

### 인증 확인 순서와 실패 코드

모두 401입니다. 앞에서 걸리면 뒤는 보지 않습니다. 인증에 실패하면 세션을 연장하지 않습니다.

| 순서 | 확인 | 실패 코드 | 게임 쪽 처리(제안) |
|---|---|---|---|
| 1 | 헤더가 있고 `Bearer `로 시작 | `AUTH_TOKEN_MISSING` | 로그인 화면 |
| 2 | 토큰이 43자, `A-Z a-z 0-9 - _`만 | `AUTH_TOKEN_INVALID` | 로그인 화면 |
| 3 | 세션이 있음 | `AUTH_SESSION_NOT_FOUND` | 로그인 화면(로그아웃·만료) |
| 4 | 그 계정의 지금 세션이 이 토큰 | `AUTH_SESSION_REPLACED` | "다른 곳에서 로그인" 안내 후 타이틀 |

## A1. 회원가입 — `POST /auth/signup`

요청

| 필드 | 타입 | 필수 | 규칙 |
|---|---|---|---|
| `loginId` | string | 예 | 영문 대소문자·숫자 4~20자. **대소문자를 구분**하고 입력 그대로 저장합니다(`Warrior01`과 `warrior01`은 다른 아이디) |
| `password` | string | 예 | 8자 이상, UTF-8 72바이트 이하(BCrypt 한도. 한글은 24자까지) |
| `nickname` | string | 예 | 한글·영문·숫자 2~20자, 가운데 공백 가능, 앞뒤 공백 불가. 대소문자만 다르면 같은 닉네임 |
| `email` | string 또는 null | 아니오 | 254자 이하, 형식 `이름@도메인.최상위`. 보내지 않거나 null이면 없음(빈 문자열은 400). 유일하지 않음 |

예시: `examples/auth-signup-request.json`

응답

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 201 | 가입함. 헤더 `Location: /accounts/me` | 성공 응답, `data`는 아래 표 |
| 400 | 칸 규칙 위반, 모르는 필드 | 오류 응답(`VALIDATION_FAILED`, `INVALID_REQUEST_BODY`) |
| 409 | 아이디 또는 닉네임 중복 | 오류 응답(`ACCOUNT_LOGIN_ID_DUPLICATED`, `ACCOUNT_NICKNAME_DUPLICATED`) |
| 503 | MySQL에 닿지 못함 | 오류 응답(`SERVICE_UNAVAILABLE`, `retryable: true`) |

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `accountId` | string | 계정 ID(숫자를 문자열로) |
| `loginId` | string | 저장된 아이디(입력 그대로) |
| `nickname` | string | |
| `createdAt` | string | 가입 시각(UTC) |

- 가입은 로그인이 아닙니다. 토큰을 주지 않으므로 이어서 A2를 부릅니다.
- 계정과 함께 진행 행(레벨 1, 경험치 0, 스탯 포인트 0, `version` 0)이 만들어집니다.

예시: `examples/auth-signup-response.json`

## A2. 로그인 — `POST /auth/login`

요청

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `loginId` | string | 예 | 비어 있으면 400. 형식이 틀리면 400이 아니라 아래의 401(아이디가 있는지 밖에서 알 수 없게) |
| `password` | string | 예 | 비어 있으면 400 |

예시: `examples/auth-login-request.json`

판단 순서

| 순서 | 상황 | 응답 | 실패를 셈 |
|---|---|---|---|
| 1 | 아이디 형식이 틀림 | 401 `AUTH_INVALID_CREDENTIALS` (DB·Redis를 보지 않음) | 아니오 |
| 2 | 잠겨 있음 | 429 `AUTH_LOGIN_LOCKED` (비밀번호를 보지 않음) | 아니오 |
| 3 | 아이디 없음 또는 비밀번호 틀림 | 401 `AUTH_INVALID_CREDENTIALS` (두 경우 코드·문구가 같음) | 예 |
| 3' | 그 실패로 허용 횟수(5번)에 닿음 | 429 `AUTH_LOGIN_LOCKED` | 예 |
| 4 | 비밀번호는 맞지만 제재 계정(`SUSPENDED`) | 403 `ACCOUNT_SUSPENDED`, 세션 없음 | 아니오 |
| 5 | 성공 | 200. 메인화면 값을 읽고 → 실패 기록을 지우고 → 세션을 만듦 | — |

- 잠김: 첫 실패부터 1분 안에 5번 틀리면 **5번째 응답부터** 1분 잠깁니다(설정 `pw01.auth.login-fail.*`). 잠긴 동안은 맞는 비밀번호도 429입니다.
- 실패는 아이디(입력 그대로)마다 셉니다. `Warrior01`과 `WARRIOR01`은 따로 셉니다.
- 429 본문에는 `retryAfterSeconds`(남은 잠김 초)가 붙고, 같은 값이 `Retry-After` 헤더로도 나갑니다. `retryable`은 `false`입니다(시간이 지나야 풀림).
- 5에서 메인화면 값을 먼저 읽는 이유: 읽기가 실패하면(500·503) 세션을 만들지 않습니다. 쓸 수 없는 세션이 남지 않습니다.
- 새로 로그인하면 같은 계정의 이전 토큰은 `AUTH_SESSION_REPLACED`가 됩니다([계정당 세션 하나](#계정당-세션-하나)).

응답

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 로그인함 | 성공 응답, `data`는 아래 표 |
| 400 | 빈 값, 모르는 필드 | 오류 응답(`VALIDATION_FAILED`, `INVALID_REQUEST_BODY`) |
| 401 | 아이디·비밀번호가 맞지 않음 | 오류 응답(`AUTH_INVALID_CREDENTIALS`) |
| 403 | 제재 계정 | 오류 응답(`ACCOUNT_SUSPENDED`) |
| 429 | 잠김 | 오류 응답(`AUTH_LOGIN_LOCKED`) + `retryAfterSeconds`, 헤더 `Retry-After` |
| 503 | MySQL·Redis에 닿지 못함 | 오류 응답(`SERVICE_UNAVAILABLE`, `retryable: true`) |

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `accessToken` | string | 43자 토큰. 인증이 필요한 요청의 `Authorization: Bearer` 뒤에 씁니다 |
| `tokenType` | string | 늘 `"Bearer"` |
| `sessionExpiresAt` | string | 세션 만료 시각(UTC). A4 응답과 같은 칸 |
| `account` | object | 메인화면 값. [account-api.md](account-api.md)의 계정 스냅샷과 같은 모양 |

예시: `examples/auth-login-response.json`, 잠김 `examples/auth-error-login-locked.json`

## A4. 접속 점검 (임시) — `POST /auth/heartbeat`

**임시 API입니다.** UE WebSocket이 붙으면 WebSocket Ping/Pong으로 옮기고 지웁니다. 로그인해 있는 동안(메인메뉴·스테이지 모두) 정한 간격마다 부릅니다.

- 요청 본문: 없음
- 연장은 인증 확인을 통과할 때 일어납니다. 이 API는 늘어난 만료 시각을 돌려줍니다([세션 수명과 연장](#세션-수명과-연장)).

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 연장함 | 성공 응답, `data`는 `{ "sessionExpiresAt": "<UTC 시각>" }` |
| 401 | 인증 실패 | 오류 응답(인증 절의 네 코드) |
| 503 | Redis에 닿지 못함 | 오류 응답(`SERVICE_UNAVAILABLE`, `retryable: true`) |

예시: `examples/auth-heartbeat-response.json`

## A5. 로그아웃 — `POST /auth/logout`

- 요청 본문: 없음. 성공하면 204(본문 없음, 헤더 `X-Request-Id`는 있음).
- 인증 확인을 먼저 통과해야 합니다. 다른 곳에서 이미 로그인된 이전 기기는 여기서 401 `AUTH_SESSION_REPLACED`가 되고, **새 기기의 세션은 지워지지 않습니다**.
- 로그아웃한 토큰으로 다시 요청하면 401 `AUTH_SESSION_NOT_FOUND`입니다.
- 게임은 응답을 받든 못 받든 토큰을 지우고 타이틀로 갑니다.

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 204 | 로그아웃함 | 없음 |
| 401 | 인증 실패 | 오류 응답(인증 절의 네 코드) |
| 503 | Redis에 닿지 못함 | 오류 응답(`SERVICE_UNAVAILABLE`, `retryable: true`) |

## 오류

모두 `retryable: false`입니다(같은 요청을 다시 보내도 결과가 같음).

| 코드 | HTTP | 상황 | 게임 쪽 처리(제안) |
|---|---|---|---|
| `ACCOUNT_LOGIN_ID_DUPLICATED` | 409 | 가입: 이미 있는 아이디 | 아이디 칸에 문구 |
| `ACCOUNT_NICKNAME_DUPLICATED` | 409 | 가입: 이미 있는 닉네임 | 닉네임 칸에 문구 |
| `AUTH_INVALID_CREDENTIALS` | 401 | 로그인: 아이디 없음·비밀번호 틀림·아이디 형식 틀림 | 로그인 화면 문구 |
| `AUTH_LOGIN_LOCKED` | 429 | 로그인: 실패가 허용 횟수에 닿음 | `retryAfterSeconds`초 뒤 다시 |
| `ACCOUNT_SUSPENDED` | 403 | 로그인: 제재 계정 | 안내 |
| `AUTH_TOKEN_MISSING` | 401 | 인증 헤더 없음 | 로그인 화면 |
| `AUTH_TOKEN_INVALID` | 401 | 토큰 모양 틀림 | 로그인 화면 |
| `AUTH_SESSION_NOT_FOUND` | 401 | 로그아웃·세션 만료·없는 토큰·제재로 끊김 | 로그인 화면 |
| `AUTH_SESSION_REPLACED` | 401 | 다른 곳에서 로그인 | 안내 후 타이틀 |

공통 오류 코드(`VALIDATION_FAILED`, `INVALID_REQUEST_BODY`, `SERVICE_UNAVAILABLE` 등)는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

## 정할 것

| 무엇 | 지금 | 누가 |
|---|---|---|
| 접속 점검 간격, 허용 연속 실패 횟수 | 세션 수명 10분과의 관계에 맞춰(예: 60초 × 3번) | Robbie·Juunnmmoo |
| 점검 결과별 UE 화면(연결 실패·503 다시 시도 횟수) | 위 "게임 쪽 처리"는 제안 | Juunnmmoo |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-07 | 첫 흐름 A1·A2·A4·A5와 인증 절 작성(10/7 회의, redis-keys v1, 공통 응답 `{data, meta}`·`retryable` 기준). Postman 런타임 시험 1~11 통과 |
