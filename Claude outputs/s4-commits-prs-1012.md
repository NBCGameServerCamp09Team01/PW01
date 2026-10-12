# S4 스킬 해금: 커밋·PR 초안 (10/12, 웹서버·루트)

> 기준: S4 계획서 `s4-skill-unlock-plan-1011.md`, 회의 안건 `s4-sang-agenda-1012.md`(c가 정한 것·S1~S3 결정).
> 커밋·push는 직접 합니다. 각 저장소 폴더 안에서 실행합니다(`git rev-parse --show-toplevel`로 확인).
> 게임(UE) 쪽은 아직 시작 전이라 이 문서에 없습니다.

## 0. 확인한 것

| 항목 | 결과 |
|---|---|
| 웹서버 `gradlew clean build` | **229개 통과**(dev 210 + S4 19) |
| Postman `pw01-s4-skill-unlock-1012` | 24요청 전부 통과(사용자 확인) |
| 커밋 나눈 단계 컴파일 | 1번만, 1+2번 상태를 임시 작업 폴더에서 `compileJava` 통과 |
| 마이그레이션 번호 | `origin/dev` 마지막 V6 → **V7** 그대로(10/12 확인) |
| 웹서버 기준 브랜치 | `dev` = 3dbd353, 브랜치를 만든 뒤 바뀌지 않음 |

---

## 1. 루트 `PW01` — `docs/s4-skill-api` (리뷰: Sang, b)

이미 커밋함: `39c478f docs: 스킬 해금 API 명세 v1, 계정 API v1.2, 오류 본문 기능별 추가 칸`

⚠ 이 커밋에 `Claude outputs/s4-sang-agenda-1012.md`가 같이 들어갔습니다(아직 push 전). push 전에 빼야 합니다(대화에서 방법 확인).

**base 고르기**: S3 루트 PR(`docs/s3-stat-api`)이 아직 `main`에 병합되지 않았습니다. 이 브랜치는 그 위에서 만들었습니다.
- S3 PR이 먼저 병합되면 → base `main`
- 그 전에 올리면 → base `docs/s3-stat-api`(S4 변경만 보임). S3가 병합된 뒤 base를 `main`으로 바꿉니다.

PR 제목: `docs: 스킬 해금 API 명세 v1, 계정 API v1.2, 오류 본문 기능별 추가 칸`

