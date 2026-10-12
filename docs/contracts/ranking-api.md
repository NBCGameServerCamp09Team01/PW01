# 랭킹 API (Ranking API)

> 버전: v1 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Sang-Hyun-Kim · 웹서버 담당: Sang-Hyun-Kim (리뷰: Robbie)

스테이지·지역 총합·전체 총합·진행 네 가지 순위입니다. 순위는 서버가 받아들인 클리어 결과만으로 서버가 만듭니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증). 아래 API는 모두 인증이 필요합니다
- 지역·스테이지 키와 권장 클리어 시간: [stage-api.md](stage-api.md). 결과 저장: [result-api.md](result-api.md)
- 서버의 저장 방식(Redis 키·스크립트): [redis-keys.md 랭킹](redis-keys.md#랭킹v13)

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| RK1 | GET | `/rankings/stages/{stageId}` | 필요 | 200 | 스테이지 순위 목록 |
| RK2 | GET | `/accounts/me/rankings/stages/{stageId}` | 필요 | 200 | 스테이지 순위에서 내 줄 |
| RK3 | GET | `/rankings/regions/{regionId}` | 필요 | 200 | 지역 순위 목록 |
| RK4 | GET | `/accounts/me/rankings/regions/{regionId}` | 필요 | 200 | 지역 순위에서 내 줄 |
| RK5 | GET | `/rankings/progress` | 필요 | 200 | 진행 순위 목록 |
| RK6 | GET | `/accounts/me/rankings/progress` | 필요 | 200 | 진행 순위에서 내 줄 |
| RK7 | GET | `/rankings/total` | 필요 | 200 | 전체 총합(모든 지역) 순위 목록 |
| RK8 | GET | `/accounts/me/rankings/total` | 필요 | 200 | 전체 총합 순위에서 내 줄 |

- 게임 화면: 메인메뉴 "랭킹" 팝업 = 전체 총합(RK7·RK8)·지역 총합(RK3·RK4) 두 화면, 스테이지 선택의 "순위" 버튼 = 스테이지 위 5명(RK1 `limit=5`)·내 줄(RK2). 진행(RK5·RK6)은 지금 화면에 쓰지 않습니다(API만).

- 모두에게 같은 목록과 내 것을 다른 자원으로 둡니다. 내 것은 [stage-api.md](stage-api.md) ST2처럼 `/accounts/me` 아래에 있습니다.
- 게임은 랭킹 화면을 열거나 보드·기간을 바꿀 때 목록(첫 묶음)과 내 줄을 함께 부릅니다. "더 보기"는 목록에 `cursor`만 붙여 부릅니다.

## 점수

```text
T = 스테이지 권장 클리어 시간(stage-api ST1 recommendedClearSeconds)
t = 클리어 시간(결과 요청의 playTimeSeconds를 서버가 밀리초로 저장한 값)
남은 시간 r = max(0, T − t)
스테이지 점수 = floor(M × (1000 + floor(9000 × r / T)))     M = 난이도 배수(지금 늘 1)
```

- 1,000~10,000점입니다. 빨리 깰수록 높고, 권장 시간을 넘겨도 클리어면 1,000점입니다.
- 예: T 300초, t 183.4초 → 1000 + floor(9000 × 116.6 / 300) = **4498점**.
- 점수는 서버가 클리어를 기록할 때 계산해 저장합니다. 나중에 권장 시간을 바꿔도 이미 기록된 점수는 다시 계산하지 않습니다.
- 난이도 배수 `M`은 자리만 있습니다(지금 결과는 모두 난이도 0, M = 1).

## 보드와 순서

| 보드 | `kind` | 대상 | 기간 | 한 계정의 점수 |
|---|---|---|---|---|
| 스테이지 | `STAGE` | 스테이지 하나 × 난이도 | 전체·주간 | 그 기간 그 스테이지 최고 점수 |
| 지역 | `REGION` | 지역 하나 × 난이도 | 전체·주간 | 그 지역 스테이지마다 최고 점수의 합(클리어 안 한 스테이지는 0). 지역 스테이지를 하나라도 클리어하면 들어감 |
| 전체 총합 | `TOTAL` | 모든 지역 × 난이도 | 전체·주간 | 모든 스테이지마다 최고 점수의 합(클리어 안 한 스테이지는 0). 스테이지를 하나라도 클리어하면 들어감 |
| 진행 | `PROGRESS` | 전체 | 전체만 | 클리어한 스테이지 수(난이도와 상관없음) |

**순서(모든 보드)**: 점수가 높을수록 위 → 같으면 **먼저 달성**한 쪽 → 그것도 같으면 **먼저 기록**된 쪽(서버가 매기는 기록 순번). 같은 순위는 없습니다.

| 항목 | 규칙 |
|---|---|
| 달성 시각 | 그 점수가 된 클리어 결과를 서버가 저장한 시각(R1 응답 `submittedAt`과 같은 값, 밀리초까지). 지역·전체 총합은 합이 마지막으로 오른 때, 진행은 그 수에 닿은 때 |
| 기록 순번 | 서버가 클리어를 기록할 때마다 하나씩 올리는 번호. 달성 시각이 같은 밀리초여도 먼저 기록된 쪽이 위 |
| 덮어쓰기 | 한 계정·스테이지·난이도의 최고 점수가 **오를 때만** 그 기록으로 통째로 바뀝니다(점수·시간·달성 시각·순번). 같은 점수의 늦은 클리어, 낮은 점수는 바꾸지 않습니다 |
| 들어가는 기록 | 서버가 검사를 통과시켜 저장한(R1 `SAVED`) **클리어** 결과만. 실패 결과, 같은 플레이의 재전송(`ALREADY_SAVED`)은 바꾸지 않습니다 |
| 반영 시점 | 결과 저장 직후(보통 1초 안). 게임은 결과 화면 뒤에 랭킹을 열면 됩니다 |

**기간**

| `period` | 뜻 | `periodKey` |
|---|---|---|
| `all`(기본) | 전체 기간 | `"all"` |
| `weekly` | 이번 주. 월요일 00:00 UTC(한국 시간 월요일 09:00)에 시작합니다 | ISO 주 `"2026-W42"` |

- 주간은 클리어의 달성 시각이 속한 주에 들어갑니다. 새 주가 되면 주간 보드는 비어서 시작합니다. 지난 주는 조회하지 않습니다.
- 진행 보드는 `all`만 있습니다.

## 쿼리(공통)

| 이름 | 쓰는 곳 | 타입 | 기본 | 규칙 |
|---|---|---|---|---|
| `difficulty` | RK1~4, RK7·RK8 | integer | 0 | 서버가 받는 난이도만(지금 0). 진행 보드에는 없음 |
| `period` | RK1~RK8 | string | `all` | `all` · `weekly`. 진행 보드(RK5·RK6)는 `all`만 |
| `limit` | RK1·3·5·7 | integer | 20 | 1~50 |
| `cursor` | RK1·3·5·7 | string | 없음(1위부터) | 앞 응답의 `nextCursor` **그대로** |

- 위 규칙에 맞지 않으면 400 `VALIDATION_FAILED`(`errors[].field` = 쿼리 이름)입니다. 모르는 쿼리 이름은 무시합니다.

## 줄 모양(공통)

**`board`**

| 필드 | 타입 | 설명 |
|---|---|---|
| `kind` | string | `STAGE` · `REGION` · `TOTAL` · `PROGRESS` |
| `targetId` | string \| null | 스테이지 키 · 지역 키. 전체 총합·진행은 `null` |
| `difficulty` | integer \| null | 난이도. 진행은 `null` |
| `period` | string | `all` · `weekly` |
| `periodKey` | string | 기간 표시 |

**줄(`items[]`)**

| 필드 | 타입 | 설명 |
|---|---|---|
| `rank` | integer | 순위(1부터) |
| `accountId` | string | 계정 ID |
| `nickname` | string | 닉네임(지금 값) |
| `score` | integer | 그 보드의 점수(진행은 클리어한 스테이지 수) |
| `achievedAt` | string | 달성 시각 |
| `playTimeSeconds` | number \| null | 스테이지 보드: 그 최고 점수의 클리어 시간(초, 소수 셋째 자리까지). 그 밖은 `null` |
| `clearedStageCount` | integer \| null | 지역·전체 총합 보드: 그 범위에서 클리어한 스테이지 수(그 난이도). 진행 보드: `score`와 같음. 스테이지 보드는 `null` |
| `furthestStageId` | string \| null | 진행 보드: 클리어한 스테이지 중 가장 뒤(지역 `order` → 스테이지 `order`). 그 밖은 `null` |

- 칸은 늘 있습니다(보드에 맞지 않는 칸은 `null`).

## RK1·RK3·RK5·RK7. 순위 목록

`GET /rankings/stages/{stageId}`, `GET /rankings/regions/{regionId}`, `GET /rankings/total`, `GET /rankings/progress`

**응답 `data`**

| 필드 | 타입 | 설명 |
|---|---|---|
| `board` | object | 위 `board` |
| `items` | array | 순위 순. 기록이 없으면 빈 배열 |
| `hasNext` | boolean | 뒤에 줄이 더 있나 |
| `nextCursor` | string \| null | 다음 묶음 커서. `hasNext`가 `false`면 `null`(칸은 늘 있음) |

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 찾음(기록이 없어도 200) | 성공 응답 |
| 400 | 쿼리 값이 틀림 / 받을 수 없는 커서 | `VALIDATION_FAILED` / `RANK_INVALID_CURSOR` |
| 401 | 인증 실패 | [인증 절의 네 코드](auth-api.md#인증-확인-순서와-실패-코드) |
| 404 | 없는 스테이지 / 없는 지역 | `STAGE_NOT_FOUND` / `REGION_NOT_FOUND` |
| 503 | MySQL·Redis에 닿지 못함 | `SERVICE_UNAVAILABLE`(`retryable: true`) |

예시: `examples/ranking-stage-list-response.json`, `examples/ranking-region-list-response.json`, `examples/ranking-total-list-response.json`, `examples/ranking-progress-list-response.json`, 커서 오류 `examples/ranking-error-invalid-cursor.json`

### 커서

- 커서는 서버가 만든 문자열입니다(200자 이하). 게임은 해석하거나 만들지 않고, 받은 값을 그대로 돌려보냅니다.
- 커서는 **마지막으로 받은 줄 다음부터**를 뜻합니다(순위 번호가 아님). 묶음 사이에 다른 기록이 끼어도 줄이 겹치거나 빠지지 않습니다. 대신 다음 묶음의 `rank`가 앞 묶음 마지막 + 1보다 클 수 있습니다. 게임은 받은 `rank`를 그대로 그립니다.
- 커서는 그 보드(대상·난이도·기간)에서만 통합니다. 다른 보드에 쓰거나 주간 커서를 주가 바뀐 뒤 쓰면 400 `RANK_INVALID_CURSOR`입니다. 게임은 커서를 버리고 첫 묶음부터 다시 받습니다.

## RK2·RK4·RK6·RK8. 내 줄

`GET /accounts/me/rankings/stages/{stageId}`, `GET /accounts/me/rankings/regions/{regionId}`, `GET /accounts/me/rankings/total`, `GET /accounts/me/rankings/progress`

**응답 `data`**

| 필드 | 타입 | 설명 |
|---|---|---|
| `board` | object | 위 `board` |
| `rank` | integer \| null | 내 순위. 그 보드에 내 기록이 없으면 `null` |
| `score` | integer \| null | 내 점수 |
| `achievedAt` | string \| null | 내 달성 시각 |
| `playTimeSeconds` · `clearedStageCount` · `furthestStageId` | | 줄 모양과 같음. 기록이 없으면 `null` |
| `totalCount` | integer | 그 보드에 기록이 있는 계정 수 |

상태 코드는 목록과 같습니다(커서 오류 없음). 예시: `examples/ranking-me-response.json`, 기록 없음 `examples/ranking-me-response-empty.json`

## 서버가 순위를 두는 곳과 장애 때 응답

| 저장소 | 맡는 것 |
|---|---|
| MySQL(원천) | 랭킹 클리어 기록(덧붙이기만, 기록 순번), 계정 × 스테이지 최고 기록, 계정 × 지역 점수, 계정 전체 총합, 계정 진행. 결과를 저장하는 같은 트랜잭션에서 고칩니다 |
| Redis(사본) | 보드마다 정렬된 순위. 결과가 커밋된 뒤 고칩니다. 지워지거나 어긋나면 MySQL에서 다시 채웁니다 |

| 상황 | 응답 |
|---|---|
| 평소 | Redis 보드로 답합니다 |
| 보드가 없음(처음, 만료, 새 주) | MySQL에서 채운 뒤 답합니다. 다른 서버가 채우는 중이면 MySQL로 답합니다 |
| Redis의 랭킹 명령만 실패(부분 장애) | MySQL로 답합니다. 순서·커서는 같습니다 |
| **Redis 전체 장애** | 응답하지 않습니다. 인증(세션 확인)에서 503 `SERVICE_UNAVAILABLE` |
| MySQL 장애 | 503 `SERVICE_UNAVAILABLE` |

- 결과 저장 뒤 Redis 고치기가 실패해도 결과 저장(R1)은 성공입니다. 그 서버는 그 보드를 "다시 채울 보드"로 표시하고, 다음에 그 보드를 쓸 때 MySQL에서 다시 채웁니다. 그 전까지 그 서버는 MySQL로 답합니다.
- 한계: 이 표시는 서버 메모리에 있습니다. 그 사이 서버가 다시 뜨면, 그 보드는 만료(전체 30일, 주간은 주 끝 + 14일)되거나 운영자가 키를 지울 때까지 기록 하나가 빠질 수 있습니다.

## 오류

기능 오류 코드 앞부분은 `RANK_`입니다. 인증 오류는 [auth-api.md 오류](auth-api.md#오류), 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `RANK_INVALID_CURSOR` | 400 | 서버가 준 적 없는 커서, 다른 보드의 커서, 주가 바뀐 주간 커서 | false | 커서를 버리고 첫 묶음부터 다시 받음. 안내 문구 없음 |

다른 명세의 코드를 이 API에서도 씁니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `STAGE_NOT_FOUND` · `REGION_NOT_FOUND` | 404 | 없는 키([stage-api.md](stage-api.md#오류)) | false | 게임·서버 키가 어긋난 버그. 로그 |
| `VALIDATION_FAILED` | 400 | 쿼리 값이 틀림 | false | 게임 버그. 로그 |
| `SERVICE_UNAVAILABLE` | 503 | MySQL·Redis에 닿지 못함 | true | "현재 서버에서 데이터를 불러올 수가 없습니다." + 다시 불러오기 |

## 유의사항(인계)

- **Redis 키 이름**: 랭킹은 `pw01:rank:*`, `pw01:rank-lock:*`를 씁니다. 다른 기능은 이 앞부분을 쓰지 않습니다.
- **"처리 중 표시" 키가 둘입니다**: 중복 방지의 `pw01:idem`(`IN_PROGRESS`)과 랭킹 다시 채우기 잠금 `pw01:rank-lock:<보드>`가 비슷한 일을 따로 합니다. 셋째 쓰임이 생기면 공용 틀로 묶을지 봅니다([redis-keys.md 랭킹 유의사항](redis-keys.md#랭킹-유의사항)).
- **결과 저장과의 연결**: 웹서버 결과 저장(result-api R1)이 같은 트랜잭션에서 랭킹 기록을 한 번 부릅니다. 재전송 길에서는 부르지 않습니다. 결과 저장 순서를 바꿀 때 이 호출을 결과 저장 **뒤**에 둡니다.
- **지난 결과**: 랭킹이 생기기 전에 저장된 결과는 순위에 없습니다.

## 정할 것

| 무엇 | 지금 | 누가 |
|---|---|---|
| 난이도 배수와 보드 | 배수 자리만(×1). 난이도가 생기면 "난이도별 보드 유지"와 "배수로 합친 하나의 보드" 중 고름 | Sang-Hyun-Kim |
| 지난 주 보드 조회, 시즌 | 없음 | Sang-Hyun-Kim |
| 결과 응답의 "새 기록·순위" 칸 | 없음. 넣으면 [result-api.md](result-api.md) v1.x | Robbie·Sang-Hyun-Kim |
| 정지된 계정을 순위에서 뺄지 | 빼지 않음 | Sang-Hyun-Kim |
| 다시 채울 보드 표시를 잃지 않게(아웃박스 표, 관리자 명령) | 서버 메모리 | Sang-Hyun-Kim |
| 순위가 바뀌면 실시간 알림 | 없음. 넣으면 [realtime-api.md](realtime-api.md) | Juunnmmoo·Sang-Hyun-Kim |
| 클리어 시간의 신뢰 | 게임이 보낸 값을 서버가 상한·경과 시간으로만 검사. 조작 여지가 남음 | Robbie |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-12 | 초안: 스테이지·지역 총합·전체 총합·진행 순위(진행 말고는 전체·주간), 점수(권장 클리어 시간에서 남은 시간, 1,000~10,000), 순서(점수 → 먼저 달성 → 먼저 기록), 덮어쓰기, RK1~RK8, 값 커서, 장애 때 응답(Redis 전체 장애는 503, 랭킹 명령만 실패하면 MySQL), 오류 `RANK_INVALID_CURSOR`, 유의사항 |
