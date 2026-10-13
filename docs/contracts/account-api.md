# 계정 API (Account API)

> 버전: v1.3 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Juunnmmoo · 웹서버 담당: Robbie (리뷰: Sang-Hyun-Kim)

계정의 메인화면 값(계정 스냅샷)입니다. 로그인 응답의 `data.account`도 같은 모양입니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증)
- 경우별 흐름도: [flows/account-snapshot.md](../flows/account-snapshot.md)

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| A3 | GET | `/accounts/me` | 필요 | 200 | 내 메인화면 값 |

## 계정 스냅샷

계정 값의 **원본은 서버 DB**(진행 행·투자 스탯·해금 스킬 표)이고, 계정 스냅샷은 서버가 응답할 때마다 원본을 읽어 **한 곳에서 만드는 묶음**입니다(따로 저장하지 않음). 게임은 받은 스냅샷을 **사본**으로 들고 화면과 판 시작 값에 씁니다. 해금·투자·보상을 정하는 판정은 서버가 원본으로 합니다.

칸 이름은 UE `FWarriorAccountData`에 맞춥니다.

| 필드 | 타입 | 설명 | 예 | UE `FWarriorAccountData` |
|---|---|---|---|---|
| `accountId` | string | 계정 ID(숫자를 문자열로) | `"7"` | — (따로 보관) |
| `version` | integer | 계정 진행이 바뀔 때마다 서버가 1 올리는 번호([버전 규칙](#버전-규칙)) | `4` | — (`UWarriorAuthSubsystem`이 마지막 적용 값을 보관) |
| `accountLevel` | integer | 계정 레벨. 1부터 | `3` | `AccountLevel` |
| `experience` | integer | 지금 레벨 안의 경험치 | `120` | `Experience` |
| `statPoints` | integer | 남은 스탯 포인트 | `2` | `StatPoints` |
| `investedStats` | object | 스탯 태그 이름 → 투자 포인트. **투자한 스탯만**(0인 스탯은 빠짐). 투자는 [stat-api.md](stat-api.md) | `{"Account.Stat.MaxHealth": 1}` | `InvestedStats` |
| `unlockedSkills` | string[] | 해금한 스킬 태그 이름(태그 이름순). 해금은 [skill-api.md](skill-api.md) | `["Account.Skill.Combo4"]` | `UnlockedSkills` |

- 누적 경험치는 서버 계산용이라 보내지 않습니다.
- UE의 `SchemaVersion`은 UE 구조체 버전이라 `version`과 다릅니다. 서버가 보내지 않는 UE 칸(`ExternalCurrencies`, `RewardedRecordIds`)은 덮어쓰지 않도록 받는 쪽에서 지금 값을 유지합니다.

### 싣는 응답

아래 다섯 응답이 같은 스냅샷을 싣습니다. 모두 서버의 같은 조립에서 나오므로 같은 계정·같은 상태면 값이 같습니다.

| 응답 | 칸 | 명세 |
|---|---|---|
| 로그인 | `data.account` | [auth-api.md](auth-api.md) |
| A3 메인화면 값 | `data` | 이 문서 |
| R1 결과 제출(`SAVED`·`ALREADY_SAVED` 모두) | `data.account` | [result-api.md](result-api.md) |
| T1 스탯 투자(`SAVED`·`ALREADY_SAVED` 모두) | `data.account` | [stat-api.md](stat-api.md) |
| K1 스킬 해금(`SAVED`·`ALREADY_SAVED` 모두) | `data.account` | [skill-api.md](skill-api.md) |

### 버전 규칙

| 쪽 | 규칙 |
|---|---|
| 서버 | 계정 진행(레벨·경험치·포인트·투자·해금)이 바뀌는 저장마다 `version`을 1 올립니다. 같은 계정에 저장이 동시에 오면 이 번호로 하나씩 줄을 세우고(먼저 저장한 쪽이 이기고 나머지는 다시 읽어 다시 저장), 넘치면 409 `VERSION_CONFLICT`입니다 |
| 게임 | 받은 `version`이 마지막으로 적용한 값보다 **작으면 버리고**, **같거나 크면 적용**합니다. 로그아웃하면 기준을 0으로 되돌립니다 |

- 늦게 도착한 옛 응답을 버려도 잃는 값이 없습니다. 더 큰 `version`의 스냅샷은 그 이전 변경을 모두 담고 있습니다.

### 받는 쪽 규칙

- 결과 제출과 보관 결과 재전송의 응답은 **요청을 보낸 뒤 로그아웃하거나 다시 로그인했으면** 적용하지 않습니다. 보낼 때와 같은 로그인 세션이고, `accountId`가 보낸 계정과 같을 때만 적용합니다. 응답에 `account`가 없으면 적용하지 않습니다.
- `investedStats`와 `unlockedSkills`는 **통째로 바꿉니다**(칸이 빠진 스탯은 0, 목록에 없는 스킬은 해금 안 됨).
- 화면은 스냅샷을 직접 받지 않고, 사본이 바뀌었다는 알림을 받아 다시 그립니다. 판 안 캐릭터(스탯 보너스·해금 스킬 효과)는 스테이지에 들어올 때 사본을 한 번 읽습니다.

### 동기화 시점

게임의 사본이 서버 값으로 맞춰지는 때입니다. 서버는 저장할 때마다 바로 DB에 반영하므로, 서버 쪽에는 맞춰야 할 사본이 없습니다.

| # | 시점 | 서버 API | 받는 칸 | 게임에서 적용하는 곳 | 버리는 조건 |
|---|---|---|---|---|---|
| T1 | 로그인 직후 | `POST /auth/login` | `data.account` | `UWarriorAuthSubsystem` 로그인 성공 | — (첫 값) |
| T2 | 결과 확정 | R1 | `data.account` | `UWarriorStagePlaySubsystem` 결과 응답 처리 | 다른 세션·계정, 작은 `version` |
| T3 | 스탯 투자 직후 | T1(stat-api) | `data.account` | `UWarriorStatInvestSubsystem` | 작은 `version` |
| T4 | 스킬 해금 직후 | K1 | `data.account` | `UWarriorSkillUnlockSubsystem` | 작은 `version` |
| T5 | 로그인 뒤 보관 요청 재전송 성공 | 보관한 요청(지금은 R1) | `data.account` | `UWarriorApiSubsystem` 재전송 | 다른 세션·계정, 작은 `version` |
| T5b | 판 시작 전 보관 결과를 먼저 보냄([stage-play-api.md P1](stage-play-api.md) 409 처리) | R1(보관본 그대로) | `data.account` | `UWarriorStagePlaySubsystem` 보관 결과 재전송 | 다른 세션·계정, 작은 `version` |
| T6 | 메인메뉴 들어올 때 | 없음 | — | 마지막으로 적용한 사본을 그림 | — |

- 모든 적용은 `UWarriorAuthSubsystem::ApplyAccountSnapshot` 한 곳을 지나고, 적용 뒤 화면은 `UWarriorAccountSubsystem::OnAccountChanged`로 다시 그립니다.
- **예외 1**: 결과 저장이 실패해 결과를 보관한 동안(T2 없음) 메인메뉴는 게임이 먼저 계산한 보상 값입니다. 재전송이 성공하면(T5·T5b) 서버 값으로 바뀝니다.
- **예외 2**: 결과를 보낸 직후 같은 계정으로 다시 로그인하면 그 결과 응답은 버립니다. 로그인 응답이 결과 저장보다 먼저 만들어졌다면 다음 시점(투자·해금·다음 결과·재로그인)까지 옛 값입니다.
- A3는 지금 게임이 부르지 않습니다. 위 응답들이 새 값을 실어 오기 때문입니다. 연결 밖에서 계정 값이 바뀌는 기능이 생기면 실시간 알림 `ACCOUNT_CHANGED`([realtime-api.md](realtime-api.md)) 뒤 A3로 다시 받습니다.

### 넣지 않는 것

새 칸을 더할 때의 기준입니다. 더할 때는 서버 조립 한 곳, `AccountSnapshotResponse`, UE `FWarriorAccountSnapshotDto`, `ApplyAccountSnapshot` 네 곳만 고칩니다.

| 넣는다 | 넣지 않는다(따로 조회하거나 그 요청의 응답 칸) |
|---|---|
| 메인메뉴에 늘 보이는 작은 값 | 계속 늘어나는 목록(우편·업적·기록) |
| 계정 `version`과 같이 바뀌는 값(서버 판정) | 바뀌는 속도가 다른 값(그룹·순위·접속 상태). 순위는 [ranking-api.md](ranking-api.md) |
| 여러 화면이 같이 쓰는 값 | 한 화면에서만 쓰는 상세(스킬 진행도는 [skill-api.md K2](skill-api.md)) |
| 영구 계정 값 | 판 안 값(골드·인벤토리·판 강화·체력, [stage-play-api.md](stage-play-api.md) 이어하기), 한 번 일어난 사건(팝업은 그 요청의 응답 칸) |

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
| v1.1 | 2026-10-12 | `investedStats`를 스탯 투자(S3, stat-api.md)에서 채움(0인 스탯은 뺌), 스냅샷을 쓰는 응답 목록 |
| v1.2 | 2026-10-12 | `unlockedSkills`를 스킬 해금(S4, skill-api.md)에서 채움(태그 이름순, 통째로 교체) |
| v1.3 | 2026-10-13 | M25: 원본·사본 설명, 칸 표에 예, 싣는 응답 다섯, 버전 규칙(서버·게임), 받는 쪽 규칙(결과·재전송은 같은 세션·계정일 때만), 동기화 시점 표(결과 확정 T2·판 시작 전 보관 결과 T5b를 게임이 적용), 넣지 않는 것. 서버 동작·칸은 그대로 |