PR 본문
```markdown
## 무엇
- `skill-api.md` v1(새): K1 `POST /accounts/me/skill-unlocks`, K2 `GET /accounts/me/skills`
  - 스킬 3개(Combo4·DodgeMastery·CounterPlus, 시연용 목표 값), 조건 종류 8개와 서버 재료, 서버가 판정하지 않는 종류
  - 조건 미충족 응답 `requirements`(조건 전부 + 충족 여부, UE `FWarriorSkillRequirementProgress`와 같은 칸)
- `account-api.md` v1.2: `unlockedSkills`를 S4에서 채움(태그 이름순, 통째로 교체)
- `README.md` 공통 규칙: 오류 본문의 **기능별 추가 칸**(10/12 S1), `errors` 설명 보완(기능 오류에도 붙음)
- 예시 JSON 6개

## 10/12에 정한 것
| # | 정한 것 |
|---|---|
| S1 | 오류 본문에 기능 명세가 정한 추가 칸 허용(`requirements`) |
| S2 | `DA_SkillTree`를 3개로, 서버가 판정하는 조건만 |
| S8 | K2 서버 진행도 조회를 이번에 함 |
| 목표 값 | 시연용으로 낮게(마스터 데이터라 리허설 뒤 조정) |

## 계획서와 다르게 정한 것
- 기억 시간이 지난 뒤 같은 `requestId`가 오면 **200 `ALREADY_SAVED`**(README 재전송 규칙과 같게). 새 `requestId`로 이미 해금한 스킬은 409 `SKILL_ALREADY_UNLOCKED`.

## 리뷰 부탁
- **Sang**: README 오류 본문 "기능별 추가 칸" 줄, 조건 종류 표
- **b**: K2 응답 모양이 스킬 화면에 맞는지(`FWarriorSkillView`)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## 2. 웹서버 `PW01WebServer` — `feat/s4-skill` → `dev` (리뷰: Sang)

| 순서 | 파일 | 커밋 |
|---|---|---|
| 1 | `common/error/ErrorResponse.java`·`ApiException.java`·`ConflictException.java`·`GlobalExceptionHandler.java` | 2-1 |
| 2 | `progression/`(새), `skill/`(새), `account/entity/AccountSkill.java`·`AccountSkillId.java`(새)·`AccountLedger.java`, `account/repository/AccountSkillRepository.java`(새)·`AccountStatTotalRepository.java`, `account/service/AccountService.java`·`SkillUnlockResult.java`(새), `account/dto/AccountSnapshotResponse.java`, `stageresult/service/StageResultService.java`·`ResultTotals.java`(새), `stageresult/repository/StageResultTotalsQuery.java`(새), `db/migration/V7__create_account_skill.sql`(새), `master/skills.json`(새), `docs/migrations.md` | 2-2 |
| 3 | `account/service/StatTotalReconciler.java`(새), `config/StatTotalProperties.java`·`StatTotalConfig.java`(새), `account/repository/AccountRepository.java`, `src/main/resources/application.properties` | 2-3 |
| 4 | `src/test/java/com/pw01/webserver/skill/`(새), `src/test/java/com/pw01/webserver/account/StatTotalReconcilerTest.java`(새) | 2-4 |

```bat
set B=src/main/java/com/pw01/webserver
git add %B%/common/error/ErrorResponse.java %B%/common/error/ApiException.java %B%/common/error/ConflictException.java %B%/common/error/GlobalExceptionHandler.java
git commit
git add %B%/progression %B%/skill %B%/account/entity/AccountSkill.java %B%/account/entity/AccountSkillId.java %B%/account/entity/AccountLedger.java %B%/account/repository/AccountSkillRepository.java %B%/account/repository/AccountStatTotalRepository.java %B%/account/service/AccountService.java %B%/account/service/SkillUnlockResult.java %B%/account/dto/AccountSnapshotResponse.java %B%/stageresult/service/StageResultService.java %B%/stageresult/service/ResultTotals.java %B%/stageresult/repository/StageResultTotalsQuery.java src/main/resources/db/migration/V7__create_account_skill.sql src/main/resources/master/skills.json docs/migrations.md
git commit
git add %B%/account/service/StatTotalReconciler.java %B%/config/StatTotalProperties.java %B%/config/StatTotalConfig.java %B%/account/repository/AccountRepository.java src/main/resources/application.properties
git commit
git add src/test/java/com/pw01/webserver/skill src/test/java/com/pw01/webserver/account/StatTotalReconcilerTest.java
git commit
```
(PowerShell이면 `set B=…` 대신 `$B="src/main/java/com/pw01/webserver"`, `%B%` 대신 `$B`)

- 2번에 대조용 조회(`StageResultTotalsQuery`, `AccountStatTotalRepository.totals(목록)`·`replaceIf`)가 같이 들어갑니다. 같은 파일 안에 해금용 코드가 있어서 파일을 나누지 않았습니다. 대조를 실제로 돌리는 코드는 3번입니다.

2-1
```text
feat: 오류 본문에 기능별 추가 칸(S1)

- ApiException·ConflictException이 추가 칸(이름 → 값)을 들고, ErrorResponse가 본문 최상위 칸으로 펼침(@JsonAnyGetter)
- 추가 칸이 없으면 본문은 그대로. 기존 ErrorResponse.of(5인자)는 그대로 둠(실시간 연결이 씀)
- 명세: 루트 docs/contracts/README.md "오류 응답" 기능별 추가 칸(10/12 S1)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

