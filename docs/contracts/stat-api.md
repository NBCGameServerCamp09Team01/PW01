# 스탯 투자 API (Stat API)

> 버전: v1 · 상태: 구현됨(웹서버 PR #14, 게임 PR #36, 10/12) · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Robbie · 웹서버 담당: Robbie (리뷰: Sang-Hyun-Kim)

성장 화면에서 여러 스탯을 **올리거나 내린** 것을 "적용" 한 번으로 보내면, 서버가 남은 포인트·최대치·0 아래를 판정해 **전부 저장하거나 전부 거절**합니다. 내리면 포인트를 돌려받습니다. 같은 요청이 두 번 와도 한 번만 반영합니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증). 아래 API는 인증이 필요합니다
- 계정 스냅샷(`investedStats`·`statPoints`): [account-api.md](account-api.md#계정-스냅샷)
- 아래 "응답 `data`" 표는 성공 응답의 `data` 안쪽 모양입니다.

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| T1 | POST | `/accounts/me/stat-investments` | 필요 | 200 | 묶음 투자(올림·내림). 전부 반영 또는 전부 거절 |

- 투자 값 조회 API는 따로 없습니다. 로그인 응답과 `GET /accounts/me`의 `investedStats`로 받습니다.
- 스탯 하나만 바꿀 때도 한 줄짜리 묶음으로 보냅니다.

## 스탯

| 스탯 태그 | 최대 포인트 | UE |
|---|---|---|
| `Account.Stat.MaxHealth` | 10 | `WarriorAccountTags::Account_Stat_MaxHealth` |
| `Account.Stat.MaxStamina` | 10 | `Account_Stat_MaxStamina` |
| `Account.Stat.AttackPower` | 10 | `Account_Stat_AttackPower` |
| `Account.Stat.DefensePower` | 10 | `Account_Stat_DefensePower` |

- 서버 판정 기준은 웹서버 리소스 `master/stats.json`입니다. 처음 값은 UE `UWarriorAccountSubsystem::BuildDefinitions()`와 같습니다. 둘이 어긋나면 서버 값으로 판정합니다(게임은 거절 응답을 받음).
- 스탯을 더할 때는 `stats.json` 한 줄과 UE 한 줄을 같이 더하고 이 표를 고칩니다. 서버 코드는 바꾸지 않습니다.
- 최종 능력치(포인트 × 증가량)는 UE가 계산해 적용합니다. 서버는 포인트만 판정합니다.

## T1. 묶음 투자 — `POST /accounts/me/stat-investments`

성장 화면에서 "적용"을 눌렀을 때 부릅니다. + / −는 화면 안의 미리보기만 바꾸고, 적용할 때 모아서 한 번 보냅니다.

요청

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `requestId` | string(UUID) | 예 | 이 요청의 번호(소문자·하이픈 36자). **다시 보낼 때 같은 값**. [한 번만 반영](#한-번만-반영) |
| `investments` | array | 예 | 1개 이상, 최대 10개(서버 설정 `pw01.stat-invest.max-entries`) |
| `investments[].statTag` | string | 예 | [스탯](#스탯) 태그 |
| `investments[].points` | integer | 예 | **0이 아닌 정수.** 양수 = 올림(포인트를 씀), 음수 = 내림(포인트를 돌려받음) |

- 같은 `statTag`가 두 번 나오거나 `points`가 0이면 400 `VALIDATION_FAILED`(`errors`에 칸 이름, 예: `investments[1].statTag`). 합치지 않습니다.
- 한 묶음 안에서 내려서 돌려받은 포인트로 다른 스탯을 올릴 수 있습니다(전부 한 번에 판정). 예: 남은 포인트 0에서 방어력 −1, 체력 +1 → 성공.
- 전체 초기화 API는 따로 없습니다. 모든 스탯을 음수로 보내면 같습니다.

예시: `examples/stat-invest-request.json`

### 판정 순서

| 순서 | 판정 | 걸리면 |
|---|---|---|
| 0 | 형식(필수·UUID·0·같은 스탯 두 번·묶음 크기·모르는 칸) | 400 `VALIDATION_FAILED` · `INVALID_REQUEST_BODY` |
| 1 | 같은 `requestId`가 이미 처리됐나 | [한 번만 반영](#한-번만-반영) |
| 2 | 모든 `statTag`가 [스탯](#스탯)에 있나 | 400 `STAT_UNKNOWN`(`errors`에 칸) |
| 3 | 묶음 합계(양수 + 음수) ≤ 남은 포인트 | 409 `STAT_POINTS_NOT_ENOUGH` |
| 4 | 스탯마다 `지금 값 + points ≤ 최대 포인트` | 409 `STAT_MAX_EXCEEDED`(`errors`에 넘는 스탯 전부) |
| 5 | 스탯마다 `지금 값 + points ≥ 0` | 409 `STAT_BELOW_ZERO`(`errors`에 걸린 스탯 전부) |
| 6 | 저장 | 아래 |

- 2~5 중 하나라도 걸리면 **아무것도 저장하지 않습니다.**
- 저장(한 트랜잭션): 남은 포인트에서 합계를 빼고(음수면 늘어남), 스탯마다 투자 값을 바꾸고, 스탯마다 변경 내역 한 줄. 계정 `version`이 1 오릅니다.
- 같은 계정의 다른 저장(결과 보상 등)과 부딪히면 서버가 몇 번 다시 하고, 넘으면 409 `VERSION_CONFLICT`(`retryable: true`).

### 응답

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 반영함, 또는 이미 반영된 요청 | 성공 응답, `data`는 아래 표 |
| 400 | 형식, 없는 스탯 | `VALIDATION_FAILED` · `INVALID_REQUEST_BODY` · `STAT_UNKNOWN` |
| 401 | 인증 실패 | auth-api.md 네 코드 |
| 409 | 포인트 부족, 최대치 초과, 0 아래, 같은 키 다른 본문, 처리 중, 저장 충돌 | `STAT_POINTS_NOT_ENOUGH` · `STAT_MAX_EXCEEDED` · `STAT_BELOW_ZERO` · `IDEMPOTENCY_KEY_REUSED` · `REQUEST_IN_PROGRESS` · `VERSION_CONFLICT` |
| 503 | MySQL·Redis에 닿지 못함 | `SERVICE_UNAVAILABLE`(`retryable: true`) |

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result.statPoints` | integer | 반영 뒤 남은 포인트 |
| `result.investedStats` | object | 반영 뒤 **전체** 투자 값(스탯 태그 → 포인트). 0인 스탯은 빠짐 |
| `result.version` | integer | 계정 `version` |
| `saveStatus` | string | `SAVED`(이번 요청으로 반영) · `ALREADY_SAVED`(이미 반영된 요청이라 다시 반영하지 않음). 게임은 둘 다 "반영됨"으로 봅니다 |
| `account` | object | 지금 계정 스냅샷([account-api.md](account-api.md#계정-스냅샷)). 게임은 `version`이 지금 값보다 크면 그대로 적용합니다 |

예시: `examples/stat-invest-response.json`, 거절 `examples/stat-error-points-not-enough.json`, `stat-error-max-exceeded.json`, `stat-error-below-zero.json`, `stat-error-unknown.json`

## 한 번만 반영

응답을 받지 못해 같은 요청을 다시 보내도(연결 끊김·503·버튼 두 번), 포인트는 **한 번만** 빠집니다.

| 경우 | 서버 응답 |
|---|---|
| 같은 `requestId` + 같은 본문, 처음 요청이 성공(2xx)함 | **처음 응답 그대로**(24시간 동안, 서버 설정 `pw01.idempotency.ttl`) |
| 같은 `requestId` + 같은 본문, 처음 요청이 아직 처리 중 | 409 `REQUEST_IN_PROGRESS`(`retryable: true`). 잠시 뒤 같은 본문으로 다시 |
| 같은 `requestId` + **다른** 본문 | 409 `IDEMPOTENCY_KEY_REUSED`(`retryable: false`). 게임 버그 |
| 처음 요청이 4xx·5xx로 끝남 | 기억하지 않음. 같은 `requestId`로 다시 보내면 처음처럼 다시 판정 |
| 기억 시간이 지난 뒤 같은 요청 | 변경 내역으로 이미 반영된 것을 알아채 200 + `saveStatus: ALREADY_SAVED` + 지금 값 |

- 서버는 계정 + `requestId`로 처음 응답을 Redis에 기억합니다(키는 [redis-keys.md](redis-keys.md)). 마지막 방어는 DB(변경 내역)입니다.
- 게임 규칙: **새 "적용"에는 새 `requestId`, 다시 보낼 때는 같은 `requestId`와 같은 본문.**

## 오류

이 명세만의 오류 코드입니다. 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `STAT_UNKNOWN` | 400 | 없는 스탯 태그(`errors`에 칸) | false | 미리보기 비움, "알 수 없는 스탯입니다"(게임 버그) |
| `STAT_POINTS_NOT_ENOUGH` | 409 | 묶음 합계가 남은 포인트보다 큼 | false | 미리보기 유지, "스탯 포인트가 부족합니다", 계정 값 다시 받기 |
| `STAT_MAX_EXCEEDED` | 409 | 최대 포인트를 넘는 스탯(`errors`에 스탯) | false | 해당 스탯 표시, "최대치를 넘는 스탯이 있습니다" |
| `STAT_BELOW_ZERO` | 409 | 투자한 것보다 많이 내림(`errors`에 스탯) | false | 해당 스탯 표시, "투자한 포인트보다 많이 내릴 수 없습니다" |

- 거절(`retryable: false`)은 같은 본문으로 다시 보내도 같은 결과입니다. 다시 보내지 않습니다.
- `errors[].field`는 `investments[i].statTag` 모양입니다(i는 0부터).

## 정할 것

| 무엇 | 지금 | 누가 |
|---|---|---|
| 서버 스탯 검산(최종 능력치) | 하지 않음(UE가 계산) | Robbie |
| 스탯 값 원본을 서버로 옮기기 | 서버 파일과 UE 코드를 손으로 맞춤 | Robbie·Sang-Hyun-Kim |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-12 | 초안: T1 묶음 투자(올림·내림, 전부 성공 또는 전부 실패), 스탯 4개, 판정 순서, 응답 `{result, saveStatus, account}`, 한 번만 반영(`requestId`), 오류 네 개 |
| v1 | 2026-10-12 | 상태: 구현됨(웹서버 `dev` PR #14, 게임 `dev` PR #36 병합). 내용은 바뀌지 않음 |
