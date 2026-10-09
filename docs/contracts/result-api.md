# 결과 API (Result API)

> 버전: v1 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Robbie · 웹서버 담당: Robbie (리뷰: Sang-Hyun-Kim)

스테이지 플레이가 끝나면(클리어·실패) 게임이 결과를 보내고, 서버가 **검사 → 보상 계산 → 저장 → 진행 반영**을 한 번에 합니다. 같은 플레이의 결과는 **한 번만** 반영합니다. 저장된 결과는 다시 받을 수 있습니다.

- 스테이지 플레이(시작·진행 중·포기·`stagePlayId`): [stage-play-api.md](stage-play-api.md). 결과는 그 플레이 밑에 붙습니다(플레이 하나에 결과 하나)
- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증). 아래 API는 모두 인증이 필요합니다
- 스테이지 키·열림·잠김: [stage-api.md](stage-api.md)

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| R1 | POST | `/accounts/me/stage-plays/{stagePlayId}/result` | 필요 | 200 | 결과 제출. 검사·보상·저장 → 결과 + 저장 상태 + 새 계정 값 |
| R2 | GET | `/accounts/me/stage-plays/{stagePlayId}/result` | 필요 | 200 | 저장된 결과 다시 받기(제출 응답을 놓쳤을 때) |

- `{stagePlayId}`는 [stage-play-api.md P1](stage-play-api.md#p1-시작--post-accountsmestage-plays)이 발급한 ID입니다. 대문자도 받고 소문자로 맞춥니다. UUID 모양이 아니면 400 `VALIDATION_FAILED`(`errors[0].field = "stagePlayId"`).
- 내 결과 기록 목록(여러 플레이)은 아직 없습니다([정할 것](#정할-것)).

## R1. 결과 제출 — `POST /accounts/me/stage-plays/{stagePlayId}/result`

플레이가 끝났을 때(UE `AWarriorStageGameMode::FinishRun`) 부릅니다. 중간에 나간 판은 보내지 않습니다(다음 시작 때 포기로 정리, [stage-play-api.md P1](stage-play-api.md#p1-시작--post-accountsmestage-plays)).

요청

| 필드 | 타입 | 필수 | 설명 | UE `FWarriorStageResult` |
|---|---|---|---|---|
| `requestId` | string(UUID) | 예 | 이 결과 요청의 번호. **다시 보낼 때 같은 값**. 서버가 결과와 함께 저장합니다 | — |
| `stageId` | string | 예 | 플레이 시작 때와 같은 스테이지 키(소문자, 64자 이하) | `StageId` |
| `difficulty` | integer | 아니오 | 플레이 시작 때와 같은 난이도. 없으면 0. 지금은 0만 | `Difficulty` |
| `cleared` | boolean | 예 | 클리어했나 | `bCleared` |
| `reachedWave` | integer | 예 | 도달한 웨이브 | `ReachedWave` |
| `totalWaveCount` | integer | 예 | 게임이 알고 있는 전체 웨이브 수(0 이상). **검사에 쓰지 않고** 플레이의 `waveCount`와 다르면 서버가 경고 로그만 남깁니다 | `TotalWaveCount` |
| `playTimeSeconds` | number | 예 | 플레이 시간(초, 소수 가능) | `PlayTimeSeconds` |
| `earnedGold` | integer | 예 | 얻은 골드(0 이상) | `EarnedGold` |
| `killCount` | integer | 예 | 처치 수(0 이상) | `KillCount` |

- UE 구조체를 그대로 JSON으로 바꾸면 `bCleared`가 `"bCleared"`로 나가 400 `INVALID_REQUEST_BODY`(모르는 칸)가 됩니다. 요청 칸 이름은 위 표대로 맞춥니다.

예시: `examples/result-submit-request.json`

### 검사 순서

| 순서 | 검사 | 걸리면 |
|---|---|---|
| 0 | 요청 칸 형식(필수·0 이상·UUID·모르는 칸), 경로 ID 모양 | 400 `VALIDATION_FAILED` · `INVALID_REQUEST_BODY` |
| 1 | **내 계정의 플레이**인가 | 404 `STAGE_PLAY_NOT_FOUND`(남의 플레이도 같은 코드: 있는지 알려 주지 않음) |
| 2 | 이 플레이에 **이미 결과가 있나** | 있으면 거절이 아니라 200 + **처음 결과** + `saveStatus: ALREADY_SAVED`. 아래 3~6을 지나지 않습니다 |
| 3 | 플레이 상태: 만료(저장된 `EXPIRED`이거나 진행 중인데 마감이 지남) / 그 밖에 끝남(포기) | 409 `STAGE_PLAY_EXPIRED` / 409 `STAGE_PLAY_NOT_IN_PROGRESS` |
| 4 | `stageId`·`difficulty`가 플레이 시작 때와 같은가 | 400 `RESULT_MISMATCH`(`errors`에 칸 이름) |
| 5 | 웨이브: `0 ≤ reachedWave ≤ waveCount`, 클리어면 `reachedWave = waveCount`(플레이에 저장된 `waveCount` 기준) | 400 `RESULT_INVALID`(`errors`에 `reachedWave`) |
| 6 | 시간: `0 ≤ playTimeSeconds`, `playTimeSeconds ≤ 7200`(2시간), `playTimeSeconds ≤ 서버가 잰 경과(시작 → 지금) + 60초` | 400 `RESULT_INVALID`(`errors`에 `playTimeSeconds`) |
| 7 | 저장 | 아래 [보상](#보상)·[한 번만 반영](#한-번만-반영) |

- 3~6에 걸린 결과는 아무것도 저장하지 않습니다(보상·변경 내역·누적 통계·결과 모두). 플레이 상태는 그대로입니다.
- 6의 경과 시간은 서버 시각으로 잽니다. 게임은 **스테이지가 준비된 순간 플레이를 시작**해야(UE `BeginRun`) 시간이 맞습니다.
- 상한 값(2시간, 60초 여유, 마감 24시간)은 서버 설정 `pw01.stage-play.*`입니다. 거절 로그를 보고 조입니다.

### 보상

| 항목 | 규칙 |
|---|---|
| 경험치 | 클리어 300, 실패 60 |
| 계산 원본 | **총 경험치**. 총 경험치에 더한 뒤 레벨과 "지금 레벨 안의 경험치"를 총 경험치에서 다시 계산합니다 |
| 레벨 곡선 | 레벨 L에서 다음 레벨까지 필요한 경험치 = 100 + (L − 1) × 50, 최대 레벨 99(최대 레벨에서는 지금 레벨 안의 경험치 0) |
| 스탯 포인트 | 오른 레벨 수 × 2 |
| 값의 출처 | 서버 리소스 `master/level-curve.json`. 처음 값은 UE `UWarriorAccountSubsystem::FRules`와 같습니다(새 계정의 첫 클리어 = 레벨 1 → 3, 스탯 포인트 +4) |

- 서버가 계산합니다. 게임이 보낸 값으로 경험치를 정하지 않습니다.
- 한 트랜잭션에 함께 저장: 결과, 계정 값(경험치·레벨·스탯 포인트), 변경 내역(출처 `STAGE_PLAY` + `stagePlayId`), 누적 통계(`stage_play.played`·`cleared`·`kills`·`gold`), 플레이 상태(`CLEARED`·`FAILED`, `endReason: RESULT`), 클리어면 스테이지 진행(다음 스테이지 열림, [stage-api.md](stage-api.md)). 하나라도 실패하면 아무것도 남지 않습니다.

### 응답

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 저장함, 또는 이미 저장된 결과 | 성공 응답, `data`는 아래 표 |
| 400 | 칸 형식, 경로 ID 모양, 시작 때와 다름, 검사 실패 | `VALIDATION_FAILED` · `INVALID_REQUEST_BODY` · `RESULT_MISMATCH` · `RESULT_INVALID` |
| 401 | 인증 실패 | auth-api.md 네 코드 |
| 404 | 없는 플레이, 남의 플레이 | `STAGE_PLAY_NOT_FOUND` |
| 409 | 만료, 포기로 끝남, 저장 충돌 | `STAGE_PLAY_EXPIRED` · `STAGE_PLAY_NOT_IN_PROGRESS` · `VERSION_CONFLICT`(`retryable: true`) |
| 503 | MySQL·Redis에 닿지 못함 | `SERVICE_UNAVAILABLE`(`retryable: true`) |

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result` | object | 저장된 결과(아래 [결과](#결과)). `ALREADY_SAVED`면 **처음 저장된** 결과 |
| `saveStatus` | string | `SAVED`(이번 요청으로 저장) · `ALREADY_SAVED`(이미 저장돼 있어 처음 결과를 돌려줌, 보상은 다시 주지 않음). **게임은 둘 다 "저장됨"으로 봅니다** |
| `account` | object | 지금 계정 값([account-api.md](account-api.md#계정-스냅샷), `version` 포함). 확장 칸입니다. 게임은 쓰지 않아도 되고, 메인메뉴 값은 로그인·`GET /accounts/me`로 받습니다 |

- `meta.requestId`는 서버가 만든 요청 번호입니다(응답 헤더 `X-Request-Id`와 같음). 요청 본문의 `requestId`와 다릅니다.

예시: `examples/result-submit-response.json`, 검사 실패 `examples/result-error-invalid.json`

### 결과

R1의 `data.result`와 R2의 `data`가 같은 모양입니다.

| 필드 | 타입 | 설명 | UE |
|---|---|---|---|
| `stagePlayId` | string | 스테이지 플레이 ID | — |
| `stageId` | string | 스테이지 키(플레이 값) | `StageId` |
| `difficulty` | integer | 난이도 | `Difficulty` |
| `cleared` | boolean | 클리어했나 | `bCleared` |
| `reachedWave` | integer | 도달한 웨이브 | `ReachedWave` |
| `waveCount` | integer | 플레이의 웨이브 수(서버 값) | `TotalWaveCount` |
| `playTimeSeconds` | number | 플레이 시간(초, 밀리초까지) | `PlayTimeSeconds` |
| `earnedGold` | integer | 얻은 골드 | `EarnedGold` |
| `killCount` | integer | 처치 수 | `KillCount` |
| `submittedAt` | string | 서버가 결과를 저장한 시각(UTC) | — |
| `reward.expGained` | integer | 받은 경험치 | `FWarriorStageReward.ExpGained` |
| `reward.levelBefore` | integer | 결과 전 레벨 | `LevelBefore` |
| `reward.levelAfter` | integer | 결과 뒤 레벨 | `LevelAfter` |
| `reward.statPointsGained` | integer | 레벨 업으로 받은 스탯 포인트 | `StatPointsGained` |

## R2. 결과 다시 받기 — `GET /accounts/me/stage-plays/{stagePlayId}/result`

제출 응답을 받지 못했을 때 저장 여부와 결과를 확인합니다. 저장된 결과를 바꾸지 않습니다.

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 저장된 결과 | 성공 응답, `data`는 [결과](#결과) |
| 400 | 경로 ID 모양 | `VALIDATION_FAILED`(`errors[0].field = "stagePlayId"`) |
| 401 | 인증 실패 | auth-api.md 네 코드 |
| 404 | 없는 플레이·남의 플레이 / 내 플레이인데 결과가 없음(제출 전, 포기, 만료) | `STAGE_PLAY_NOT_FOUND` / `STAGE_RESULT_NOT_FOUND` |
| 503 | MySQL·Redis에 닿지 못함 | `SERVICE_UNAVAILABLE`(`retryable: true`) |

예시: `examples/result-get-response.json`, 결과 없음 `examples/result-error-not-found.json`

## 한 번만 반영

같은 플레이의 보상은 **플레이 ID로 한 번만** 들어갑니다(결과 표의 기본 키 = `stagePlayId`).

| 경우 | 서버 응답 |
|---|---|
| 같은 플레이에 다시 보냄(같은 `requestId`든 다른 `requestId`든) | 200 + 처음 결과 + `ALREADY_SAVED` + 지금 계정 값. 두 번째 내용은 쓰지 않습니다(검사도 하지 않음) |
| 같은 플레이의 결과가 **동시에** 둘 | 하나는 `SAVED`, 다른 하나는 `ALREADY_SAVED`. 뒤 요청은 기본 키 충돌로 되돌아간 뒤 다시 해서 처음 결과를 받습니다 |
| 같은 계정의 다른 저장과 부딪힘(계정 값 `version`) | 서버가 새 트랜잭션으로 몇 번 다시 합니다(설정 `pw01.stage-play.save-attempts`, 처음 3). 넘으면 409 `VERSION_CONFLICT`(`retryable: true`) |

게임의 재전송(지금)

1. `retryable: true`이거나 연결 실패면 **같은 본문(같은 `requestId`)**으로 한 번 더 보냅니다.
2. 200(`SAVED`·`ALREADY_SAVED`)이면 끝. `retryable: false`면 다시 보내지 않고 `code`를 남깁니다.
3. 결과를 디스크에 보관했다가 다음 로그인 뒤 보내는 것은 다음 작업입니다([정할 것](#정할-것)). 그때는 [stage-play-api.md P1](stage-play-api.md#p1-시작--post-accountsmestage-plays)의 409 처리에서 포기하기 전에 보관 결과부터 보냅니다.

## 오류

이 명세만의 오류 코드입니다. 플레이 오류(`STAGE_PLAY_*`)는 [stage-play-api.md 오류](stage-play-api.md#오류), 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `RESULT_MISMATCH` | 400 | 플레이 시작 때와 스테이지·난이도가 다름(`errors`에 칸 이름) | false | 다시 보내지 않음. 게임 버그 |
| `RESULT_INVALID` | 400 | 검사 실패(웨이브·시간, `errors`에 칸 이름) | false | 다시 보내지 않음. "결과를 확인할 수 없습니다" |
| `STAGE_RESULT_NOT_FOUND` | 404 | R2: 내 플레이인데 결과가 없음 | false | 결과가 저장되지 않은 것. 제출 전이면 R1 |
| `VERSION_CONFLICT` | 409 | 같은 계정의 저장이 계속 부딪힘(공통 코드) | true | 같은 본문으로 다시 보냄 |

결과 제출에서도 쓰는 플레이 오류: `STAGE_PLAY_NOT_FOUND`(404), `STAGE_PLAY_EXPIRED`(409), `STAGE_PLAY_NOT_IN_PROGRESS`(409). 모두 `retryable: false`이고 보상 계산 전에 걸립니다.

## 정할 것

| 무엇 | 지금 | 누가 |
|---|---|---|
| 내 결과 기록 목록 | 없음. 필요해지면 `GET /accounts/me/stage-results`(최근순, 커서)로 더함 | Robbie |
| 보관 결과 재전송(게임을 다시 켠 뒤) | 같은 세션 안 한 번 재시도까지. 디스크 보관·로그인 뒤 재전송은 다음 | Robbie |
| `requestId`의 공통 중복 방지(Redis) | 없음. 결과는 플레이 ID 기본 키로 한 번만 반영 | Robbie·Sang-Hyun-Kim |
| 누적 통계에 더할 기록 키(스킬 해금 조건 재료) | v1은 결과 칸(판 수·클리어·처치·골드)만 누적 | Robbie·S4 담당 |
| 타당성 상한 조이기, `earnedGold`·`killCount` 상한 | 경과 + 60초, 2시간 / 상한 없음 | Robbie(거절 로그 보고) |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v0 | 2026-09-28 | 문서 틀 생성 |
| v0 | 2026-10-05 | 호출 주체를 게임 클라이언트로 변경(싱글 게임 구조) |
| v1 | 2026-10-09 | 초안: 결과를 스테이지 플레이 밑으로(R1 `POST`·R2 `GET …/{stagePlayId}/result`, 판 시작은 [stage-play-api.md](stage-play-api.md)로). `saveStatus`(`SAVED`·`ALREADY_SAVED`), 검사 순서(플레이 상태를 보상 전에), 보상(서버 계산, 총 경험치 기준), 플레이 ID로 한 번만 반영, 오류 `STAGE_RESULT_NOT_FOUND` |
