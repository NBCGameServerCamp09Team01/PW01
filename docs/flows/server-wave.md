# 서버 웨이브 구성 흐름 (M24: 서버 주관 웨이브 · 몬스터 카탈로그, M9: 난이도)

> 상태: 초안(구현 전) · 명세: [stage-api.md 서버 정의 파일](../contracts/stage-api.md#서버-정의-파일)·[난이도](../contracts/stage-api.md#난이도), [stage-play-api.md 웨이브 구성](../contracts/stage-play-api.md#웨이브-구성), [이어하기](../contracts/stage-play-api.md#이어하기) · 함께 보기: [play-checkpoint.md](play-checkpoint.md)

웨이브 구성(몬스터·수·보스·골드·쉬는 시간)의 원본은 **서버 파일**입니다. 서버는 판을 시작할 때 구성을 만들어 플레이에 고정하고, 게임은 받은 구성으로만 웨이브를 만듭니다. 이어하기도 같은 구성을 씁니다.
- ①~② 판 시작(보통·체크포인트에서 이어하기)
- ③~④ 구성을 쓸 수 없을 때
- ⑤ 스테이지 선택 미리보기
- ⑥ 서버: 기동 검사, 정의가 바뀐 뒤의 진행 중 판
- ⑦ 난이도 고르기 → 서버가 반영한 구성 → 적 능력치 배율(M9, 작성안)

`(새)`는 M24에서 새로 만드는 클래스·함수입니다.

## 참여자

| 이름 | 저장소·위치 | 하는 일 |
|---|---|---|
| `AWarriorStageGameMode` | 게임 `GameModes/` | `BeginRun`(플레이 시작·체크포인트 넣기), `OnWavePlanChanged`를 받아 FlowManager에 웨이브를 넣음(`ApplyServerWavePlan`), 못 쓰면 `FailRunStart` |
| `UWarriorStagePlaySubsystem` | 게임 `Network/` | P1, `StartStagePlay`, `ApplyWavePlan`(새, 구성 입구), `OnWavePlanChanged`·`GetWavePlanState`(새) |
| `UWarriorMonsterCatalogDataAsset`·`DA_MonsterCatalog` (새) | 게임 `Stage/` | 몬스터 키 → BP |
| `AWarriorStageFlowManager` | 게임 `Stage/` | 웨이브 데이터 보관, 웨이브마다 스포너에 넘김 |
| `UWarriorPlayCheckpointSubsystem` | 게임 `Network/` | 로그인 뒤 P2·C2, 이어하기 팝업 판단(`CanResumeInThisBuild`) |
| `UWarriorStageLaunchSubsystem` | 게임 `Stage/` | 이어하기 정보 `FWarriorStageResumeInfo`(`Play` 칸 새로) |
| `UWarriorApiSubsystem` | 게임 `Network/` | `PresentError`(오류 문구 표 → 팝업) |
| `UWarriorStageListSubsystem` | 게임 `Network/` | 스테이지 선택 화면 데이터(ST1·ST2), `BuildWaveInfo` |
| `StagePlayController`·`StagePlayService` | 웹서버 `stageplay/` | P1~P4, 시작 때 구성 고정 |
| `StageCatalog`·`StageMasterValidator` | 웹서버 `stage/` | 정의 파일 읽기·기동 검사·풀어 둔 구성 |
| `StageWaveMasterFile`·`MonsterMasterFile` (새) | 웹서버 `stage/master/` | `master/stage-waves.json`·`master/monsters.json` |
| `StageController` | 웹서버 `stage/` | ST1 `GET /stages` |

## ① 보통 시작

```mermaid
sequenceDiagram
  autonumber
  participant GM as AWarriorStageGameMode
  participant SP as UWarriorStagePlaySubsystem
  participant MC as DA_MonsterCatalog
  participant FM as AWarriorStageFlowManager
  participant WS as 웹서버 StagePlayService

  Note over GM: TryFinishInitialize → BeginRun (FlowManager 등록됨, 웨이브는 아직 없음)
  GM->>SP: StartStagePlay(stageId)
  SP->>SP: 이전 플레이 ID·구성 비움(ClearWavePlan)
  SP->>WS: P1 POST /accounts/me/stage-plays
  Note over GM: StageReady → Preparing(준비 시간)
  WS->>WS: 스테이지 확인 → waves 만들기(몬스터 값 풀기) → wave_plan·wave_version·wave_count 저장
  WS-->>SP: 201 {stagePlayId, waveCount, waveVersion, waves}
  SP->>SP: ApplyWavePlan(응답 waves)
  SP->>MC: monsterId → BP (모두 있음)
  SP-->>GM: OnWavePlanChanged(Ready)
  GM->>FM: SetStageWaveData + 총 웨이브 수, GameState 표시
  Note over GM: 준비 시간 끝 + 구성 준비됨 → 1웨이브
```

## ② 체크포인트에서 이어하기

로그인 때 받은 P2 응답의 구성을 이어하기 정보에 실어 옵니다. 레벨을 연 뒤에는 서버에 다시 묻지 않습니다. **구성을 체크포인트보다 먼저** 넣습니다(체크포인트 범위 검사가 총 웨이브 수를 씀).

```mermaid
sequenceDiagram
  autonumber
  participant CP as UWarriorPlayCheckpointSubsystem
  participant WS as 웹서버
  participant SL as UWarriorStageLaunchSubsystem
  participant GM as AWarriorStageGameMode
  participant SP as UWarriorStagePlaySubsystem
  participant FM as AWarriorStageFlowManager

  Note over GM,WS: 웨이브 2 클리어(C1 저장) → 웨이브 3 도중 강제 종료
  CP->>WS: P2 GET /accounts/me/stage-plays/current
  WS-->>CP: 200 {stagePlayId, waveVersion, waves(시작 때 고정)}
  CP->>WS: C2 GET /accounts/me/stage-plays/{id}/checkpoint
  WS-->>CP: 200 {contentVersion, clearedWave: 2, state}
  CP->>CP: CanResumeInThisBuild(스테이지·waves·monsterId 모두 있음)
  Note over CP: 팝업 [이어하기] / [포기] → 이어하기
  CP->>SL: SelectStageForResume(ResumeInfo{stagePlayId, Checkpoint, WavePlan})
  GM->>SL: ConsumeResumeInfo (BeginRun)
  GM->>SP: ① StartStagePlay(stageId, &ResumeInfo) (P1 없음, 같은 ID)
  SP->>SP: 구성 비움 → ApplyWavePlan(ResumeInfo.WavePlan)
  SP-->>GM: OnWavePlanChanged(Ready, 바로)
  GM->>FM: SetStageWaveData + 총 5
  GM->>GM: ② ApplyResumeCheckpoint (총 5 기준 범위 검사 → Restore → CurrentWaveIndex = 1)
  Note over GM: StageReady → Resting → 웨이브 3 = waves[2]
```

- 체크포인트가 없는 이어하기(C2 204·버전 다름·실패)는 같은 길에서 ②만 건너뛰고 1웨이브부터 합니다.
- 체크포인트에는 구성이 없습니다. 구성은 플레이(`wave_plan`), 어디까지 깼는지는 체크포인트(Redis)에 있고 둘 다 같은 `stagePlayId`입니다.

## ③ 구성을 쓸 수 없음 → 판을 시작하지 않음

```mermaid
flowchart TD
  A["BeginRun 뒤"] --> B{"구성 준비됨?"}
  B -- 예 --> W["준비(또는 쉬는) 시간이 끝나면 웨이브 시작"]
  B -- 아니요 --> C{"실패가 확정됐나?<br>P1 실패 · 응답 없음(ServerWaveWaitSeconds) ·<br>waves 없음 · 카탈로그에 없는 monsterId"}
  C -- 아니요 --> A
  C -- 예 --> D{"개발 빌드 + bAllowLocalWaveFallback<br>+ 서버 플레이 ID 없음?"}
  D -- 예 --> L["UE 웨이브 DataAsset으로 진행(경고 로그)"]
  D -- 아니요 --> E["UWarriorApiSubsystem::PresentError(코드)<br>문구는 오류 문구 표"]
  E --> M["메인메뉴(코드와 관계없이)"]
```

| 경우 | 코드 | 어디서 |
|---|---|---|
| P1이 오류 응답 | 서버 코드 그대로(`STAGE_LOCKED`·`STAGE_NOT_FOUND`·`SERVICE_UNAVAILABLE` 등) | 서버 |
| P1 연결 실패 | `NETWORK_ERROR` | 게임 |
| 준비 시간이 끝난 뒤에도 응답이 없음 | `STAGE_WAVE_PLAN_TIMEOUT` | 게임 안 코드 |
| 응답에 `waves`가 없거나 `null` | `STAGE_WAVE_PLAN_MISSING` | 게임 안 코드 |
| 카탈로그에 없는 `monsterId` | `STAGE_WAVE_MONSTER_UNKNOWN` | 게임 안 코드 |

- 서버 플레이 ID가 없는 판은 디버그 명령 `Warrior.Checkpoint.ResumeLevel`이나 서버 없이 하는 시험뿐입니다. 서버 판에는 로컬 DataAsset의 적이 섞이지 않습니다.

## ④ 이어하기 팝업: 이 빌드에서 열 수 없는 플레이

판 시작 단계에서 실패하면 플레이가 진행 중으로 남아 로그인마다 같은 실패가 되풀이됩니다. 그래서 팝업에서 먼저 거릅니다.

```mermaid
sequenceDiagram
  autonumber
  participant FPC as AWarriorFrontPlayerController
  participant CP as UWarriorPlayCheckpointSubsystem
  participant MC as DA_MonsterCatalog
  participant SP as UWarriorStagePlaySubsystem
  participant WS as 웹서버

  Note over CP: P2 200 {waves: [..., monster.new.thing, ...]} (이 빌드 카탈로그에 없음)
  CP-->>FPC: OnPlayCheckpointChecked(Resumable)
  FPC->>CP: CanResumeInThisBuild
  CP->>MC: 모든 monsterId 확인
  MC-->>CP: monster.new.thing 없음
  CP-->>FPC: false
  FPC->>FPC: 팝업 버튼 [포기]만
  FPC->>CP: Abandon
  CP->>SP: AbandonStagePlay(stagePlayId)
  SP->>WS: P4 POST /accounts/me/stage-plays/{id}/abandon
  WS-->>SP: 200 (FAILED, ABANDONED, 체크포인트 지움)
  CP-->>FPC: 메인메뉴(다음 로그인 때 묻지 않음)
```

- 같은 이유로 스테이지가 이 빌드의 목록에 없거나 `waves`가 `null`이어도 [포기]만입니다.

## ⑤ 스테이지 선택 미리보기

```mermaid
sequenceDiagram
  autonumber
  participant SLS as UWarriorStageListSubsystem
  participant WS as 웹서버 StageController

  SLS->>WS: ST1 GET /stages
  WS-->>SLS: 200 {waveVersion, monsters[], regions[].stages[].waves[]}
  SLS->>WS: ST2 GET /accounts/me/stages
  WS-->>SLS: 200 {stages[].status}
  SLS->>SLS: RebuildRegions → BuildWaveInfo(서버 waves, 이름은 monsters[].name)
  Note over SLS: UE 웨이브 DataAsset을 읽지 않음. 이름이 없으면 monsterId를 그대로 보임
```

- 미리보기는 **지금** 서버 정의입니다. 진행 중인 판의 구성(시작 때 고정)과 `waveVersion`이 다를 수 있습니다.

## ⑥ 서버: 기동 검사와 정의가 바뀐 뒤

```mermaid
sequenceDiagram
  autonumber
  participant OP as 운영(파일 수정·재시작)
  participant CAT as StageCatalog · StageMasterValidator
  participant SPS as StagePlayService
  participant DB as MySQL stage_play
  participant G as 게임

  OP->>CAT: 기동: stages.json + stage-waves.json(version 1) + monsters.json(version 1)
  CAT->>CAT: 검사(두 파일 stageId 맞춤, waveCount = waves 수, 모르는 monsterId 없음, …)
  Note over CAT: 하나라도 틀리면 서버가 뜨지 않음
  G->>SPS: P1 (stage.01.01)
  SPS->>DB: wave_count 5, wave_plan(w1-m1 구성), wave_version "w1-m1"
  OP->>CAT: stage-waves.json 4웨이브 수정, version 2 → 재시작
  G->>SPS: P2 (같은 플레이, 이어하기)
  SPS->>DB: 읽기
  SPS-->>G: 200 {waveVersion "w1-m1", waves(처음 구성)}
  G->>SPS: 새 P1 (다른 판)
  SPS->>DB: wave_version "w2-m1", 새 구성
```

- v1.3 배포 전에 시작한 플레이는 `wave_plan`이 비어 있습니다. 응답할 때 지금 정의로 채우고, 지금 웨이브 수가 그 플레이의 `waveCount`와 다르면 `waves`·`waveVersion`을 `null`로 보냅니다(게임은 ③·④대로).

## ⑦ 난이도 (M9, 작성안)

난이도는 몬스터 종류를 바꾸지 않고 **마리 수와 능력치만** 바꿉니다. 서버가 P1 때 그 난이도를 구성에 반영해 고정하므로 게임은 계산하지 않습니다. 이어하기는 P2의 `difficulty`·`waves`를 그대로 씁니다.

```mermaid
sequenceDiagram
  autonumber
  participant UI as UWarriorStageSelectPopupWidget
  participant SL as UWarriorStageLaunchSubsystem
  participant GM as AWarriorStageGameMode
  participant SP as UWarriorStagePlaySubsystem
  participant WS as 웹서버 StagePlayService
  participant CAT as StageCatalog
  participant SPN as AWarriorWaveSpawner
  participant AI as AWarriorAICharacter

  UI->>UI: 난이도 버튼(ST1 difficulties), 처음엔 0, 그 뒤엔 마지막에 고른 값
  UI->>SL: SelectStage(stageId, difficulty)
  SL-->>GM: 레벨 열기 → LaunchInfo.Difficulty
  GM->>SP: StartStagePlay(stageId, difficulty)
  SP->>WS: P1 {stageId, difficulty}
  WS->>CAT: 그 스테이지·그 난이도의 구성
  CAT-->>WS: 마리 수(배율 줄 / countByDifficulty 계단식), 골드 배율, healthMultiplier·damageMultiplier
  WS-->>SP: 201 {difficulty, waveVersion "w…-m…-d…", waves}
  SP-->>GM: OnWavePlanChanged(Ready), 판 난이도 = 응답 difficulty
  GM->>SPN: 웨이브 시작(마리 수·골드는 이미 반영)
  SPN->>AI: 스폰 → 배율 전달
  AI->>AI: 시작 GE 적용(비동기) 뒤 최대·현재 체력, 공격력에 곱함 → Initializing 해제
  Note over GM: 결과 R1의 difficulty = 판 난이도 → 랭킹은 그 난이도 보드
```

| 경우 | 처리 |
|---|---|
| 서버에 없는 난이도 | P1 400 `VALIDATION_FAILED` → ③대로 판 시작 안 함 |
| 같은 `requestId`로 다른 난이도 | 409 `IDEMPOTENCY_KEY_REUSED`(게임 버그) |
| 이어하기 | P2 `difficulty`를 이어하기 정보에 실음. 구성에 배율이 들어 있어 따로 계산 안 함 |
| v1.4 전 플레이·구성 | 난이도 0, 적 줄 배율 칸이 없으면 1.0 |
| 서버 플레이 없음(개발 시험) | 난이도 0, 배율 1.0, UE 웨이브 DataAsset |
