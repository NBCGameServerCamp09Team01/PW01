# 길드 API (Guild API)

> 버전: v1.1 · 상태: 초안(G1~G9·G11·G12 구현: 웹서버 #31·#33·#37, 게임 #61·#62·#66 — 둘 다 `dev`에 병합됨(10/17)) · 호출: 게임 클라이언트(UE) → 웹서버 · 게임 담당: Sang-Hyun-Kim · 웹서버 담당: Sang-Hyun-Kim (리뷰: 채팅 담당)

길드를 찾고, 만들고, 가입을 신청하고, 길드장이 신청을 받거나 거절하고, 길드원이 나가거나 길드장이 길드를 해체합니다. 한 사람은 길드 하나에만 들 수 있습니다. 같은 요청이 두 번 와도 한 번만 반영하고, 여러 사람이 동시에 눌러도 정원·한 사람 한 길드·길드 수 상한을 지킵니다.

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 다시 보내기·한 번만 반영: [README.md 상태를 바꾸는 요청과 재전송](README.md#상태를-바꾸는-요청과-재전송). 길드만의 차이는 아래 [한 번만 반영](#한-번만-반영)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증). 아래 API는 모두 인증이 필요합니다
- 길드 실시간 알림(`GUILD_*`)·길드원 접속 바뀜(`PRESENCE_CHANGED`): [realtime-api.md](realtime-api.md#메시지-종류) v1.6
- 길드 채팅은 이 명세에 없습니다(채팅 명세). 길드는 채팅이 쓸 소속 정보만 줍니다
- 아래 "응답 `data`" 표는 성공 응답의 `data` 안쪽 모양입니다.

## 엔드포인트

| ID | 메서드 | 경로 | 누가 | 성공 | 설명 |
|---|---|---|---|---|---|
| G1 | GET | `/guilds?name=&cursor=&size=` | 로그인 | 200 | 길드 목록(최근 만든 순, 이름 앞부분 검색) |
| G2 | GET | `/guilds/{guildId}` | 로그인 | 200 | 길드 하나(가입 전 정보) |
| G3 | POST | `/guilds` | 미소속·조건 충족 | 201 | 길드 만들기(만든 사람이 길드장) |
| G4 | GET | `/accounts/me/guild` | 로그인 | 200 | 내 길드 화면 전체(소속, 길드원, 내 신청, 만들기 조건) |
| G5 | POST | `/accounts/me/guild-join-requests` | 미소속 | 201 | 가입 신청 |
| G6 | DELETE | `/accounts/me/guild-join-requests/{joinRequestId}` | 신청자 | 204 | 신청 취소 |
| G7 | GET | `/accounts/me/guild/join-requests` | 길드장 | 200 | 받은 신청 목록 |
| G8 | POST | `/accounts/me/guild/join-requests/{joinRequestId}/approve` | 길드장 | 200 | 신청 수락 |
| G9 | POST | `/accounts/me/guild/join-requests/{joinRequestId}/reject` | 길드장 | 200 | 신청 거절 |
| G10 | POST | `/accounts/me/guild/members/{accountId}/kick` | 길드장 | 200 | 내보내기 — **보류(Lv2)**. 구현 전에는 404 `NOT_FOUND`(없는 경로) |
| G11 | POST | `/accounts/me/guild/leave` | 길드원 | 200 | 탈퇴(길드장이 혼자면 해체) |
| G12 | POST | `/accounts/me/guild/disband` | 길드장 | 200 | 해체 |

- 공개 정보는 `/guilds…`, 내 소속·신청처럼 "나"에 관한 것은 `/accounts/me/guild…`·`/accounts/me/guild-join-requests…`입니다.
- 게임은 길드 화면을 열 때와 길드 실시간 알림을 받을 때 G4 하나로 화면 전체를 다시 그립니다. 다른 API의 응답은 "성공했다"는 확인으로 쓰고, 화면은 G4로 맞춥니다(G3 만들기만 응답이 G4 모양이라 바로 씀). 403·404·409가 와도 그사이 상태가 바뀐 것이므로 G4를 다시 받습니다.

## 규칙

| 무엇 | 값 | 비고 |
|---|---|---|
| 한 사람 길드 | 하나 | 길드원이면 다른 길드에 신청·만들기 불가 |
| 정원 | 30명(길드장 포함) | 만들 때 길드에 적힘(`maxMembers`). 서버 설정 `pw01.guild.max-members` |
| 서버 길드 수 상한 | 5개 | 서버 설정 `pw01.guild.max-guilds`. 해체하면 자리가 남 |
| 만들기 조건 | 스테이지 `stage.01.01` 클리어 | 서버 설정 `pw01.guild.create-required-stage` |
| 이름 | 한글(완성형)·영문·숫자 2~12자, 가운데 공백 가능(연속 공백·앞뒤 공백 불가) | **대소문자를 가립니다**(`Knight`와 `knight`는 다른 이름, 닉네임과 다름). 공백도 한 글자로 셉니다 |
| 이름 검색 | 앞부분 일치, 대소문자 가림 | `name=새벽`이면 `새벽기사단`이 나옴 |
| 대기 중 신청 | 한 사람 최대 3곳, 같은 길드에는 하나 | 서버 설정 `pw01.guild.max-pending-requests` |
| 신청 유효 기간 | 3일 | 지나면 목록에서 빠지고 수락할 수 없음. 같은 길드에 다시 신청 가능. 서버 설정 `pw01.guild.join-request-ttl` |
| 수락되면 | 그 사람의 다른 신청은 모두 지워짐 | 길드를 만들어도 같음 |
| 거절되면 | 바로 다시 신청 가능 | |
| 길드장 탈퇴 | 다른 길드원이 있으면 불가(409), 혼자면 해체 | 길드장 넘기기는 없음 |
| 해체 | 길드장만, 즉시 | 길드원은 모두 미소속, 받은 신청은 모두 지워짐, 이름은 다시 쓸 수 있음 |
| 재가입 대기 | 없음(Lv2 보류. 설정 값 자리만 있고 기본 꺼짐) | |

### 상태와 권한

| 동작 | 미소속(신청 없음·신청 중) | 길드원 | 길드장 |
|---|---|---|---|
| G1·G2 목록·상세, G4 내 길드 | ✓ | ✓ | ✓ |
| G3 만들기 | ✓(조건 충족 시, 내 신청은 모두 지워짐) | 409 `GUILD_ALREADY_JOINED` | 409 `GUILD_ALREADY_JOINED` |
| G5 신청 | ✓(3곳까지) | 409 `GUILD_ALREADY_JOINED` | 409 `GUILD_ALREADY_JOINED` |
| G6 신청 취소 | ✓(내 신청) | 204(지울 것 없음) | 204(지울 것 없음) |
| G7·G8·G9 받은 신청·수락·거절, G10 내보내기 | 403 `GUILD_NOT_MEMBER` | 403 `GUILD_NOT_LEADER` | ✓ |
| G11 탈퇴 | 403 `GUILD_NOT_MEMBER` | ✓ | 혼자면 해체, 아니면 409 `GUILD_LEADER_CANNOT_LEAVE` |
| G12 해체 | 403 `GUILD_NOT_MEMBER` | 403 `GUILD_NOT_LEADER` | ✓ |

## 공통 모양

### 길드 요약 `GuildSummary`

G1의 목록 항목, G2의 `guild`, G4의 `guild`(+ `myRole`)가 같은 필드를 씁니다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `guildId` | string | 길드 ID(숫자 문자열) |
| `name` | string | 길드 이름 |
| `leaderAccountId` | string | 길드장 계정 ID |
| `leaderNickname` | string | 길드장 닉네임 |
| `memberCount` | integer | 지금 길드원 수(길드장 포함) |
| `maxMembers` | integer | 정원 |
| `createdAt` | string(UTC) | 만든 시각 |

### 신청 `JoinRequest`

| 필드 | 타입 | 설명 |
|---|---|---|
| `joinRequestId` | string | 신청 ID(숫자 문자열) |
| `guildId` | string | 신청한 길드 |
| `guildName` | string | 신청한 길드 이름 |
| `accountId` | string | 신청한 사람 |
| `nickname` | string | 신청한 사람 닉네임 |
| `requestedAt` | string(UTC) | 신청 시각 |
| `expiresAt` | string(UTC) | 유효 기간 끝(신청 + 3일) |

## G1. 길드 목록 — `GET /guilds`

길드 찾기 탭을 열 때, 검색할 때, "더 보기"를 누를 때 부릅니다.

쿼리

| 이름 | 타입 | 기본 | 규칙 |
|---|---|---|---|
| `name` | string | 없음(전부). 빈 값(`name=`)도 전부 | 이름 앞부분. 한글(완성형)·영문·숫자·공백 1~12자, 첫 글자는 공백이 아님(입력 중인 앞부분이라 끝 공백·연속 공백은 받음). 아니면 400 `VALIDATION_FAILED`(`errors`에 `name`) |
| `cursor` | string | 없음(가장 최근부터) | 앞 응답의 `nextCursor` **그대로**. 모양에 기대지 않습니다. 잘못된 값은 400 `VALIDATION_FAILED`(`errors`에 `cursor`). `name`과 달리 빈 값(`cursor=`)도 400이므로, 처음 묶음은 `cursor`를 빼고 보냅니다 |
| `size` | integer | 20 | 1~50. 밖이면 400 `VALIDATION_FAILED`(`errors`에 `size`) |

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `guilds[]` | `GuildSummary`[] | 최근 만든 순 |
| `hasNext` | boolean | 다음 묶음이 있나 |
| `nextCursor` | string \| null | 다음 묶음 커서. `hasNext`가 `false`면 `null`(칸은 늘 있음) |

- 정원이 찬 길드도 목록에 나옵니다(`memberCount == maxMembers`). 게임은 신청 버튼을 끄고, 서버도 신청을 409 `GUILD_FULL`로 거절합니다.

예시: `examples/guild-list-response.json`

## G2. 길드 하나 — `GET /guilds/{guildId}`

| 상태 코드 | 의미 |
|---|---|
| 200 | `data.guild`는 `GuildSummary` |
| 400 | `guildId`가 숫자 문자열이 아님(`VALIDATION_FAILED`) |
| 404 | 없는 길드(해체됨 포함) `GUILD_NOT_FOUND` |

- 길드원 목록은 길드원에게만 보입니다(G4).

## G3. 길드 만들기 — `POST /guilds`

요청

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `requestId` | string(UUID) | 예 | 이 요청의 번호. **다시 보낼 때 같은 값** |
| `name` | string | 예 | [규칙](#규칙)의 이름 |

예시: `examples/guild-create-request.json`

### 판정 순서

| 순서 | 판정 | 걸리면 |
|---|---|---|
| 0 | 형식(필수·UUID·모르는 칸), 이름 규칙 | 400 `VALIDATION_FAILED`(`errors`에 `name`) · `INVALID_REQUEST_BODY` |
| 1 | 같은 `requestId`가 이미 처리됐나 | [README 재전송](README.md#상태를-바꾸는-요청과-재전송): 처음 응답 / 처리 중 / 다른 본문 |
| 2 | 만들기 조건(스테이지 클리어) | 409 `GUILD_CREATE_REQUIREMENTS_NOT_MET` + `requirements` |
| 3 | 이미 길드원·길드장 | 409 `GUILD_ALREADY_JOINED` |
| 4 | 같은 이름의 길드가 있음(대소문자 가림) | 409 `GUILD_NAME_DUPLICATED` |
| 5 | 서버 길드 수가 상한 | 409 `GUILD_LIMIT_REACHED` |
| 6 | 저장 | 길드 만들기, 나를 길드장으로, 내 대기 중 신청 모두 지움(한 트랜잭션) |

- 같은 이름을 동시에 둘이 만들면 하나만 201, 나머지는 409 `GUILD_NAME_DUPLICATED`. 상한 직전에 동시에 만들면 상한까지만 201, 나머지는 409 `GUILD_LIMIT_REACHED`.
- 다른 저장과 계속 부딪히면 409 `VERSION_CONFLICT`(`retryable: true`) — 아래 [동시에 눌렀을 때](#동시에-눌렀을-때).

응답: **201** + 헤더 `Location: /accounts/me/guild`, `data`는 [G4](#g4-내-길드--get-accountsmeguild)와 같은 모양(만든 뒤 내 길드). 게임은 이 응답으로 바로 화면을 그리고 G4를 따로 부르지 않습니다. 예시: `examples/guild-me-response.json`

### 조건 미충족 응답

409 `GUILD_CREATE_REQUIREMENTS_NOT_MET` 오류 본문에 기능별 추가 칸 `requirements`가 붙습니다([README 오류 응답](README.md#오류-응답) "기능별 추가 칸"). G4의 `create.requirements`와 같은 모양입니다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `requirements[].type` | string | 지금은 `STAGE_CLEARED` 하나 |
| `requirements[].stageId` | string | 클리어해야 하는 스테이지 |
| `requirements[].met` | boolean | 충족 여부 |

예시: `examples/guild-error-create-requirements-not-met.json`

## G4. 내 길드 — `GET /accounts/me/guild`

로그인 직후(채팅이 내 길드 ID를 쓰므로 팝업과 상관없이), 길드 팝업을 열 때, 길드 실시간 알림을 받았을 때(0.5초 모아 한 번), 실시간이 다시 연결됐을 때, 쓰기 요청이 끝났을 때 부릅니다. **늘 200**입니다(미소속도).

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `guild` | object \| null | 소속 길드. `GuildSummary` + `myRole`(`LEADER`·`MEMBER`). 미소속이면 `null` |
| `members[]` | array | 길드원. 길드장 먼저, 그다음 들어온 순. 미소속이면 `[]` |
| `members[].accountId` | string | 계정 ID |
| `members[].nickname` | string | 닉네임 |
| `members[].role` | string | `LEADER` · `MEMBER` |
| `members[].joinedAt` | string(UTC) | 들어온 시각 |
| `members[].online` | boolean | 지금 실시간 연결이 있나(서버 어느 대든). 이 응답 뒤에는 실시간 `PRESENCE_CHANGED`로 바뀜([realtime-api.md 접속 표시 처리](realtime-api.md#접속-표시-처리)). 서버가 갑자기 꺼지면 최대 150초까지 `true`로 남을 수 있음 |
| `pendingJoinRequestCount` | integer | 받은 대기 중 신청 수. 길드장이 아니면 0 |
| `myJoinRequests[]` | `JoinRequest`[] | 내 대기 중 신청(유효 기간 안, 오래된 순). 길드원이면 `[]` |
| `create.allowed` | boolean | 지금 길드를 만들 수 있나: 미소속이고 `requirements`가 모두 충족. 길드 수 상한은 넣지 않습니다(만들 때 판정) |
| `create.requirements[]` | array | [조건 미충족 응답](#조건-미충족-응답)과 같은 모양 |
| `rejoinAvailableAt` | string(UTC) \| null | 재가입 대기가 끝나는 시각. 지금은 늘 `null`(재가입 대기는 Lv2 보류) |

예시: `examples/guild-me-response.json`(길드장), `examples/guild-me-response-none.json`(미소속, 신청 하나)

## G5. 가입 신청 — `POST /accounts/me/guild-join-requests`

요청

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `requestId` | string(UUID) | 예 | 이 요청의 번호 |
| `guildId` | string | 예 | 신청할 길드(숫자 문자열) |

### 판정 순서

| 순서 | 판정 | 걸리면 |
|---|---|---|
| 0 | 형식 | 400 `VALIDATION_FAILED`(`errors`에 `guildId`) · `INVALID_REQUEST_BODY` |
| 1 | 같은 `requestId` | README 재전송 |
| 2 | 이미 길드원·길드장 | 409 `GUILD_ALREADY_JOINED` |
| 3 | 길드가 없음(해체됨 포함) | 404 `GUILD_NOT_FOUND` |
| 4 | 같은 길드에 대기 중 신청이 있음 | 409 `GUILD_JOIN_REQUEST_DUPLICATED`(유효 기간이 지난 신청은 지우고 새로 받음) |
| 5 | 대기 중 신청이 이미 3곳 | 409 `GUILD_JOIN_REQUEST_LIMIT` |
| 6 | 길드 정원이 참 | 409 `GUILD_FULL`(안내용. 진짜 판정은 수락 때) |
| 7 | 저장 | 신청 행 하나. 커밋 뒤 길드장에게 `GUILD_JOIN_REQUESTED` |

응답: **201** + 헤더 `Location: /accounts/me/guild-join-requests/{joinRequestId}`(G6 취소 경로), `data`는 `JoinRequest` 하나. 예시: `examples/guild-join-request-response.json`

## G6. 신청 취소 — `DELETE /accounts/me/guild-join-requests/{joinRequestId}`

- 내 신청이면 지우고 **204**. 내 것이 아니거나 이미 없으면(수락·거절·만료·해체) **역시 204**입니다(같은 결과라 다시 보내도 됨). 본문·`requestId` 없음.
- `joinRequestId`가 숫자 문자열이 아니면 400 `VALIDATION_FAILED`.

## G7. 받은 신청 — `GET /accounts/me/guild/join-requests`

- 길드장만. 미소속 403 `GUILD_NOT_MEMBER`, 길드원 403 `GUILD_NOT_LEADER`.
- 응답 `data.joinRequests[]`: `JoinRequest`, 유효 기간 안, 오래된 순. 예시: `examples/guild-join-requests-response.json`

## G8. 신청 수락 — `POST /accounts/me/guild/join-requests/{joinRequestId}/approve`

요청: `{ "requestId": "…" }`

| 순서 | 판정 | 걸리면 |
|---|---|---|
| 0 | 형식 | 400 |
| 1 | 같은 `requestId` | README 재전송 |
| 2 | 내가 길드장인가 | 403 `GUILD_NOT_MEMBER` · `GUILD_NOT_LEADER` |
| 3 | 정원 | 409 `GUILD_FULL` |
| 4 | 신청이 내 길드에 대기 중인가(유효 기간 안) | 404 `GUILD_JOIN_REQUEST_NOT_FOUND`(취소·만료·이미 처리) |
| 5 | 신청자가 그사이 다른 길드에 들어갔나 | 409 `GUILD_ALREADY_JOINED` |
| 6 | 저장 | 신청자를 길드원으로, 인원 +1, 신청자의 신청 모두 지움. 커밋 뒤 `GUILD_MEMBER_JOINED` |

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `member` | object | 새 길드원(G4 `members[]` 항목 하나와 같은 모양) |
| `memberCount` | integer | 반영 뒤 길드원 수 |

## G9. 신청 거절 — `POST /accounts/me/guild/join-requests/{joinRequestId}/reject`

요청: `{ "requestId": "…" }`. 403 둘 → 대기 중 신청이 없으면 404 `GUILD_JOIN_REQUEST_NOT_FOUND` → 지움. 커밋 뒤 신청자에게 `GUILD_JOIN_REJECTED`.

응답 `data`: `{ "joinRequestId": "…" }`

## G10. 내보내기 — `POST /accounts/me/guild/members/{accountId}/kick` (보류, Lv2)

요청: `{ "requestId": "…" }`. 403 둘 → 자기 자신이면 400 `VALIDATION_FAILED`(`errors`에 `accountId`) → 대상이 내 길드원이 아니면 404 `GUILD_MEMBER_NOT_FOUND` → 대상 미소속, 인원 −1. 커밋 뒤 `GUILD_MEMBER_LEFT`(`reason: KICKED`).

응답 `data`: `{ "accountId": "…", "memberCount": 2 }`

## G11. 탈퇴 — `POST /accounts/me/guild/leave`

요청: `{ "requestId": "…" }`

| 순서 | 판정 | 걸리면 |
|---|---|---|
| 0~1 | 형식, 같은 `requestId` | 400, README 재전송 |
| 2 | 길드가 있나 | 403 `GUILD_NOT_MEMBER` |
| 3 | 길드장이고 다른 길드원이 있음 | 409 `GUILD_LEADER_CANNOT_LEAVE` |
| 4 | 길드장이 혼자 | [G12 해체](#g12-해체--post-accountsmeguilddisband)와 같이 처리 |
| 5 | 저장 | 나를 미소속으로, 인원 −1. 커밋 뒤 `GUILD_MEMBER_LEFT`(`reason: LEFT`) |

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `guildId` | string | 나온 길드 |
| `disbanded` | boolean | 길드장이 혼자라 해체됐으면 `true` |

## G12. 해체 — `POST /accounts/me/guild/disband`

요청: `{ "requestId": "…" }`. 403 둘 → 길드원 모두 미소속, 받은 신청 모두 지움, 길드 지움, 서버 길드 수 −1(한 트랜잭션). 커밋 뒤 길드원과 신청자에게 `GUILD_DISBANDED`. 길드 채팅은 채팅 모듈이 해체를 받아 지웁니다.

응답 `data`: `{ "guildId": "…" }`

## 동시에 눌렀을 때

서버는 아래를 늘 지킵니다(여러 서버에서 동시에 와도 같은 DB에서 판정).

| 약속 | 예 | 결과 |
|---|---|---|
| 길드원 수 ≤ 정원 | 길드장이 두 기기에서 동시에 수락 | 정원까지만 200, 나머지 409 `GUILD_FULL` |
| 한 사람 길드 하나 | 두 길드가 한 사람을 동시에 수락 | 한쪽만 200, 다른 쪽 404 `GUILD_JOIN_REQUEST_NOT_FOUND` 또는 409 `GUILD_ALREADY_JOINED` |
| 해체된 길드에 사람이 들지 않음 | 수락과 해체가 동시 | 해체가 먼저면 수락은 403·404, 수락이 먼저면 새 길드원까지 해체 알림을 받음 |
| 이름 유일, 길드 수 ≤ 상한 | 동시 만들기 | G3 |
| 대기 중 신청 ≤ 3 | 한 사람이 넷을 동시에 | 셋까지 201, 나머지 409 `GUILD_JOIN_REQUEST_LIMIT` |

- 저장이 다른 요청과 부딪히면 서버가 먼저 몇 번(기본 3번) 다시 합니다. 그래도 안 되면 409 `VERSION_CONFLICT`(`retryable: true`)입니다. 게임은 공통 규칙대로 **같은 본문**으로 다시 보낼 수 있습니다.
- 서버 쪽 방법(낙관적 잠금 + 해체만 비관적 잠금 + DB 제약 + 잠금 순서)은 웹서버 `docs/decisions/0003-guild-concurrency.md`에 있습니다.

## 한 번만 반영

쓰기(G3·G5·G8·G9·G10·G11·G12)는 본문 `requestId`로 한 번만 반영합니다. G6 취소는 `DELETE`라 다시 보내도 결과가 같습니다.

| 경우 | 서버 응답 |
|---|---|
| 같은 `requestId` + 같은 본문, 처음 요청이 성공함 | 처음 응답 그대로(24시간 동안, 서버 설정 `pw01.idempotency.ttl`) |
| 처리 중 / 다른 본문 | 409 `REQUEST_IN_PROGRESS` / `IDEMPOTENCY_KEY_REUSED` |
| 기억 시간이 지난 뒤 같은 요청 | **지금 상태로 다시 판정**합니다(길드에는 `saveStatus`가 없음). 예: 만들기는 409 `GUILD_ALREADY_JOINED`, 수락은 404 `GUILD_JOIN_REQUEST_NOT_FOUND`. 두 번 반영되지는 않습니다 |

- 게임 규칙: 새로 누른 동작에는 새 `requestId`. **길드 요청은 디스크에 보관하지 않고**, 실패해도 "다시 시도 / 게임 종료"를 묻지 않습니다(팝업 안 문구로 알림). 공통 규칙의 자동 재시도(`retryable: true`)는 그대로 씁니다.

## 오류

이 명세만의 오류 코드입니다. 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다. 모두 `retryable: false`입니다. 게임에 보이는 문구와 보이는 곳(팝업·팝업 안 문구·이름 칸)의 기준은 UE `WarriorErrorText.cpp` d 구역(맥락 `Guild`)입니다. 아래 "게임 쪽 처리"는 그 요약입니다.

| 코드 | HTTP | 상황 | 게임 쪽 처리(제안) |
|---|---|---|---|
| `GUILD_NOT_FOUND` | 404 | 없는 길드(해체됨 포함) | "길드를 찾을 수 없습니다", 목록 다시 받기 |
| `GUILD_NOT_MEMBER` | 403 | 길드 없이 내 길드 기능 | G4 다시 받기 |
| `GUILD_NOT_LEADER` | 403 | 길드장 기능을 길드원이 | "길드장만 할 수 있습니다", G4 다시 받기 |
| `GUILD_ALREADY_JOINED` | 409 | 이미 길드가 있음 / 수락하는 순간 신청자가 다른 길드에 들어감 | "이미 길드에 가입했습니다", G4 다시 받기 |
| `GUILD_FULL` | 409 | 정원 | "길드 정원이 찼습니다" |
| `GUILD_NAME_DUPLICATED` | 409 | 같은 이름(대소문자 가림) | 이름 칸에 문구 |
| `GUILD_LIMIT_REACHED` | 409 | 서버 길드 수 상한 | "더 이상 길드를 만들 수 없습니다" |
| `GUILD_CREATE_REQUIREMENTS_NOT_MET` | 409 | 만들기 조건 미충족(`requirements`) | 조건 안내 |
| `GUILD_JOIN_REQUEST_DUPLICATED` | 409 | 같은 길드에 대기 중 | "이미 신청한 길드입니다" |
| `GUILD_JOIN_REQUEST_LIMIT` | 409 | 대기 중 3곳 | "신청은 3곳까지 할 수 있습니다" |
| `GUILD_JOIN_REQUEST_NOT_FOUND` | 404 | 수락·거절할 신청이 없음(취소·만료·처리됨) | 받은 신청 다시 받기 |
| `GUILD_MEMBER_NOT_FOUND` | 404 | 내보낼 사람이 내 길드원이 아님(Lv2) | G4 다시 받기 |
| `GUILD_LEADER_CANNOT_LEAVE` | 409 | 길드원이 있는 길드장의 탈퇴 | "길드원이 있으면 길드장은 탈퇴할 수 없습니다(해체만 가능)" |

예시: `examples/guild-error-full.json`

## 다른 기능이 길드를 쓸 때

길드 채팅·친구처럼 "누가 어느 길드인가"가 필요한 기능은 아래만 씁니다. 길드 표·잠금을 직접 다루지 않습니다.

| 어디 | 쓰는 것 | 주의 |
|---|---|---|
| 웹서버 | `common/chat/GuildDirectory`: `guildIdOf(계정)`·`isMember(길드, 계정)`·`memberIds(길드)` | 매번 MySQL에서 읽음(캐시 없음, [redis-keys.md 길드](redis-keys.md#길드v17)). 길드 ID는 숫자 문자열 |
| 웹서버 | 길드 생애 이벤트 `GuildMemberJoinedEvent`·`GuildMemberLeftEvent`(`reason` `LEFT`·`KICKED`)·`GuildDisbandedEvent`(해체 직전 길드원 목록 포함) | 길드 트랜잭션 안에서 냄. 받는 쪽은 `@TransactionalEventListener(AFTER_COMMIT)`(되돌려진 일은 받지 않음). 받는 쪽이 DB에 쓰려면 `@Transactional(propagation = REQUIRES_NEW)`(원래 트랜잭션은 이미 끝남). 해체는 길드원마다가 아니라 이벤트 하나. 지금 받는 쪽은 채팅 `ChatDisbandListener`(해체 → 그 길드 채팅 지움) 하나이고, 가입·탈퇴 이벤트는 받는 쪽이 없습니다(자리만) |
| 웹서버 | 접속: `PresenceService.onlineOf(계정들)`, 바뀜 이벤트 `PresenceChangedEvent(계정, online)` | 이벤트는 연결 처리 스레드에서 바로 옴(트랜잭션 없음). 받는 쪽은 예외를 던지지 않음 |
| 웹서버 | 게임에 알리기: `RealtimeNotifier.sendToGuild(길드 ID, 받는 사람, 메시지)` | 다른 서버에 붙은 사람에게도 감([realtime-relay](../flows/realtime-relay.md)). 메시지 종류는 realtime-api 표에 먼저 |
| 게임 | `UWarriorGuildSubsystem`: `GetMyGuildId()`·`HasLoadedMyGuild()`·`OnMyGuildChanged(이전, 새)`(길드 ID가 바뀔 때만)·`OnMyGuildUpdated`(화면 값이 바뀔 때마다) | 로그인 직후 G4 응답 전에는 `HasLoadedMyGuild()`가 false(그동안 "길드 없음"으로 보임). 실시간 메시지는 `UWarriorRealtimeSubsystem::OnMessage`로 따로 받음 |

- 서버 안 구조(표·제약·잠금 순서·동시성 결정)는 웹서버 저장소 `docs/erd/guild.md`, `docs/decisions/0003-guild-concurrency.md`. 경우별 흐름은 [flows/guild.md](../flows/guild.md).

## 정할 것

| 무엇 | 지금 | 누가 |
|---|---|---|
| 길드장 넘기기 | 없음 | — |
| 초대(길드장 → 사람) | 없음. 신청 표에 종류 칸을 두어 자리만 마련 | Sang-Hyun-Kim |
| 내보내기(G10)·재가입 대기 | 보류(Lv2, 10/16 Sang 결정: 이번 M23에서는 하지 않음). 재가입 대기 설정 `pw01.guild.rejoin-cooldown=0s`와 `rejoinAvailableAt`(늘 `null`) 자리만 있음 | Sang-Hyun-Kim |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-16 | 초안: G1~G12(G10 내보내기는 Lv2 예정), 규칙(한 사람 하나·정원 30·상한 5·스테이지 1 클리어·이름 2~12자 대소문자 가림·신청 3곳 3일), 상태·권한 표, 판정 순서, 동시에 눌렀을 때, 한 번만 반영(기억이 지나면 지금 상태로 판정), 오류 열셋 |
| v1.1 | 2026-10-16 | 구현 반영: 길드원 접속 바뀜 `PRESENCE_CHANGED`(realtime-api v1.6)가 Lv2로 들어가 G4 `members[].online` 설명과 "정할 것"에서 뺌. G10 내보내기·재가입 대기는 "예정(10/17)" → 보류. 상태 줄에 구현 PR. 구현과 대조해 빠진 설명 보탬: G1 `name` 규칙(첫 글자만 공백 불가, 빈 값은 전부), G3 `Location` 헤더와 응답으로 바로 그림, G4를 부르는 때(로그인 직후·다시 연결), 403·404·409 뒤 G4, 오류 문구의 기준(UE `WarriorErrorText`), 새 절 "다른 기능이 길드를 쓸 때". 10/17 채팅 병합(웹서버 #34) 뒤 다시 대조: G5 `Location` 헤더, G1 빈 `cursor=`는 400, 생애 이벤트를 지금 받는 쪽(채팅은 해체만). API 모양은 그대로 |
