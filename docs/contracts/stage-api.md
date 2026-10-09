# 스테이지 API (Stage API)

> 버전: v1.1 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Sang-Hyun-Kim · 웹서버 담당: Sang-Hyun-Kim (리뷰: Robbie)

지역 → 스테이지 정의(모두에게 같음)와 내 진행(열림·잠김·클리어)입니다. 스테이지를 시작할 수 있는지는 스테이지 플레이 시작([stage-play-api.md](stage-play-api.md))에서 서버가 다시 확인합니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증). 인증이 필요한 요청은 부를 때마다 세션이 연장됩니다
- 아래 "응답 `data`" 표는 성공 응답의 `data` 안쪽 모양입니다. 실제 본문은 `{ "data": { … }, "meta": { "requestId": "…" } }`입니다.

## 키

| 키 | 모양 | 예 | 규칙 |
|---|---|---|---|
| 지역 키 `regionId` | 영문 소문자·숫자·`.`, 1~64자 | `region.01` | 한 번 정하면 바꾸지 않습니다 |
| 스테이지 키 `stageId` | 영문 소문자·숫자·`.`, 1~64자 | `stage.01.01` | UE `FName`과 같은 문자열입니다. 진행·결과 기록이 이 값을 가지므로 바꾸지 않습니다 |

- 서버는 키의 대소문자를 가립니다. UE `FName`은 대소문자를 가리지 않으므로 **소문자만 씁니다.** 게임은 서버 목록에서 받은 문자열을 그대로 보냅니다.
- 게임은 키를 잘라 번호를 읽지 않습니다. 순서는 `order`, 해금은 `requires`로 정합니다.
- 지역·스테이지 정의는 서버 리소스 파일(`master/stages.json`)에 있습니다. 서버는 기동할 때 검사하고 틀리면 뜨지 않습니다.

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| ST1 | GET | `/stages` | 없음 | 200 | 스테이지 정의(모두에게 같음) |
| ST2 | GET | `/accounts/me/stages` | 필요 | 200 | 내 스테이지 진행 |

- 모두에게 같은 정의(ST1)와 계정마다 다른 진행(ST2)을 다른 자원으로 둡니다. 내 것은 `GET /accounts/me`처럼 `/accounts/me` 아래에 있습니다.
- 게임은 선택 화면에서 둘을 받아 `stageId`로 합칩니다. ST1은 서버가 다시 뜰 때까지 바뀌지 않으므로 한 번 받아 두면 되고, ST2는 선택 화면을 열 때마다 받습니다.

## ST1. 스테이지 정의 — `GET /stages`

인증 없이 부릅니다.

**응답 `data`**

| 필드 | 타입 | 설명 |
|---|---|---|
| `totalCount` | integer | 전체 스테이지 수 |
| `regions` | array | 지역 목록. `order` 순 |
| `regions[].regionId` | string | 지역 키 |
| `regions[].name` | string | 화면 이름 |
| `regions[].order` | integer | 화면 순서. 1부터 |
| `regions[].stages` | array | 그 지역의 스테이지. `order` 순 |
| `stages[].stageId` | string | 스테이지 키 |
| `stages[].name` | string | 화면 이름 |
| `stages[].order` | integer | 지역 안 화면 순서. 1부터 |
| `stages[].requires` | string \| null | 이 스테이지를 클리어하면 열립니다. 첫 스테이지는 `null`(칸은 늘 있음). 잠김 안내 문구에 씁니다 |
| `stages[].waveCount` | integer | 웨이브 수 |

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 찾음 | 성공 응답, `data`는 위 표 |

예시: `examples/stage-list-response.json`

## ST2. 내 스테이지 진행 — `GET /accounts/me/stages`

스테이지 선택 화면을 열 때마다 부릅니다. 결과를 낸 뒤 진행이 바뀌었으면 다음에 부를 때 반영되어 있습니다. 결과 제출 응답에는 진행이 들어 있지 않습니다(나중에 `stage` 칸으로 더할 자리만 있음, [result-api.md](result-api.md)).

**응답 `data`**

| 필드 | 타입 | 설명 |
|---|---|---|
| `clearedCount` | integer | 클리어한 스테이지 수 |
| `totalCount` | integer | 전체 스테이지 수 |
| `stages` | array | 스테이지마다 내 상태. 순서는 ST1과 같습니다(지역 `order` → 스테이지 `order`) |
| `stages[].stageId` | string | 스테이지 키 |
| `stages[].status` | string | `LOCKED` · `OPEN` · `CLEARED`. 서버가 계산합니다 |
| `stages[].firstClearedAt` | string \| null | 서버가 처음 클리어 결과를 받아들인 시각. 클리어 전에는 `null`(칸은 늘 있음). 보관했다 다시 보낸 결과면 플레이한 시각보다 늦을 수 있습니다 |

