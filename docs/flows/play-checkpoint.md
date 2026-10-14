# 플레이 체크포인트 흐름 (M22: 진행 중 스테이지 이어하기)

> 상태: 초안 · 명세: [stage-play-api.md 이어하기](../contracts/stage-play-api.md#이어하기), [C1·C2 체크포인트](../contracts/stage-play-api.md#c1c2-체크포인트) · Redis: [redis-keys.md 플레이 체크포인트](../contracts/redis-keys.md#플레이-체크포인트v14) · 재전송: [README.md 재전송 규칙](../contracts/README.md#재전송-규칙)

판 도중 게임이 꺼지거나 로그인 상태가 끝난 뒤 다시 로그인했을 때의 흐름입니다. 이어하기는 **같은 `stagePlayId`**로 합니다.
- ①~⑤ 1차(구현됨): 체크포인트 없이 **처음(1웨이브)부터**
- ⑥·⑦ 최종(명세 v1.2, 구현 중): 웨이브를 클리어할 때마다 체크포인트를 올리고, 이어할 때 **클리어한 웨이브 다음의 쉬는 시간부터** 그 판 안 값으로

## 참여자

| 이름 | 저장소·위치 | 하는 일 |
|---|---|---|
| `UWarriorAuthSubsystem` | 게임 `Auth/` | 로그인, 계정 값 적용, `OnLoginCompleted`·`OnSessionEnded` |
| `UWarriorApiSubsystem` | 게임 `Network/` | 보관 요청 재전송, 끝나면 `OnPendingResendFinished` |
| `UWarriorPlayCheckpointSubsystem` | 게임 `Network/` | 로그인 뒤 진행 중 플레이 확인, 이어하기·포기 |
| `UWarriorStagePlaySubsystem` | 게임 `Network/` | P1·P2·P4·결과 제출 |
| `UWarriorStageLaunchSubsystem` | 게임 `Stage/` | 고른 스테이지와 이어하기 정보(`FWarriorStageResumeInfo`) |
| `AWarriorFrontPlayerController` | 게임 `Controllers/` | 메인메뉴, 이어하기 팝업 |
| `AWarriorStageGameMode` | 게임 `GameModes/` | `BeginRun`(플레이 시작), `FinishRun`(결과) |
| `StagePlayController` | 웹서버 `stageplay/` | `/accounts/me/stage-plays` |
| `WarriorPlayCheckpoint` | 게임 `Stage/` | 판 안 값 꺼내기(`Capture`)·넣기(`Restore`) (⑥⑦) |
| 체크포인트 API·Redis | 웹서버 `stageplay/`, Redis `pw01:play-checkpoint:` | C1 저장·C2 받기, 판이 끝나면 삭제 (⑥⑦) |

## ① 판 도중 강제 종료 → 다시 로그인 → 이어하기

```mermaid
sequenceDiagram
  autonumber
  participant FPC as AWarriorFrontPlayerController
  participant Auth as UWarriorAuthSubsystem
  participant Api as UWarriorApiSubsystem
  participant CP as UWarriorPlayCheckpointSubsystem
  participant SP as UWarriorStagePlaySubsystem
  participant SL as UWarriorStageLaunchSubsystem
  participant GM as AWarriorStageGameMode
  participant WS as 웹서버 StagePlayController

  Note over GM,WS: 3웨이브 중 앱 강제 종료. 서버 플레이는 IN_PROGRESS로 남음
  FPC->>Auth: 로그인
  Auth-->>Auth: 계정 값 적용(ApplyAccountSnapshot)
  Auth-->>Api: OnLoginCompleted
  Auth-->>CP: OnLoginCompleted (확인 대기)
  Auth-->>FPC: OnLoginCompleted → 메인메뉴(입력 막음)
  Api->>Api: ResendPending (보관 파일 없음)
  Api-->>CP: OnPendingResendFinished(0, 0)
  CP->>SP: RequestCurrentStagePlay
  SP->>WS: GET /accounts/me/stage-plays/current
  WS-->>SP: 200 IN_PROGRESS (stagePlayId, stageId, expiresAt)
  SP-->>CP: InProgress
  CP->>CP: 보관 결과 없음 확인(FindByKey)
  CP-->>FPC: OnPlayCheckpointChecked(Resumable)
  FPC->>FPC: 팝업 "진행 중인 스테이지가 있습니다. 이어하시겠습니까?"
  FPC->>CP: Resume (이어하기)
  CP->>SL: SelectStageForResume(stageId, ResumeInfo)
  CP->>FPC: 레벨 열기
  GM->>SL: ConsumeResumeInfo (BeginRun)
  GM->>SP: StartStagePlay(stageId, Resume)
  Note over SP: P1을 부르지 않고 같은 stagePlayId를 씀
  Note over GM: 1웨이브부터, 판 안 값은 처음 값
  GM->>SP: SubmitResult (FinishRun)
  SP->>WS: POST /accounts/me/stage-plays/{id}/result
  WS-->>SP: 200 SAVED
```

## ② 팝업 → 포기

```mermaid
sequenceDiagram
  autonumber
  participant FPC as AWarriorFrontPlayerController
  participant CP as UWarriorPlayCheckpointSubsystem
  participant SP as UWarriorStagePlaySubsystem
  participant WS as 웹서버 StagePlayController

  Note over FPC: ①의 팝업까지 같음
  FPC->>CP: Abandon (포기)
  CP->>SP: AbandonStagePlay(stagePlayId)
  SP->>WS: POST /accounts/me/stage-plays/{id}/abandon
  alt 200 / 404 / 409 STAGE_PLAY_NOT_IN_PROGRESS
    WS-->>SP: 응답
    SP-->>CP: 끝남
    CP-->>FPC: 메인메뉴(입력 풂)
  else 연결 실패 / 5xx
    WS-->>SP: 실패
    SP-->>CP: 실패
    CP-->>FPC: 안내 "포기하지 못했습니다. 다음 로그인 때 다시 묻습니다." → 메인메뉴
  end
```

## ③ 진행 중 플레이 없음

```mermaid
sequenceDiagram
  autonumber
  participant FPC as AWarriorFrontPlayerController
  participant Api as UWarriorApiSubsystem
  participant CP as UWarriorPlayCheckpointSubsystem
  participant SP as UWarriorStagePlaySubsystem
  participant WS as 웹서버 StagePlayController

  Api-->>CP: OnPendingResendFinished
  CP->>SP: RequestCurrentStagePlay
  SP->>WS: GET /accounts/me/stage-plays/current
  WS-->>SP: 204
  SP-->>CP: None
  CP-->>FPC: OnPlayCheckpointChecked(None) → 메인메뉴(입력 풂)
```

## ④ 보관 결과가 있음 → 재전송이 먼저

```mermaid
sequenceDiagram
  autonumber
  participant FPC as AWarriorFrontPlayerController
  participant Api as UWarriorApiSubsystem
  participant CP as UWarriorPlayCheckpointSubsystem
  participant SP as UWarriorStagePlaySubsystem
  participant WS as 웹서버

  Note over Api: 서버가 꺼진 채 판이 끝나 결과가 디스크에 보관됨
  Api->>WS: POST …/{id}/result (보관본, 같은 requestId)
  alt 재전송 성공
    WS-->>Api: 200 SAVED (플레이 끝남)
    Api-->>CP: OnPendingResendFinished(1, 0)
    CP->>SP: RequestCurrentStagePlay
    SP->>WS: GET …/current
    WS-->>SP: 204
    CP-->>FPC: None → 메인메뉴
  else 재시도할 수 있는 실패(보관본 남음)
    WS-->>Api: 503
    Api-->>CP: OnPendingResendFinished(0, 0)
    CP->>SP: RequestCurrentStagePlay
    SP->>WS: GET …/current
    WS-->>SP: 200 IN_PROGRESS
    CP->>CP: 그 플레이의 보관 결과 있음(FindByKey)
    CP-->>FPC: Blocked → 팝업 없이 메인메뉴(다음 로그인 때 다시 재전송)
  end
```

## ⑤ 마감이 지남

```mermaid
sequenceDiagram
  autonumber
  participant CP as UWarriorPlayCheckpointSubsystem
  participant SP as UWarriorStagePlaySubsystem
  participant WS as 웹서버 StagePlayController
  participant FPC as AWarriorFrontPlayerController

  Note over WS: 시작 + 24시간이 지난 IN_PROGRESS 플레이
  CP->>SP: RequestCurrentStagePlay
  SP->>WS: GET /accounts/me/stage-plays/current
  WS->>WS: EXPIRED로 바꿈(endReason EXPIRED)
  WS-->>SP: 204
  CP-->>FPC: None → 메인메뉴
```

## ⑥ 웨이브 클리어 → 체크포인트 올리기

마지막 웨이브가 아니면 클리어할 때마다 올립니다. 실패해도 판은 계속되고 디스크에 보관하지 않습니다(다음 웨이브 클리어 때 새로 올림).

```mermaid
sequenceDiagram
  autonumber
  participant GM as AWarriorStageGameMode
  participant CPL as WarriorPlayCheckpoint
  participant CP as UWarriorPlayCheckpointSubsystem
  participant SP as UWarriorStagePlaySubsystem
  participant WS as 웹서버 StagePlayController
  participant R as Redis

  Note over GM: 웨이브 N 클리어(WaveCleared, 보상 반영 뒤). N < 전체 웨이브
  GM->>CPL: Capture
  CPL-->>GM: 판 안 값(골드·아이템·강화·체력·통계·시간)
  GM->>CP: 체크포인트 올리기
  CP->>SP: C1
  SP->>WS: PUT /accounts/me/stage-plays/{id}/checkpoint {contentVersion, clearedWave: N, elapsedSeconds, state}
  WS->>WS: 내 플레이·진행 중·마감·값 검사
  WS->>R: play_checkpoint_put.lua (저장된 clearedWave ≤ N 이면 SET, 만료 = 마감)
  alt 저장함
    R-->>WS: 1
    WS-->>SP: 200 {clearedWave: N, savedAt}
  else 뒤로 감
    R-->>WS: -1
    WS-->>SP: 409 CHECKPOINT_OUT_OF_ORDER
  else 연결 실패·5xx
    WS-->>SP: 실패
  end
  Note over GM: 결과와 관계없이 쉬는 시간 → 웨이브 N+1 진행
```

## ⑦ 판 도중 강제 종료 → 다시 로그인 → 체크포인트에서 이어하기

```mermaid
sequenceDiagram
  autonumber
  participant FPC as AWarriorFrontPlayerController
  participant CP as UWarriorPlayCheckpointSubsystem
  participant SP as UWarriorStagePlaySubsystem
  participant SL as UWarriorStageLaunchSubsystem
  participant GM as AWarriorStageGameMode
  participant CPL as WarriorPlayCheckpoint
  participant WS as 웹서버

  Note over GM,WS: 웨이브 2 클리어(체크포인트 저장) → 웨이브 3 도중 강제 종료
  Note over CP: 로그인 → 재전송 끝(①과 같음)
  CP->>SP: RequestCurrentStagePlay
  SP->>WS: GET /accounts/me/stage-plays/current
  WS-->>SP: 200 IN_PROGRESS
  CP->>SP: 체크포인트 받기
  SP->>WS: GET /accounts/me/stage-plays/{id}/checkpoint
  alt 200이고 contentVersion이 같음
    WS-->>SP: 200 {clearedWave: 2, state}
    CP-->>FPC: Resumable(체크포인트)
    FPC->>FPC: 팝업 "3웨이브부터 이어서 합니다 · 골드 · 체력"
  else 204 · 버전 다름 · 실패
    CP-->>FPC: Resumable(처음부터)
    FPC->>FPC: 팝업 "처음(1웨이브)부터 다시 시작합니다"
  end
  FPC->>CP: Resume (이어하기)
  CP->>SL: SelectStageForResume(stageId, ResumeInfo{stagePlayId, Checkpoint})
  CP->>FPC: 레벨 열기
  GM->>SL: ConsumeResumeInfo (BeginRun)
  GM->>CPL: Restore(강화 → GAS 현재값 → 인벤토리 → 판 통계)
  GM->>GM: CurrentWaveIndex = 2 - 1, 웨이브 표시 2/5
  GM->>SP: StartStagePlay(stageId, &ResumeInfo) (P1 없음, 같은 ID)
  Note over GM: Initializing → Resting(준비 시간 대신) → 웨이브 3
  Note over GM: 결과 playTimeSeconds = elapsedSeconds + 이어한 뒤 시간
```
