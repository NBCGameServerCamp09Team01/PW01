# 계정 API (Account API)

> 버전: v1 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Juunnmmoo · 웹서버 담당: Robbie (리뷰: Sang-Hyun-Kim)

계정의 메인화면 값(계정 스냅샷)입니다. 로그인 응답의 `data.account`도 같은 모양입니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증)

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| A3 | GET | `/accounts/me` | 필요 | 200 | 내 메인화면 값 |

## 계정 스냅샷

칸 이름은 UE `FWarriorAccountData`에 맞춥니다.

| 필드 | 타입 | 설명 | UE `FWarriorAccountData` |
|---|---|---|---|
| `accountId` | string | 계정 ID(숫자를 문자열로) | — (따로 보관) |
| `version` | integer | 계정 진행이 바뀔 때마다 올라가는 번호. 지금 가진 값보다 작은 값이 오면 무시합니다 | (추가 필요) |
| `accountLevel` | integer | 계정 레벨. 1부터 | `AccountLevel` |
| `experience` | integer | 지금 레벨 안의 경험치 | `Experience` |
| `statPoints` | integer | 남은 스탯 포인트 | `StatPoints` |
| `investedStats` | object | 스탯 태그 이름 → 투자 포인트. 첫 흐름에서는 늘 `{}` | `InvestedStats` |
| `unlockedSkills` | string[] | 해금한 스킬 태그 이름. 첫 흐름에서는 늘 `[]` | `UnlockedSkills` |

- 누적 경험치는 서버 계산용이라 보내지 않습니다.
- `investedStats`·`unlockedSkills`는 스탯 분배(S3)·스킬 해금(S4)에서 채웁니다. 그때 이 명세를 v1.1로 올립니다.
- UE의 `SchemaVersion`은 UE 구조체 버전이라 `version`과 다릅니다. 서버가 보내지 않는 UE 칸(`ExternalCurrencies`, `RewardedRecordIds`)은 덮어쓰지 않도록 받는 쪽에서 지금 값을 유지합니다.

## A3. 메인화면 값 — `GET /accounts/me`

메인메뉴로 돌아올 때, 값을 새로 받아야 할 때 부릅니다. 내 계정은 토큰으로 정해지므로 경로에 ID가 없습니다.

- 인증이 필요한 요청이라 **부를 때마다 세션이 10분으로 연장됩니다**([세션 수명과 연장](auth-api.md#세션-수명과-연장)). 응답에 만료 시각은 없습니다.

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 찾음 | 성공 응답, `data`는 계정 스냅샷(위 표) |
| 401 | 인증 실패 | 오류 응답([인증 절의 네 코드](auth-api.md#인증-확인-순서와-실패-코드)) |
| 503 | MySQL·Redis에 닿지 못함 | 오류 응답(`SERVICE_UNAVAILABLE`, `retryable: true`) |

예시: `examples/account-me-response.json`

## 오류

이 명세만의 오류 코드는 없습니다. 인증 오류는 [auth-api.md 오류](auth-api.md#오류), 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-07 | A3 메인화면 값과 계정 스냅샷 작성(공통 응답 `{data, meta}` 기준). Postman 런타임 시험 통과 |