2-2
```text
feat: 스킬 해금·진행도 API, 조건 판정기, 해금 재료 누적 키

- K1 POST /accounts/me/skill-unlocks: 선행·포인트·누적 기록 판정, 미충족이면 409 + requirements(조건 전부)
- K2 GET /accounts/me/skills: 스킬마다 상태(LOCKED·NEED_POINTS·UNLOCKABLE·UNLOCKED)와 진행도
- 조건 판정기(progression/requirement): 스킬을 모름, 조건 하나 = 판정기 빈 한 줄. 업적도 같은 판정기를 쓸 수 있음
- 새 표 account_skill(V7, 기본 키 = 계정 + 스킬), 변경 내역 SKILL_UNLOCK(source_id = requestId:스킬태그)
- 누적 키 3개: 플레이 시간 합계, 최대 웨이브(최댓값), 최고 클리어(최솟값, 클리어만). V7에서 기존 결과로 처음 값 채움
- skills.json(SF-7) + SkillCatalog 기동 검사(판정 안 하는 조건·key·없는 선행·순환·태그 27자)
- 계정 스냅샷 unlockedSkills(태그 이름순). 중복 방지 SF-5·진행 저장 SF-6을 그대로 씀
- 명세: 루트 docs/contracts/skill-api.md v1, account-api.md v1.2

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

2-3
```text
feat: 누적 통계 대조(전용 스케줄러)

- StatTotalReconciler: 결과 표를 계정별로 다시 모아 account_stat_total이 어긋났으면 결과 표 값으로 고침(경고 로그 + 줄 수)
- 고칠 때는 "읽은 값 그대로일 때만" 바꿔 그사이 들어온 새 결과를 덮지 않음
- @EnableScheduling을 켜지 않고 전용 스케줄러(RealtimeHeartbeat와 같은 방식, 10/12 S9)
- 설정 pw01.stat-total.reconcile.enabled·interval(6h)·batch-size(500)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

2-4
```text
test: 스킬 해금·진행도·누적 통계 대조 시험

- 해금 성공, 포인트 부족(requirements), 선행 없음, 없는 스킬, 이미 해금, 같은 요청 두 번, 기억이 사라진 뒤 ALREADY_SAVED
- 조건별 경계값, K2 상태 4가지, 같은 스킬 동시 해금, 결과마다 누적 키 쌓임, 401
- skills.json 기동 검사(단위), 대조: 어긋난 값 고침·결과 없는 계정 비움

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

PR 제목: `feat: 스킬 해금·진행도 API, 조건 판정기·누적 통계 대조 뼈대`

PR 본문
```markdown
## 무엇
- K1 `POST /accounts/me/skill-unlocks`, K2 `GET /accounts/me/skills`
- 오류 본문 기능별 추가 칸(`requirements`)
- 해금 재료 누적 키 3개 + 누적 통계 대조
- 명세: 루트 `docs/contracts/skill-api.md` v1, `account-api.md` v1.2, README 오류 본문 (루트 PR 링크)

## 뼈대
| 뼈대 | 위치 | 이어 쓰는 법 |
|---|---|---|
| 조건 판정기 | `progression/requirement/` | 조건 하나 더하기 = `RequirementEvaluatorConfig`에 빈 한 줄(+ 재료가 없으면 누적 키). 업적·퀘스트는 자기 마스터에서 같은 조건 모양을 읽어 `RequirementEvaluatorRegistry`를 부르면 됨 |
| 누적 통계 대조 | `account/service/StatTotalReconciler` | 누적 키를 더하면 `SUM_KEYS`·`RECORD_KEYS`와 `StageResultTotalsQuery` 집계에 한 줄 |
| 오류 추가 칸 | `ConflictException(code, message, Map)` | 기능 명세에 칸을 적고 Map으로 넘김 |
| 마스터(SF-7) | `master/skills.json` + `SkillCatalog` | 스킬 하나 = JSON 한 줄(UE `DA_SkillTree`도) |

## 바뀐 것 (커밋 순서)
1. `feat` 오류 본문 기능별 추가 칸(공통 코드 4개)
2. `feat` 해금·진행도·판정기·누적 키 3개, V7
3. `feat` 누적 통계 대조(전용 스케줄러)
4. `test` `SkillApiTest`(12), `SkillCatalogTest`(5), `StatTotalReconcilerTest`(2)

## S2 코드에 닿은 곳
- `AccountService.grantStageReward`: 인자 2개 추가(`reachedWave`, `playTimeMs`), 누적 키 3개 쓰기
- `StageResultService`: `playTimeMs`를 보상 계산 전에 구함(값은 같음), 대조용 `totalsByAccount`
- 결과 응답·동작은 바뀌지 않음(기존 시험 그대로 통과)

