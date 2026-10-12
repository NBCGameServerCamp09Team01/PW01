# 스킬 해금 API (Skill API)

> 버전: v1 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Robbie · 웹서버 담당: Robbie (리뷰: Sang-Hyun-Kim)

스킬 화면에서 해금을 누르면, 서버가 **선행 스킬·스탯 포인트·누적 기록 조건을 판정**해 되면 저장하고, 모자라면 **조건 전부의 진행도**를 돌려줍니다. 해금 전에도 서버 기준 진행도를 받아 화면에 그릴 수 있습니다. 같은 요청이 두 번 와도 한 번만 반영합니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 다시 보내기·한 번만 반영: [README.md 상태를 바꾸는 요청과 재전송](README.md#상태를-바꾸는-요청과-재전송)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증). 아래 API는 모두 인증이 필요합니다
- 계정 스냅샷(`unlockedSkills`·`statPoints`): [account-api.md](account-api.md#계정-스냅샷)
- 아래 "응답 `data`" 표는 성공 응답의 `data` 안쪽 모양입니다.

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| K1 | POST | `/accounts/me/skill-unlocks` | 필요 | 200 | 스킬 하나 해금 |
| K2 | GET | `/accounts/me/skills` | 필요 | 200 | 스킬마다 상태와 조건 진행도(서버 판정) |

- 해금한 스킬 목록만 필요하면 로그인 응답과 `GET /accounts/me`의 `unlockedSkills`로 받습니다. K2는 스킬 화면이 진행도를 그릴 때 씁니다.

## 스킬

| 스킬 태그 | 비용(스탯 포인트) | 선행 스킬 | 조건 | 게임 효과 |
|---|---|---|---|---|
| `Account.Skill.Combo4` | 1 | — | 스테이지 클리어 1회 이상 | 약공격 4타가 나가게 됨(해금 전에는 3타에서 콤보가 끝남) |
| `Account.Skill.DodgeMastery` | 2 | — | 계정 레벨 3 이상, 누적 플레이 120초 이상 | 회피(더블 탭 스텝)를 쓸 수 있게 됨(해금 전에는 회피가 나가지 않음) |
| `Account.Skill.CounterPlus` | 2 | `Account.Skill.Combo4` | 누적 처치 10 이상, 최대 도달 웨이브 3 이상, 최고 클리어 시간 900초 이하 | 반격 데미지 ×1.5 |

- 서버 판정 기준은 웹서버 리소스 `master/skills.json`입니다. UE `DA_SkillTree`와 같은 값으로 맞춥니다(손으로). 둘이 어긋나면 서버 값으로 판정합니다(게임은 거절 응답을 받음).
- 목표 값은 시연용입니다. 바꿀 때는 `skills.json`과 `DA_SkillTree`를 같이 고치고 이 표를 고칩니다. 서버 코드는 바꾸지 않습니다.
- 게임 효과는 UE가 적용합니다(해금 태그가 있으면 능력이 바뀜). 서버는 해금 여부만 판정·저장합니다. 효과 수치와 켜기·끄기는 UE 프로젝트 설정 `Warrior Skill Effects`(`DefaultGame.ini`)에 있고, 시연용이라 바뀔 수 있습니다.

## 조건 종류

| `type` | 뜻 | 비교 | 서버 재료 | UE `EWarriorSkillRequirementType` |
|---|---|---|---|---|
| `PREREQUISITE` | 선행 스킬을 해금했나(`key` = 스킬 태그) | 해금 = 1 | 해금한 스킬 | `Prerequisites`(DA의 선행 목록) |
| `STAT_POINTS` | 비용만큼 남은 스탯 포인트 | 이상 | 남은 포인트 | `StatPointCost` |
| `ACCOUNT_LEVEL` | 계정 레벨 | 이상 | 계정 레벨 | `AccountLevel` |
| `STAGES_CLEARED` | 스테이지 클리어 횟수 | 이상 | 누적 `stage_play.cleared` | `StagesCleared` |
| `TOTAL_KILLS` | 누적 처치 수(적 종류 구분 없음) | 이상 | 누적 `stage_play.kills` | `TotalKills`(`Key` 없음) |
| `PLAY_TIME_SECONDS` | 누적 플레이 시간(초) | 이상 | 누적 `stage_play.play_time_ms` ÷ 1000 | `PlayTimeSeconds` |
| `MAX_WAVE_REACHED` | 가장 멀리 간 웨이브(클리어하면 그 스테이지 웨이브 수) | 이상 | 최댓값 `stage_play.max_wave` | `MaxWaveReached` |
| `BEST_CLEAR_TIME` | 가장 빠른 클리어 시간(초). 클리어한 적이 없으면 미충족 | **이하** | 최솟값 `stage_play.best_clear_ms` ÷ 1000 | `BestClearTime` |

- 누적 기록은 서버가 결과를 저장할 때 쌓습니다([result-api.md](result-api.md)). 게임 PC의 로컬 통계와 다를 수 있고, **판정은 서버 값으로** 합니다. 같은 결과가 다시 와도 두 번 쌓지 않습니다.
- **서버가 판정하지 않는 종류**: `KillsByDeathType`, 적 종류별 `TotalKills`(`Key` 있음), `TotalDamage`, `MaxDamage`, `ExtraStat`. 서버에 재료가 없어서, `skills.json`에 넣으면 서버가 뜨지 않습니다. 쓰려면 결과 요청에 재료를 더하는 명세 변경이 먼저입니다.

## K1. 스킬 해금 — `POST /accounts/me/skill-unlocks`

스킬 화면에서 해금 버튼을 눌렀을 때 부릅니다.

요청

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `requestId` | string(UUID) | 예 | 이 요청의 번호(소문자·하이픈 36자). **다시 보낼 때 같은 값** |
| `skillTag` | string | 예 | [스킬](#스킬) 태그 |

예시: `examples/skill-unlock-request.json`

### 판정 순서

| 순서 | 판정 | 걸리면 |
|---|---|---|
| 0 | 형식(필수·UUID·모르는 칸) | 400 `VALIDATION_FAILED` · `INVALID_REQUEST_BODY` |
| 1 | 같은 `requestId`가 이미 처리됐나 | [README 재전송](README.md#상태를-바꾸는-요청과-재전송): 처음 응답 / 처리 중 / 다른 본문 |
| 2 | `skillTag`가 [스킬](#스킬)에 있나 | 400 `SKILL_UNKNOWN`(`errors`에 `skillTag`) |
| 3 | 이 `requestId`로 이미 해금했나 | 200 `saveStatus: ALREADY_SAVED` + 지금 값(아래 "한 번만 반영") |
| 4 | 다른 요청으로 이미 해금한 스킬인가 | 409 `SKILL_ALREADY_UNLOCKED` |
| 5 | [조건](#조건-종류) 전부: 선행 스킬 + 스탯 포인트 + 누적 기록 | 하나라도 미충족 → 409 `SKILL_REQUIREMENTS_NOT_MET` + `requirements`(조건 전부) |
| 6 | 저장 | 아래 |

- 저장(한 트랜잭션): 남은 포인트에서 비용을 빼고, 해금 한 줄, 변경 내역 한 줄. 계정 `version`이 1 오릅니다.
- 같은 계정의 다른 저장(결과 보상·투자 등)과 부딪히면 서버가 몇 번 다시 하고, 넘으면 409 `VERSION_CONFLICT`(`retryable: true`).
- 5번에서 걸리면 **아무것도 저장하지 않습니다.** 포인트만 모자라도 같은 코드이고, `requirements`의 `STAT_POINTS` 줄이 `met: false`입니다.

### 응답

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 해금함, 또는 이미 이 요청으로 해금됨 | 성공 응답, `data`는 아래 표 |
| 400 | 형식, 없는 스킬 | `VALIDATION_FAILED` · `INVALID_REQUEST_BODY` · `SKILL_UNKNOWN` |
| 401 | 인증 실패 | auth-api.md 네 코드 |
| 409 | 조건 미충족, 이미 해금, 같은 키 다른 본문, 처리 중, 저장 충돌 | `SKILL_REQUIREMENTS_NOT_MET` · `SKILL_ALREADY_UNLOCKED` · `IDEMPOTENCY_KEY_REUSED` · `REQUEST_IN_PROGRESS` · `VERSION_CONFLICT` |
| 503 | MySQL·Redis에 닿지 못함 | `SERVICE_UNAVAILABLE`(`retryable: true`) |

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `result.skillTag` | string | 해금한 스킬 |
| `result.unlockedSkills` | string[] | 반영 뒤 해금한 스킬 **전체**(태그 이름순) |
| `result.statPoints` | integer | 반영 뒤 남은 포인트 |
| `result.version` | integer | 계정 `version` |
| `saveStatus` | string | `SAVED`(이번 요청으로 반영) · `ALREADY_SAVED`(이미 반영된 요청). 게임은 둘 다 "해금됨"으로 봅니다 |
| `account` | object | 지금 계정 스냅샷([account-api.md](account-api.md#계정-스냅샷)). 게임은 `version`이 지금 값보다 크면 적용합니다 |

예시: `examples/skill-unlock-response.json`

### 조건 미충족 응답

409 `SKILL_REQUIREMENTS_NOT_MET` 오류 본문에 기능별 추가 칸 `requirements`가 붙습니다([README 오류 응답](README.md#오류-응답) "기능별 추가 칸").

| 필드 | 타입 | 설명 | UE `FWarriorSkillRequirementProgress` |
|---|---|---|---|
| `requirements[].type` | string | [조건 종류](#조건-종류) | — (`Text`는 게임이 만듦) |
| `requirements[].key` | string \| null | `PREREQUISITE`면 선행 스킬 태그, 나머지는 `null` | — |
| `requirements[].target` | number | 목표 값 | `Target` |
| `requirements[].current` | number \| null | 지금 값. 기록이 없으면 `null`(클리어 기록 없는 `BEST_CLEAR_TIME` 등) | `Current`, `bHasValue = (current != null)` |
| `requirements[].met` | boolean | 충족 여부 | `bMet` |
| `requirements[].upperBound` | boolean | `true`면 "이하"(`BEST_CLEAR_TIME`) | `bUpperBound` |

- 그 스킬의 **조건 전부**를 [스킬](#스킬) 표 순서(선행 → 비용 → 나머지)로 보냅니다. 충족한 조건도 `met: true`로 들어갑니다.
- 시간은 초(소수 셋째 자리까지)입니다.

예시: `examples/skill-error-requirements-not-met.json`, `skill-error-already-unlocked.json`, `skill-error-unknown.json`

## K2. 스킬 진행도 — `GET /accounts/me/skills`

스킬 화면을 열 때(그리고 해금·결과 뒤 다시 그릴 때) 부릅니다. 상태를 바꾸지 않습니다.

응답 `data`

| 필드 | 타입 | 설명 | UE `FWarriorSkillView` |
|---|---|---|---|
| `skills[]` | array | [스킬](#스킬) 표의 스킬 전부, 표 순서 | — |
| `skills[].skillTag` | string | 스킬 태그 | `Definition.SkillTag` |
| `skills[].state` | string | `LOCKED`(조건 또는 선행 미충족) · `NEED_POINTS`(조건·선행은 충족, 포인트 부족) · `UNLOCKABLE`(해금 가능) · `UNLOCKED`(해금함) | `State` |
| `skills[].cost` | integer | 비용(스탯 포인트) | `Definition.StatPointCost` |
| `skills[].requirements` | array | K1 [조건 미충족 응답](#조건-미충족-응답)과 같은 모양. `UNLOCKED`도 보냄(표시용. 누적 기록은 해금해도 줄지 않음) | `Requirements` |
| `statPoints` | integer | 지금 남은 포인트 | — |
| `version` | integer | 계정 `version` | — |

- 이름·설명·아이콘은 보내지 않습니다. 게임 `DA_SkillTree`에서 읽습니다.
- `UE MissingPrerequisites`는 `requirements` 중 `type: PREREQUISITE`, `met: false`인 줄의 `key`입니다.

예시: `examples/skill-list-response.json`

## 한 번만 반영

공통 규칙은 [README 재전송](README.md#상태를-바꾸는-요청과-재전송)과 같습니다. 해금만의 경우:

| 경우 | 서버 응답 |
|---|---|
| 같은 `requestId` + 같은 본문, 처음 요청이 성공함 | 처음 응답 그대로(24시간 동안, 서버 설정 `pw01.idempotency.ttl`) |
| 기억 시간이 지난 뒤 같은 `requestId` | 이 요청으로 이미 해금한 것을 알아채 200 + `saveStatus: ALREADY_SAVED` + 지금 값 |
| **새** `requestId`로 이미 해금한 스킬 | 409 `SKILL_ALREADY_UNLOCKED`(로그인 값이 오래됐을 수 있으니 계정 값을 다시 받음) |
| 같은 스킬을 다른 `requestId`로 동시에 둘 | 하나만 200, 나머지 409 `SKILL_ALREADY_UNLOCKED` |

- 게임 규칙: **새 해금 버튼에는 새 `requestId`, 다시 보낼 때는 같은 `requestId`와 같은 본문.**

## 오류

이 명세만의 오류 코드입니다. 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `SKILL_UNKNOWN` | 400 | 없는 스킬 태그(`errors`에 `skillTag`) | false | "알 수 없는 스킬입니다"(게임 버그) |
| `SKILL_ALREADY_UNLOCKED` | 409 | 다른 요청으로 이미 해금한 스킬 | false | "이미 해금한 스킬입니다", 계정 값 다시 받기 |
| `SKILL_REQUIREMENTS_NOT_MET` | 409 | 선행·포인트·누적 기록 중 하나라도 미충족(`requirements`에 조건 전부) | false | "해금 조건을 채우지 못했습니다", `requirements`로 그 스킬 진행도 다시 그림 |

- 거절(`retryable: false`)은 같은 본문으로 다시 보내도 같은 결과입니다. 다시 보내지 않습니다.

## 정할 것

| 무엇 | 지금 | 누가 |
|---|---|---|
| 판정하지 않는 조건(사망 방식별·적 종류별 처치, 데미지, 추가 통계) | 서버에 재료 없음. 쓰려면 결과 요청 칸부터 | Robbie |
| 스킬 값 원본을 서버로 옮기기 | 서버 파일과 UE `DA_SkillTree`를 손으로 맞춤 | Robbie·Sang-Hyun-Kim |
| 스킬 초기화(포인트 돌려받기) | 없음 | — |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-12 | 초안: K1 해금, K2 진행도, 스킬 3개(시연용 목표 값), 조건 종류 8개(판정하지 않는 종류 명시), 조건 미충족 응답 `requirements`, 한 번만 반영, 오류 세 개 |
