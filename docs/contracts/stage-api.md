# 스테이지 API (Stage API)

> 버전: v1.5 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Sang-Hyun-Kim · 웹서버 담당: Sang-Hyun-Kim (리뷰: Robbie)

지역 → 스테이지 정의(모두에게 같음)와 내 진행(열림·잠김·클리어), 그리고 스테이지의 웨이브 구성·몬스터 정의·난이도입니다. 스테이지를 시작할 수 있는지는 스테이지 플레이 시작([stage-play-api.md](stage-play-api.md))에서 서버가 다시 확인합니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증). 인증이 필요한 요청은 부를 때마다 세션이 연장됩니다
- 아래 "응답 `data`" 표는 성공 응답의 `data` 안쪽 모양입니다. 실제 본문은 `{ "data": { … }, "meta": { "requestId": "…" } }`입니다.

## 키

| 키 | 모양 | 예 | 규칙 |
|---|---|---|---|
| 지역 키 `regionId` | 영문 소문자·숫자·`.`, 1~64자 | `region.01` | 한 번 정하면 바꾸지 않습니다 |
| 스테이지 키 `stageId` | 영문 소문자·숫자·`.`, 1~64자 | `stage.01.01` | UE `FName`과 같은 문자열입니다. 진행·결과 기록이 이 값을 가지므로 바꾸지 않습니다 |
| 몬스터 키 `monsterId` | 영문 소문자·숫자·`.`, 1~64자, `monster.`으로 시작 | `monster.samurai`, `monster.boss.warrior` | UE 몬스터 카탈로그(몬스터 키 → BP)의 키와 같은 문자열입니다. 진행 중 플레이의 웨이브 구성이 이 값을 가지므로 바꾸지 않습니다(바꿀 때는 새 키를 더함) |