## 설정 값
| 설정 | 기본값 |
|---|---|
| `pw01.stat-total.reconcile.enabled` | true |
| `pw01.stat-total.reconcile.interval` | 6h |
| `pw01.stat-total.reconcile.batch-size` | 500 |

## 확인
- `gradlew clean build`: **229개 통과**(dev 210 + 19)
- Postman `pw01-s4-skill-unlock-1012` 24요청 전부 통과: 새 계정 → 미충족 409 → 클리어 → 해금 → 재전송 → 두 번째 클리어 → 나머지 두 스킬 → 재로그인 뒤 `unlockedSkills` 3개
- 마이그레이션 V7: `dev` 마지막 V6 확인(10/12)

## 리뷰 부탁
- **Sang**: 1번 커밋(공통 오류 코드), V7(누적 키 처음 값 채우기 SQL), 대조의 조건부 덮어쓰기
- 웹서버 `AGENTS.md:57` "@EnableScheduling은 켜지 않았습니다(heartbeat는 전용 스케줄러)"에 대조도 전용 스케줄러라고 적을지

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## 3. 디스코드 공지 초안

```text
[S4 스킬 해금 웹서버 PR 올렸습니다] 루트 명세 → 웹서버 순서로 리뷰 부탁드립니다. 게임(UE)은 이어서 작업합니다.

새 API
- K1 POST /accounts/me/skill-unlocks (해금), K2 GET /accounts/me/skills (서버 진행도)
- 조건이 모자라면 409 SKILL_REQUIREMENTS_NOT_MET + requirements(조건 전부)

새 뼈대
- 조건 판정기: progression/requirement (조건 하나 = 빈 한 줄, 업적도 같이 쓸 수 있음)
- 누적 통계 대조: StatTotalReconciler (전용 스케줄러, @EnableScheduling 안 켬)
- 오류 본문 기능별 추가 칸: ConflictException(code, message, Map)

바뀐 약속
- README 오류 본문에 "기능별 추가 칸" 허용
- account-api v1.2: unlockedSkills 채움
- 마이그레이션 V7(account_skill) 사용합니다
- account_stat_total에 키 3개 추가(stage_play.play_time_ms·max_wave·best_clear_ms). 랭킹은 지금처럼 결과 표를 스테이지별로 읽으면 됩니다

리뷰: Sang(공통 오류 코드, V7, 대조), b(K2 응답 모양)
```

---

## 4. 루트 명세 추가 커밋 — `docs/s4-skill-api`

UE 작업 중 효과가 바뀌어(회피는 스태미나를 쓰지 않음) 스킬 표의 효과 칸을 고쳤습니다.

```bat
git add docs/contracts/skill-api.md
git commit
```