- **상태 규칙**: 클리어했으면 `CLEARED`, 아니면 `requires`가 없거나 `requires`를 클리어했으면 `OPEN`, 그 밖은 `LOCKED`입니다. 첫 스테이지는 계정을 만들면 바로 `OPEN`입니다.
- 게임은 해금 규칙을 따로 갖지 않고 `status`대로 그립니다. `LOCKED` 스테이지는 선택 화면에서 시작하지 못하게 막습니다.
- 실패·포기한 스테이지 플레이는 진행을 바꾸지 않습니다. 같은 스테이지를 다시 클리어해도 `firstClearedAt`은 그대로입니다. 진행은 난이도와 상관없이 스테이지 단위입니다.

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 찾음 | 성공 응답, `data`는 위 표 |
| 401 | 인증 실패 | 오류 응답([인증 절의 네 코드](auth-api.md#인증-확인-순서와-실패-코드)) |
| 503 | MySQL·Redis에 닿지 못함 | 오류 응답(`SERVICE_UNAVAILABLE`, `retryable: true`) |

예시: `examples/stage-progress-response.json`(새 계정)

## 스테이지 플레이 시작·결과에서의 약속

스테이지 플레이 시작(`POST /accounts/me/stage-plays`)은 [stage-play-api.md](stage-play-api.md), 결과(`POST /accounts/me/stage-plays/{stagePlayId}/result`)는 [result-api.md](result-api.md)에 있습니다. 스테이지 플레이 ID 모양(UUID 소문자·하이픈 36자)은 stage-play-api.md가 기준입니다. 스테이지에 관해 서버가 하는 일만 여기에 적습니다.

| 때 | 서버가 하는 일 |
|---|---|
| 스테이지 플레이 시작 | 요청의 `stageId`가 없는 키면 `STAGE_NOT_FOUND`, 아직 열리지 않았으면 `STAGE_LOCKED`로 거절합니다. 통과하면 그 스테이지와 **그때의 `waveCount`**를 스테이지 플레이에 저장합니다 |
| 결과 검사 | 결과 본문의 `stageId`가 스테이지 플레이에 저장한 스테이지와 다르면 거절합니다. 웨이브 기준은 **스테이지 플레이에 저장한 `waveCount`**입니다. 도달 웨이브는 0 이상 `waveCount` 이하이고, 클리어면 `waveCount`와 같아야 합니다. 게임이 보낸 전체 웨이브 수는 검사에 쓰지 않습니다. 거절 코드는 result-api.md에 있습니다 |
| 결과 저장 | 클리어 결과가 받아들여지면, 결과·보상과 **같이** 그 스테이지가 클리어로 기록됩니다. 기록하는 스테이지는 스테이지 플레이에 저장한 값입니다. 같은 스테이지 플레이의 재전송은 진행을 다시 바꾸지 않습니다 |

- 스테이지 플레이에 웨이브 수를 저장하는 이유: 유효 시간(24시간) 사이에 서버의 `waveCount`가 바뀌어도, 보관했다 다시 보낸 결과가 거절되지 않게 하려고입니다.
- 게임의 시작 요청에는 선택 화면에서 고른 스테이지 키(`AWarriorStageGameMode`가 정한 값)를 보냅니다. 레벨 이름이 가면 `STAGE_NOT_FOUND`입니다. 난이도(`difficulty`, 선택 칸)는 지금 0(난이도 조절 없음)만 받습니다.
- `waveCount`의 원본은 지금 UE 웨이브 DataAsset이고, 서버 값은 손으로 옮긴 사본입니다. 웨이브 수를 바꾸면 서버 `master/stages.json`도 함께 고칩니다(어긋나면 결과가 거절됩니다).

## 오류

이 명세만의 오류 코드입니다. 인증 오류는 [auth-api.md 오류](auth-api.md#오류), 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `STAGE_NOT_FOUND` | 404 | 없는 `stageId`로 스테이지 플레이를 시작함 | false | "스테이지 정보를 찾을 수 없습니다." 안내 후 메인메뉴. 게임·서버 키가 어긋난 버그입니다 |
| `STAGE_LOCKED` | 403 | 아직 열리지 않은 스테이지로 스테이지 플레이를 시작함 | false | "아직 열리지 않은 스테이지입니다." 안내 후 메인메뉴. 선택 화면이 먼저 막으므로 보통은 나오지 않습니다 |

- `STAGE_LOCKED`는 다시 보내도 결과가 같으므로 409(다시 보내면 될 수 있는 충돌)가 아니라 403으로 둡니다. 게임은 HTTP 상태가 아니라 `code`로 나눕니다(403 `ACCOUNT_SUSPENDED`와 섞이지 않음).
- 예시: `examples/stage-error-locked.json`

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-08 | 초안: 키 규칙, ST1 스테이지 정의(공개), ST2 내 스테이지 진행, 판 시작·결과에서의 약속(판에 웨이브 수 저장, 결과 본문의 스테이지 비교), 오류 두 개 |
| v1.1 | 2026-10-09 | 판 시작(`POST /runs`)·결과(`/runs/{runId}/result`)를 스테이지 플레이 API([stage-play-api.md](stage-play-api.md))와 새 결과 경로로 바꿈. "판"·"판 번호" 표기를 스테이지 플레이·스테이지 플레이 ID로. 예시 오류의 `path`. 동작·칸은 그대로 |