- 서버는 키의 대소문자를 가립니다. UE `FName`은 대소문자를 가리지 않으므로 **소문자만 씁니다.** 게임은 서버 목록에서 받은 문자열을 그대로 보냅니다.
- 게임은 키를 잘라 번호를 읽지 않습니다. 순서는 `order`, 해금은 `requires`로 정합니다.
- 지역·스테이지·웨이브·몬스터·난이도 정의는 서버 정의 파일에 있습니다([서버 정의 파일](#서버-정의-파일)). 서버는 기동할 때 검사하고 틀리면 뜨지 않습니다. 배포 서버에서 웨이브 구성(`stage-waves.json`)만은 S3에서 읽고 재시작 없이 바꿀 수 있습니다(v1.5).

## 서버 정의 파일

웨이브 구성과 몬스터 정의의 **원본은 서버 파일**입니다(v1.3부터). 게임은 스테이지 플레이를 시작할 때 서버가 준 구성([stage-play-api.md 웨이브 구성](stage-play-api.md#웨이브-구성))으로 웨이브를 만들고, 스테이지 선택 화면의 미리보기도 ST1의 값을 씁니다. UE의 웨이브 DataAsset은 서버 없이 시험하는 개발용입니다.

| 파일 | 담는 것 | `version` | 배포 서버(prod)가 읽는 곳 |
|---|---|---|---|
| `master/stages.json` | 지역·스테이지(이름·순서·`requires`·`waveCount`·`recommendedClearSeconds`) | 없음 | 이미지 안 파일(배포로 바꿈) |
| `master/stage-waves.json` | 스테이지마다 웨이브 구성. `stageId`로 `stages.json`과 이어짐 | 있음 | **S3 객체 `content/stage-waves.json`**(재시작 없이 바꿈, [웨이브 구성 바꾸기](#웨이브-구성-바꾸기재시작-없이)) |
| `master/monsters.json` | 몬스터 정의(이름·보스 여부·기본 골드) | 있음 | 이미지 안 파일(배포로 바꿈) |
| `master/difficulties.json` | 난이도 목록(이름·랭킹 점수 배수)과 **기본 배율** | 있음 | 이미지 안 파일(배포로 바꿈) |

- 로컬·시험(`local`·`test` 프로필)은 네 파일 모두 이미지 안 `master/`에서 읽습니다. AWS가 없어도 됩니다.
- 배포 서버의 `stage-waves.json` 원본은 S3입니다. 이미지 안 같은 파일은 로컬·시험용 사본이고, S3에 처음 올리는 값도 이 파일입니다. 배포 서버가 뜰 때 S3를 읽지 못하면 서버가 뜨지 않습니다(배포는 이전 서버로 되돌아감).
- 웨이브 구성만 S3로 둔 이유: 실행 중에 바꿀 일이 있는 것은 웨이브 구성뿐입니다. 스테이지는 해금·랭킹 구조를, 난이도는 랭킹 점수 배수를 바꾸므로 배포로 바꿉니다. 새 몬스터는 게임의 새 빌드가 먼저 있어야 하므로 `monsters.json`도 배포와 함께 바뀝니다.

**`stage-waves.json`**

| 칸 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `version` | integer | 예 | 파일 버전(1 이상). 값을 바꾸면 1 올립니다 |
| `stages[].stageId` | string | 예 | `stages.json`의 스테이지 키 |
| `stages[].waves` | array | 예 | 웨이브 목록. **순서가 웨이브 번호**(1부터). 1개 이상 |
| `stages[].difficultyMultipliers` | object | 아니오 | 이 스테이지에서만 난이도 배율을 덮어씁니다([난이도](#난이도)). 키 = 난이도 번호 문자열(`"1"`, `"2"`…, **`"0"`은 안 됨**), 값 = 배율 칸 중 바꿀 칸만(`enemyCountMultiplier`·`enemyHealthMultiplier`·`enemyDamageMultiplier`·`goldAmountMultiplier`, 0보다 큼) |
| `waves[].restSeconds` | number | 아니오 | 이 웨이브 앞 쉬는 시간(초, 0 이상). 0이거나 없으면 게임 기본 쉬는 시간. 1웨이브 앞은 준비 시간이라 쓰지 않습니다 |
| `waves[].bossWave` | boolean | 아니오 | 보스 웨이브. 없으면 false |
| `waves[].goldChanceMultiplier` | number | 아니오 | 이 웨이브의 골드 확률 배율(0 이상). 없으면 1.0 |
| `waves[].goldAmountMultiplier` | number | 아니오 | 이 웨이브의 골드 양 배율(0 이상). 없으면 1.0 |
| `waves[].enemies` | array | 예 | 나올 적. 1줄 이상 |
| `enemies[].monsterId` | string | 예 | `monsters.json`의 몬스터 키 |
| `enemies[].count` | integer | 예 | 마리 수(1 이상). 난이도 0의 마리 수이자 다른 난이도 계산의 바탕([난이도](#난이도)) |
| `enemies[].countByDifficulty` | object | 아니오 | 이 줄의 난이도별 마리 수를 직접 정합니다. 키 = 난이도 번호 문자열(1 이상), 값 = 마리 수(1 이상). **그 난이도부터** 적용(계단식). 있으면 이 줄에는 마리 수 배율을 곱하지 않습니다 |
| `enemies[].spawnGroup` | string | 아니오 | 스폰 그룹 이름. 위치는 레벨(UE)이 정합니다. 없으면 기본 스폰 |
| `enemies[].boss` · `goldReward` · `goldDropChance` | | 아니오 | 이 줄에서만 몬스터 정의 값을 덮어씁니다. 없으면 `monsters.json` 값 |

**`monsters.json`**

| 칸 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `version` | integer | 예 | 파일 버전(1 이상). 값을 바꾸면 1 올립니다 |
| `monsters[].monsterId` | string | 예 | 몬스터 키 |
| `monsters[].name` | string | 예 | 화면 이름(미리보기) |
| `monsters[].boss` | boolean | 예 | 보스 몬스터 |
| `monsters[].goldReward` | integer | 예 | 한 마리 골드(0 이상) |
| `monsters[].goldDropChance` | number | 예 | 골드를 떨굴 확률(0~1) |

**`difficulties.json`**

| 칸 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `version` | integer | 예 | 파일 버전(1 이상). 값을 바꾸면 1 올립니다 |
| `difficulties[].difficulty` | integer | 예 | 난이도 번호. 0부터 빈틈없이. 스테이지 플레이·결과·랭킹의 `difficulty`와 같은 값 |
| `difficulties[].name` | string | 예 | 화면 이름 |
| `difficulties[].enemyCountMultiplier` | number | 예 | 기본 마리 수 배율(0보다 큼) |
| `difficulties[].enemyHealthMultiplier` | number | 예 | 기본 적 체력 배율(0보다 큼) |
| `difficulties[].enemyDamageMultiplier` | number | 예 | 기본 적 공격력 배율(0보다 큼) |
| `difficulties[].goldAmountMultiplier` | number | 예 | 기본 골드 양 배율(0보다 큼) |
| `difficulties[].scoreMultiplierPercent` | integer | 예 | 랭킹 점수 배수(%, 1 이상, [ranking-api.md 점수](ranking-api.md#점수)). 모든 스테이지 공통 |

- **난이도 0은 "난이도 조절 없음"**입니다. 배율은 모두 1.0, 점수 배수는 100이어야 하고 스테이지에서 덮어쓸 수 없습니다. v1.4 전에 시작한 플레이·결과·랭킹은 모두 난이도 0입니다.
- 지금 난이도: 0 이지, 1 노말, 2 하드(이름과 배율은 파일 값).

### 난이도

난이도는 **나오는 몬스터 종류는 그대로 두고 마리 수와 능력치만** 바꿉니다. 서버가 스테이지 플레이를 시작할 때 그 난이도의 값을 웨이브 구성에 반영해 플레이에 고정합니다([stage-play-api.md 웨이브 구성](stage-play-api.md#웨이브-구성)). 게임은 난이도 숫자로 계산하지 않고 받은 구성을 씁니다.

**그 스테이지의 배율**: 칸마다 `stage-waves.json`의 그 스테이지 `difficultyMultipliers[난이도]`에 있으면 그 값, 없으면 `difficulties.json`의 그 난이도 값입니다(칸 단위 덮어쓰기).

**적 한 줄의 난이도 d 마리 수**

| 줄 | 마리 수 |
|---|---|
| `countByDifficulty`가 없음(배율 줄) | 보스 줄(`boss` true)은 `count` 그대로. 나머지는 `max(1, round(count × 그 스테이지의 enemyCountMultiplier))`. 반올림은 0.5 올림 |
| `countByDifficulty`가 있음(직접 수 줄) | d 이하에서 가장 큰 키의 값. 그런 키가 없으면 `count`. 배율을 곱하지 않습니다 |

예: `{"count": 3, "countByDifficulty": {"1": 4, "2": 5}}` → 0: 3, 1: 4, 2: 5, 난이도 3을 더하면 3: 5(이어받음). `{"count": 2, "countByDifficulty": {"2": 3}}` → 0: 2, 1: 2, 2: 3.

**그 밖의 반영**
- 웨이브 골드 양 배율 = 웨이브 `goldAmountMultiplier` × 그 스테이지의 `goldAmountMultiplier`. 웨이브 골드 확률 배율은 그대로
- 적 줄마다 `healthMultiplier` = 그 스테이지의 `enemyHealthMultiplier`, `damageMultiplier` = 그 스테이지의 `enemyDamageMultiplier`. 게임이 그 적을 만들 때 체력(최대·현재)과 공격력에 곱합니다
- 웨이브 수(`waveCount`)와 줄(몬스터 종류)은 난이도와 상관없이 같습니다

**웨이브 정보 버전 `waveVersion`**: `"w{stage-waves.json version}-m{monsters.json version}-d{difficulties.json version}"`(예: `w2-m2-d1`). 웨이브 구성·몬스터·난이도 값을 바꾸면 달라집니다. v1.4 전에 시작한 플레이는 `w{n}-m{n}` 모양 그대로입니다. 스테이지 플레이에 시작 때 값이 저장되어 "어느 구성으로 한 판인가"를 알 수 있습니다. 체크포인트의 `contentVersion`(판 안 값 모양, 게임이 정함)과는 다른 값입니다.

**서버 기동 검사** (하나라도 틀리면 서버가 뜨지 않음)

- 몬스터: 키 모양, 중복 없음, `goldReward` ≥ 0, `goldDropChance` 0~1
- 두 파일 맞춤: `stages.json`의 모든 스테이지가 `stage-waves.json`에 정확히 한 번 있고, `stage-waves.json`에만 있는 스테이지가 없음
- 스테이지마다: `waves` 1개 이상, **`waveCount` = `waves` 수**, 웨이브마다 적 1줄 이상, 모르는 `monsterId` 없음, `count` ≥ 1, 배율 ≥ 0, 덮어쓴 골드·확률도 위 범위
- 난이도: 번호 0부터 빈틈없이·중복 없음, 0이 있음, 0의 배율 모두 1.0·점수 배수 100, 배율 > 0, 점수 배수 ≥ 1, 이름 비어 있지 않음
- `countByDifficulty`: 키는 있는 난이도이고 1 이상, 값 ≥ 1
- `difficultyMultipliers`: 키는 있는 난이도이고 1 이상, 값 > 0. 배율 네 칸 말고 다른 칸(예: `name`)은 파일 읽기 실패
- 세 파일 모두 `version` ≥ 1

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
| `waveVersion` | string | 지금 서버의 웨이브 정보 버전(예: `w2-m2-d1`) |
| `difficulties` | array | 난이도 목록. 번호 순 |
| `difficulties[].difficulty` | integer | 난이도 번호. 0부터 |
| `difficulties[].name` | string | 화면 이름 |
| `monsters` | array | 몬스터 정의(미리보기 이름용). `monsters.json` 순서 |
| `monsters[].monsterId` | string | 몬스터 키 |
| `monsters[].name` | string | 화면 이름 |
| `monsters[].boss` | boolean | 보스 몬스터 |
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
| `stages[].recommendedClearSeconds` | integer | 권장 클리어 시간(초, 1 이상). 랭킹 점수의 기준입니다([ranking-api.md 점수](ranking-api.md#점수)). 게임에 시간 제한은 없습니다 |
| `stages[].multipliers` | array | 이 스테이지에서 실제로 쓰는 난이도 배율(덮어쓰기 반영). 난이도 번호 순, 길이는 난이도 수 |
| `multipliers[].difficulty` | integer | 난이도 번호 |
| `multipliers[].enemyCountMultiplier` · `enemyHealthMultiplier` · `enemyDamageMultiplier` · `goldAmountMultiplier` | number | 그 난이도의 배율(안내 문구용. 마리 수는 아래 `counts`가 이미 반영) |
| `stages[].waves` | array | 웨이브 미리보기. 웨이브 번호 순, 길이는 `waveCount` |
| `waves[].waveNumber` | integer | 웨이브 번호. 1부터 |
| `waves[].bossWave` | boolean | 보스 웨이브 |
| `waves[].enemies` | array | 나올 적 |
| `enemies[].monsterId` | string | 몬스터 키. 이름은 `monsters`에서 찾습니다 |
| `enemies[].count` | integer | 난이도 0의 마리 수(= `counts[0]`) |
| `enemies[].counts` | integer[] | 난이도별 마리 수(서버가 계산한 값, [난이도](#난이도)). 난이도 번호 순, 모두 1 이상 |
| `enemies[].boss` | boolean | 이 줄이 보스인가(덮어쓰기 반영) |

- 미리보기에는 골드·확률·쉬는 시간을 싣지 않습니다. 실제 판의 구성은 스테이지 플레이 응답의 `waves`(시작 때 고정, 골드 포함)입니다.
- 게임은 몬스터 이름을 `monsters`에서 찾고, 없으면 키를 그대로 보입니다.
- 게임은 고른 난이도의 `counts[d]`·`multipliers[d]`를 보입니다. 마리 수를 직접 계산하지 않습니다(반올림·계단식 규칙이 서버에만 있음).

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
| 스테이지 플레이 시작 | 요청의 `stageId`가 없는 키면 `STAGE_NOT_FOUND`, 아직 열리지 않았으면 `STAGE_LOCKED`로 거절합니다. 통과하면 그 스테이지와 **그때의 `waveCount`·웨이브 구성(몬스터 값과 그 난이도를 반영한 것)·`waveVersion`**을 스테이지 플레이에 저장합니다. 스테이지가 열려 있으면 모든 난이도로 시작할 수 있습니다 |
| 결과 검사 | 결과 본문의 `stageId`가 스테이지 플레이에 저장한 스테이지와 다르면 거절합니다. 웨이브 기준은 **스테이지 플레이에 저장한 `waveCount`**입니다. 도달 웨이브는 0 이상 `waveCount` 이하이고, 클리어면 `waveCount`와 같아야 합니다. 게임이 보낸 전체 웨이브 수는 검사에 쓰지 않습니다. 거절 코드는 result-api.md에 있습니다 |
| 결과 저장 | 클리어 결과가 받아들여지면, 결과·보상과 **같이** 그 스테이지가 클리어로 기록됩니다. 기록하는 스테이지는 스테이지 플레이에 저장한 값입니다. 같은 스테이지 플레이의 재전송은 진행을 다시 바꾸지 않습니다 |

- 스테이지 플레이에 웨이브 수·구성을 저장하는 이유: 유효 시간(24시간) 사이에 서버 정의가 바뀌어도, 보관했다 다시 보낸 결과가 거절되지 않고 **이어한 판이 처음과 같은 적**으로 진행되게 하려고입니다.
- 게임의 시작 요청에는 선택 화면에서 고른 스테이지 키(`AWarriorStageGameMode`가 정한 값)를 보냅니다. 레벨 이름이 가면 `STAGE_NOT_FOUND`입니다. 난이도(`difficulty`, 선택 칸, 없으면 0)는 `difficulties.json`에 있는 번호만 받습니다(없는 번호는 400 `VALIDATION_FAILED`).
- 웨이브 구성의 원본은 서버 `master/stage-waves.json`입니다(v1.3부터, 그 전에는 UE DataAsset이 원본이고 `waveCount`는 손 사본이었음). 웨이브 수를 바꾸면 `stage-waves.json`의 `waves`와 `stages.json`의 `waveCount`를 함께 고칩니다(어긋나면 서버가 뜨지 않습니다).

## 서버 정의 바꾸기

| 바꾸고 싶은 것 | 고칠 곳 |
|---|---|
| 난이도의 세기(모든 스테이지) | `difficulties.json` 그 난이도의 배율 |
| 한 스테이지만 난이도 배율 다르게 | `stage-waves.json` 그 스테이지 `difficultyMultipliers`(바꿀 칸만) |
| 한 줄의 난이도별 마리 수를 정확히 | `stage-waves.json` 그 적 줄 `countByDifficulty` |
| 나오는 몬스터 종류·웨이브 | `stage-waves.json` 웨이브·적 줄(모든 난이도가 같이 바뀜) |
| 새 난이도 | `difficulties.json`에 줄 하나(다음 번호). 다르게 할 스테이지·줄에만 새 키. 나머지는 자동(배율 줄은 새 배율, 직접 수 줄은 아래 난이도 값을 이어받음) |
| 몬스터 기본 골드·이름 | `monsters.json` |
| 새 몬스터 | 게임 몬스터 카탈로그(키 → BP)를 먼저 배포한 뒤 `monsters.json`·`stage-waves.json`. 순서가 바뀌면 그 스테이지를 시작하지 못합니다([stage-play-api.md 웨이브 구성](stage-play-api.md#웨이브-구성)) |
| 몬스터 기본 체력·공격력 | 서버가 아니라 UE 에셋. 서버 배율은 이 값에 곱해집니다 |

- 바꾼 파일의 `version`을 1 올립니다(`waveVersion`이 달라짐). **새로 시작하는 플레이부터** 적용됩니다(진행 중·이어하기는 시작 때 구성).
- `stage-waves.json`만 바꿨으면 배포 서버는 재시작 없이 반영합니다(아래 절). `stages.json`·`monsters.json`·`difficulties.json`을 바꿨으면 이미지를 새로 만들어 배포해야 반영됩니다. 두 가지를 함께 바꿀 때는 **배포를 먼저** 하고 그다음 S3를 올립니다(새 난이도·새 몬스터를 가리키는 웨이브는 그 정의가 있는 서버에서만 검사를 통과합니다).
- 난이도는 빼지 않습니다. 지난 플레이와 랭킹(`d<난이도>` 보드)이 그 번호를 가집니다.

### 웨이브 구성 바꾸기(재시작 없이)

배포 서버(서버가 여러 대여도)에서 `stage-waves.json`을 바꾸는 순서입니다. 흐름도는 [server-wave.md ⑥](../flows/server-wave.md), 관리 포트 요청·응답은 [ops-health.md 웨이브 정의 다시 읽기](../flows/ops-health.md#웨이브-정의-다시-읽기)에 있습니다.

1. 고친 `stage-waves.json`의 `version`을 **새 숫자**로 올립니다(쓴 적 없는 숫자).
2. S3 콘솔에서 같은 키 `content/stage-waves.json`에 덮어씁니다. 버킷은 버전 관리가 켜져 있어 이전 파일이 남습니다.
3. 아무 서버 하나의 관리 포트에 다시 읽기를 보냅니다: `POST http://localhost:8081/actuator/stagecontent`(서버 안에서, 관리 포트는 밖에 열지 않음).
4. 그 서버가 읽고 검사해 바꾼 뒤 다른 서버에 "정의 바뀜"을 알리고, 다른 서버도 같은 일을 합니다(보통 1초 안).
5. 알림을 놓친 서버는 **5분마다** S3 객체가 바뀌었는지 확인해 따라옵니다. 3번을 건너뛰어도 5분 안에 반영됩니다.

**다시 읽을 때의 검사**(하나라도 걸리면 그 서버는 **이전 정의를 그대로** 쓰고 거절 이유를 로그·관리 포트에 남깁니다)

- 기동 검사와 같은 것: JSON 모양(모르는 칸 실패), 이미지 안 `stages.json`·`monsters.json`·`difficulties.json`과 맞음(스테이지 정확히 한 번, 웨이브 수 = `waveCount`, 아는 몬스터 키, 있는 난이도 키), 값 범위
- 내용이 바뀌었는데 `version`이 그대로면 거절(같은 `waveVersion`에 다른 구성이 저장되지 않게). 숫자가 내려가는 것(되돌리기)은 받습니다.

**되돌리기**: S3 콘솔에서 그 객체의 버전 목록을 열고 가장 위(최신) 버전을 지우면 바로 아래 버전이 다시 현재가 됩니다. 그 뒤 3번을 다시 합니다. 또는 git에 있는 이전 파일을 새 `version` 숫자로 다시 올립니다.

**바뀌는 것과 그대로인 것**

| 대상 | 다시 읽은 뒤 |
|---|---|
| 새로 시작하는 스테이지 플레이(P1) | 새 구성·새 `waveVersion` |
| 진행 중·이어하기(P2) | 시작 때 저장한 구성 그대로 |
| ST1 미리보기 | 다시 읽은 서버는 새 정의. 서버마다 바뀌는 시각이 잠깐 다를 수 있음(보통 1초, 최대 5분). 게임은 ST1을 게임을 끌 때까지 한 번만 받으므로 메인메뉴 미리보기는 게임을 다시 켜야 새 것 |
| 결과 검사·랭킹·해금 | 영향 없음(웨이브 수·스테이지·난이도는 이미지 안 파일) |

## 오류

이 명세만의 오류 코드입니다. 인증 오류는 [auth-api.md 오류](auth-api.md#오류), 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `STAGE_NOT_FOUND` | 404 | 없는 `stageId`로 스테이지 플레이를 시작함 | false | "스테이지 정보를 찾을 수 없습니다." 안내 후 메인메뉴. 게임·서버 키가 어긋난 버그입니다 |
| `STAGE_LOCKED` | 403 | 아직 열리지 않은 스테이지로 스테이지 플레이를 시작함 | false | "아직 열리지 않은 스테이지입니다." 안내 후 메인메뉴. 선택 화면이 먼저 막으므로 보통은 나오지 않습니다 |
| `REGION_NOT_FOUND` | 404 | 없는 `regionId`(지역 순위, [ranking-api.md](ranking-api.md)) | false | 게임·서버 키가 어긋난 버그. 로그 |

- `STAGE_NOT_FOUND`는 랭킹 API의 없는 `stageId`에도 씁니다.

- `STAGE_LOCKED`는 다시 보내도 결과가 같으므로 409(다시 보내면 될 수 있는 충돌)가 아니라 403으로 둡니다. 게임은 HTTP 상태가 아니라 `code`로 나눕니다(403 `ACCOUNT_SUSPENDED`와 섞이지 않음).
- 예시: `examples/stage-error-locked.json`

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-08 | 초안: 키 규칙, ST1 스테이지 정의(공개), ST2 내 스테이지 진행, 판 시작·결과에서의 약속(판에 웨이브 수 저장, 결과 본문의 스테이지 비교), 오류 두 개 |
| v1.1 | 2026-10-09 | 판 시작(`POST /runs`)·결과(`/runs/{runId}/result`)를 스테이지 플레이 API([stage-play-api.md](stage-play-api.md))와 새 결과 경로로 바꿈. "판"·"판 번호" 표기를 스테이지 플레이·스테이지 플레이 ID로. 예시 오류의 `path`. 동작·칸은 그대로 |
| v1.2 | 2026-10-12 | ST1 `stages[].recommendedClearSeconds`(권장 클리어 시간, 랭킹 점수 기준) 칸 추가, 오류 `REGION_NOT_FOUND`(랭킹 지역 순위). 응답 칸 추가라 호환 |
| v1.3 | 2026-10-14 | 웨이브 구성·몬스터 정의의 원본을 서버 파일로(M24): 몬스터 키 규칙, 서버 정의 파일 절(`stage-waves.json`·`monsters.json`, 덮어쓰기, `waveVersion` = `w{n}-m{n}`, 기동 검사). ST1에 `waveVersion`·`monsters`·`stages[].waves`(미리보기) 추가. 시작 때 구성·`waveVersion`도 플레이에 저장. "`waveCount`는 손 사본" 문장 고침. 응답 칸 추가라 호환 |
| v1.4 | 2026-10-15 | 난이도(M9): `master/difficulties.json`(이름·점수 배수·기본 배율, 0 = 조절 없음), `stage-waves.json`의 `difficultyMultipliers`(스테이지별 배율 덮어쓰기)·`countByDifficulty`(줄별 마리 수, 계단식), "난이도" 절(마리 수·배율 계산), `waveVersion` = `w{n}-m{n}-d{n}`, 기동 검사. ST1에 `difficulties`·`stages[].multipliers`·`enemies[].counts` 추가, `enemies[].count`는 난이도 0 값. 시작은 `difficulties.json`에 있는 난이도만. "서버 정의 바꾸기" 절. 응답 칸 추가라 호환 |
| v1.5 | 2026-10-17 | 웨이브 구성(`stage-waves.json`)의 배포 서버 원본을 S3로(판 12·M24 Lv5): "서버 정의 파일" 표에 읽는 곳, "웨이브 구성 바꾸기(재시작 없이)" 절(올림 → 관리 포트 다시 읽기 → 서버 사이 알림 → 5분 안전망, 다시 읽을 때의 검사, 되돌리기). 나머지 셋은 배포로. 게임이 받는 API 모양은 그대로 |