```text
docs: 스킬 효과 설명을 시연용 효과로

- 회피 숙련: 회피 스태미나 감소 → 해금해야 회피(더블 탭 스텝)를 쓸 수 있음(회피 GA는 스태미나 비용이 없음, MCP 확인)
- 반격 강화: 반격 데미지 ×1.5
- 효과 수치·켜기는 UE 프로젝트 설정 Warrior Skill Effects. 시연용이라 바뀔 수 있음

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

---

## 5. 게임 `ProjectWarrior` — `feature/s4-skill-ue` → `dev` (리뷰: Sang, leejunhyeok3907)

기준: `dev` c24be8dc(브랜치를 만든 뒤 바뀌지 않음 → 병합 없이 커밋). 넣지 않는 것: `BP_StageGameMode.uasset`, `.idea/`, `Docs/worklog-code-session.md`.

| 순서 | 파일 | 커밋 |
|---|---|---|
| 1 | `Source/ProjectWarrior/Network/WarriorSkillUnlockTypes.h`·`WarriorSkillUnlockSubsystem.h`·`.cpp`(새) | 5-1 |
| 2 | `Source/ProjectWarrior/Skill/WarriorSkillLibrary.h`·`.cpp`, `WarriorSkillWidget.h`·`.cpp`, `WarriorSkillEntryWidget.cpp`, `Source/ProjectWarrior/Account/WarriorAccountSubsystem.h`·`.cpp` | 5-2 |
| 3 | `Source/ProjectWarrior/Skill/WarriorSkillEffectSettings.h`(새), `Source/ProjectWarrior/Characters/WarriorPlayerCharacter.h`·`.cpp`, `Source/ProjectWarrior/AbilitySystem/Abilities/PlayerGameplayAbility.h`·`.cpp`, `Config/DefaultGame.ini` | 5-3 |
| 4 | `Content/MyGameContents/Skill/DA_SkillTree.uasset`, `Content/MyGameContents/UI/Front/WBP_Skill.uasset` | 5-4 |

```bat
git add Source/ProjectWarrior/Network/WarriorSkillUnlockTypes.h Source/ProjectWarrior/Network/WarriorSkillUnlockSubsystem.h Source/ProjectWarrior/Network/WarriorSkillUnlockSubsystem.cpp
git commit
git add Source/ProjectWarrior/Skill/WarriorSkillLibrary.h Source/ProjectWarrior/Skill/WarriorSkillLibrary.cpp Source/ProjectWarrior/Skill/WarriorSkillWidget.h Source/ProjectWarrior/Skill/WarriorSkillWidget.cpp Source/ProjectWarrior/Skill/WarriorSkillEntryWidget.cpp Source/ProjectWarrior/Account/WarriorAccountSubsystem.h Source/ProjectWarrior/Account/WarriorAccountSubsystem.cpp
git commit
git add Source/ProjectWarrior/Skill/WarriorSkillEffectSettings.h Source/ProjectWarrior/Characters/WarriorPlayerCharacter.h Source/ProjectWarrior/Characters/WarriorPlayerCharacter.cpp Source/ProjectWarrior/AbilitySystem/Abilities/PlayerGameplayAbility.h Source/ProjectWarrior/AbilitySystem/Abilities/PlayerGameplayAbility.cpp Config/DefaultGame.ini
git commit
git lfs status
git add Content/MyGameContents/Skill/DA_SkillTree.uasset Content/MyGameContents/UI/Front/WBP_Skill.uasset
git commit
```

- 커밋마다 따로 빌드해 보지는 않았습니다(파일 의존 관계로만 확인). 순서: 1번 서브시스템 → 2번이 그것을 씀 → 3번 효과는 독립. 4개를 모두 넣은 상태는 빌드 통과(10/12).

5-1
```text
feat: 스킬 해금 서브시스템 추가(서버 해금·진행도)

- UWarriorSkillUnlockSubsystem.RequestUnlock: POST /accounts/me/skill-unlocks, 성공하면 ApplyAccountSnapshot 뒤 진행도 다시 받음
- RequestSkills: GET /accounts/me/skills. 진행도 JSON은 직접 읽음(current null = 기록 없음), 로그인 세션이 바뀌면 버림
- retryable이면 같은 본문(같은 requestId)으로 다시. 횟수는 Config UnlockMaxAttempts=2
- 로그인하지 않았으면 NOT_LOGGED_IN(로컬 해금 길 없음, 10/12 S10)
- 명세: 루트 docs/contracts/skill-api.md v1

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

5-2
```text
feat: 스킬 화면을 서버 해금·진행도로, 로컬 해금 삭제

- 스킬 화면이 열리면 서버 진행도(K2)를 받아 DA 화면 값에 덮어씀(ApplyServerProgress). 받기 전·로그인 전에는 로컬 값
- 해금 버튼은 서버로. 응답을 기다리는 동안 버튼 끔, 결과 문구는 Text_Message·BP_OnUnlockFinished
- 삭제: UWarriorSkillLibrary::TryUnlockSkill, UWarriorAccountSubsystem::UnlockSkill·UnlockSkillWithCost·GetSkillCost·SkillCosts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

5-3
```text
feat: 해금한 스킬 효과(회피 해금, 반격 강화)

- 캐릭터가 스테이지에 들어올 때 해금 태그(Account.Skill.*)를 능력 시스템에 붙임(ApplyAccountSkillTags)
- 회피 숙련: 해금해야 회피(Player.Ability.Dodge)가 나감(UPlayerGameplayAbility::CanActivateAbility). 구르기는 그대로
- 반격 강화: 반격 데미지·균형 데미지 ×1.5(GA_Player_Counter는 균형 데미지를 씀, MCP 확인)
- 프로젝트 설정 Warrior Skill Effects(DefaultGame.ini): CounterPlusDamageMultiplier, bDodgeRequiresDodgeMastery. 시연용
- GA .uasset은 고치지 않음(C++ 기본 클래스에서 처리)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

5-4
```text
content: 스킬 트리 3개로, 스킬 화면 결과 문구 칸

- DA_SkillTree: Combo4·DodgeMastery·CounterPlus(서버 master/skills.json과 같은 비용·조건), 설명 문구를 효과에 맞춤
- 강공격·강공격 강화·처형 숙련은 뺌(태그는 남김, 서버가 판정하지 않는 조건을 쓰고 있었음)
- WBP_Skill: Text_Message(해금 결과 문구)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

PR 제목: `feat: 스킬 해금을 서버에 저장하고 해금 효과 적용(S4)`

PR 본문
```markdown
## 무엇
- 스킬 화면의 해금을 서버로(`POST /accounts/me/skill-unlocks`), 진행도를 서버 판정 값으로(`GET /accounts/me/skills`)
- 해금한 스킬 효과: 회피 숙련 = 해금해야 회피 사용, 반격 강화 = 반격 데미지 ×1.5 (콤보 4타 효과는 다음 PR)
- 로컬 해금 삭제(로그인하지 않으면 "로그인이 필요합니다.")
- 명세: 루트 `docs/contracts/skill-api.md` v1 (루트 PR 링크), 웹서버 PR (링크)

## 바뀐 파일
| 파일 | 바꾼 것 |
|---|---|
| `Network/WarriorSkillUnlockTypes.h`·`WarriorSkillUnlockSubsystem.h/.cpp` | 새: 해금 요청·재시도·응답 적용, 서버 진행도 받기 |
| `Skill/WarriorSkillLibrary.h/.cpp` | `ApplyServerProgress`(서버 값 덮어쓰기), `TryUnlockSkill` 삭제 |
| `Skill/WarriorSkillWidget.h/.cpp`·`WarriorSkillEntryWidget.cpp` | 서버 해금·진행도, 대기 중 버튼 끔, `Text_Message`·`BP_OnUnlockFinished` |
| `Account/WarriorAccountSubsystem.h/.cpp` | 로컬 해금 4개 삭제 |
| `Characters/WarriorPlayerCharacter.h/.cpp` | `ApplyAccountSkillTags()` |
| `AbilitySystem/Abilities/PlayerGameplayAbility.h/.cpp` | `CanActivateAbility`(회피 해금), `ApplyCounterPlus`(데미지·균형 데미지) |
| `Skill/WarriorSkillEffectSettings.h`, `Config/DefaultGame.ini` | 효과 설정, `UnlockMaxAttempts` |
| `DA_SkillTree`·`WBP_Skill` | 스킬 3개, 결과 문구 칸 |

## 확인
- 빌드 통과(에디터)
- PIE(서버 켬): 스킬 해금 성공 확인
- MCP로 읽어 확인: 회피·구르기·반격 GA는 비용 0·비용 GE 없음, 반격은 `Make Player Balance Damage Effect Spec Handle` 사용 → GA .uasset 수정 없이 C++에서 처리

## 리뷰 부탁
- **leejunhyeok3907**: `PlayerGameplayAbility`(회피 발동 조건, 반격 배율)·캐릭터 `ApplyAccountSkillTags`. **새 계정은 회피 숙련을 해금하기 전까지 회피가 안 나갑니다**(시연용, 설정 `bDodgeRequiresDodgeMastery=False`로 끔)
- **Sang**: `WarriorAccountSubsystem` 로컬 해금 삭제, `DA_SkillTree` 3개(10/12 S2 승인)
- 넣지 않은 것: 콤보 4타 효과(`GA_Katana_LightAttack_04`, 다음 작업)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```
