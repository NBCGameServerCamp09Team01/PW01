# 길드 흐름 (M23)

> 상태: 초안 · 명세: [guild-api.md](../contracts/guild-api.md) v1.1, [realtime-api.md 메시지 종류·길드 알림 처리·접속 표시 처리](../contracts/realtime-api.md#메시지-종류) v1.6 · Redis: [redis-keys.md 접속 상태·길드](../contracts/redis-keys.md#접속-상태v17) v1.8 · 서버 사이 전달: [realtime-relay.md](realtime-relay.md)
> 클래스·함수 이름은 구현 기준입니다(웹서버 #31·#33, 게임 #61·#62 — 10/17 `dev` 병합(웹서버 #37, 게임 #66). 10/16 대조·10/17 채팅 병합 뒤 다시 대조). 코드 이름이 바뀌면 이 문서를 같이 고칩니다.

- ① 만들기 · ② 신청 → 길드장 알림 · ③ 수락(신청자가 다른 서버) · ④ 거절 · ⑤ 탈퇴 · ⑥ 해체 · ⑦ 같은 길드에 수락 둘이 동시에(정원) · ⑧ 접속 표시

## 참여자

| 이름 | 저장소·위치 | 하는 일 |
|---|---|---|
| `UWarriorGuildSubsystem` | 게임 `Network/` | 길드 API 부르기, `GUILD_*`를 받아 0.5초 모아 `GET /accounts/me/guild`, `PRESENCE_CHANGED`는 길드원 목록을 바로 고침, `GetMyGuildId()`·`OnMyGuildChanged`(채팅이 씀) |
| `UWarriorRealtimeSubsystem` | 게임 `Network/` | 서버 메시지를 `OnMessage(type, id, data)`로 넘김 |
| `GuildController` · `MyGuildController` · `MyGuildJoinRequestController` | 웹서버 `guild/controller` | `/guilds…`(목록·상세·만들기) · `/accounts/me/guild…`(내 길드·받은 신청·수락·거절·탈퇴·해체) · `/accounts/me/guild-join-requests…`(내 신청·취소) |
| `GuildQueryService` | 웹서버 `guild/service` | 조회 조립(닉네임·접속·만들기 조건) |
| `GuildCommandService` | 웹서버 `guild/service` | 쓰기: `IdempotencyService.run` → (만들기만 스테이지 클리어 확인) → `ProgressWriter.run`(새 트랜잭션, 부딪히면 다시) → 트랜잭션 몸통. 유일·외래 키 위반을 409·404로 바꿈 |
| `GuildMembershipTx` | 웹서버 `guild/service` | 트랜잭션 몸통(`create`·`apply`·`approve`·`reject`·`leave`·`disband`). 잠금 순서(길드 수 행 → 길드 행 → 사람 행 → 신청 행)를 한곳에서 지키고, 길드원을 넣는 길은 `approve` 하나 |
| `AccountGuildReader` | 웹서버 `guild/service` | 사람 행 읽기(없으면 그 자리에서 무소속 행을 만듦) |
| `GuildNotifier` | 웹서버 `guild/service` | 커밋 뒤(AFTER_COMMIT) `RealtimeNotifier.sendToGuild` |
| `PresenceService` | 웹서버 `presence` | 연결 이벤트 → `pw01:presence:<계정>`, 읽기 `MGET`. 키가 바뀌면 `PresenceChangedEvent` |
| `GuildPresenceNotifier` | 웹서버 `guild/service` | `PresenceChangedEvent` → 본인을 뺀 길드원에게 `PRESENCE_CHANGED` |
| MySQL | `guild` · `account_guild` · `guild_join_request` · `guild_counter` | 원본 |
| Redis | `pw01:idem:…`, `pw01:presence:…`, 채널 `pw01:realtime-relay:guild:<길드 ID>` | 한 번만 반영, 접속 표시, 서버 사이 전달 |

## ① 만들기

```mermaid
sequenceDiagram
  autonumber
  participant G as 게임(만드는 사람)
  participant C as GuildController
  participant S as GuildCommandService
  participant I as IdempotencyService
  participant W as ProgressWriter
  participant T as GuildMembershipTx
  participant DB as MySQL

  G->>C: POST /guilds {requestId, name}
  C->>C: 이름 규칙(2~12자) — 아니면 400
  C->>S: create(계정, 요청)
  S->>I: run(계정, requestId, 본문)
  I->>S: (처음 요청이면) 몸통 실행
  S->>DB: 스테이지 1 클리어?(StageProgressService.hasCleared) — 아니면 409 GUILD_CREATE_REQUIREMENTS_NOT_MET
  S->>W: run("guild-create requestId=…", 몸통)
  W->>T: 새 트랜잭션에서 create
  T->>DB: 내 사람 행(없으면 만듦) — 이미 길드면 409 GUILD_ALREADY_JOINED
  T->>DB: 같은 이름? (있으면 409 GUILD_NAME_DUPLICATED)
  T->>DB: 길드 수 행 — 상한이면 409 GUILD_LIMIT_REACHED, 아니면 +1·version 올림(flush)
  T->>DB: INSERT guild(인원 1) — 유일 위반이면 409 이름 겹침(다시 하지 않음)
  T->>DB: 내 사람 행 = LEADER
  T->>DB: 내 신청 모두 지움
  W-->>S: 커밋
  S->>DB: 내 길드 읽기(GuildQueryService.myGuild)
  S-->>I: 내 길드(G4 모양) — 처음 응답으로 기억
  I-->>C: 201 + Location: /accounts/me/guild
  C-->>G: 201
```

- 같은 이름 둘이 동시에 오면 하나는 유일 제약에 걸려 409. 길드 수 행 version이 부딪히면 `ProgressWriter`가 새 트랜잭션으로 다시 하고, 다시 해도 안 되면 409 `VERSION_CONFLICT`(`retryable: true`).

## ② 신청 → 길드장에게 알림

```mermaid
sequenceDiagram
  autonumber
  participant GA as 게임(신청자)
  participant S as GuildCommandService
  participant T as GuildMembershipTx
  participant DB as MySQL
  participant Nf as GuildNotifier
  participant N as RealtimeNotifier
  participant GL as 게임(길드장)

  GA->>S: POST /accounts/me/guild-join-requests {requestId, guildId}
  S->>T: (중복 방지 → 새 트랜잭션)
  T->>DB: 내 사람 행 FOR UPDATE + version 올림(같은 사람의 동시 신청을 하나씩 처리)
  T->>DB: 이미 길드? 길드 있나? 같은 길드 대기 중? 3곳? 정원? (각각 409·404)
  T->>DB: INSERT guild_join_request — 그사이 해체됐으면 외래 키 위반 → 404
  T-->>S: 커밋
  S-->>GA: 201 {joinRequestId, expiresAt …}
  T-)Nf: GuildRealtimeNotice(GUILD_JOIN_REQUESTED, [길드장]) — 커밋 뒤(AFTER_COMMIT)에 받음
  Nf->>N: sendToGuild(길드, [길드장], GUILD_JOIN_REQUESTED)
  N-->>GL: GUILD_JOIN_REQUESTED
  GL->>GL: 0.5초 모아 GET /accounts/me/guild → 받은 신청 수 표시
```

## ③ 수락 — 신청자가 다른 서버에 붙어 있을 때

```mermaid
sequenceDiagram
  autonumber
  participant GL as 게임(길드장, A에 붙음)
  participant A as 웹서버 A
  participant DB as MySQL
  participant R as Redis 채널 guild:7
  participant B as 웹서버 B
  participant GN as 게임(신청자, B에 붙음)

  GL->>A: POST /accounts/me/guild/join-requests/105/approve {requestId}
  A->>DB: 새 트랜잭션: 길드장인가(아니면 403)
  A->>DB: 길드 행 인원 +1 → 먼저 flush(version 올림, 배타 잠금) — 정원이면 409 GUILD_FULL
  A->>DB: 신청 105가 이 길드 것·만료 전? (아니면 404)
  A->>DB: 신청자 사람 행: 이미 길드면 409, 아니면 MEMBER(version 올림)
  A->>DB: 신청자의 신청 모두 지움 → 커밋
  A-->>GL: 200 {member, memberCount}
  A->>A: (트랜잭션 안에서 낸) GuildMemberJoinedEvent — 지금 받는 쪽 없음(채팅은 해체만 받음)
  A->>R: (커밋 뒤 GuildNotifier) sendToGuild(7, 새 사람 포함 길드원 전부, GUILD_MEMBER_JOINED)
  A-->>GL: (A 연결에 바로) GUILD_MEMBER_JOINED
  R-->>B: 길드 채널로 넘어옴
  B-->>GN: GUILD_MEMBER_JOINED
  GN->>B: (0.5초 뒤) GET /accounts/me/guild → 소속이 생겨 길드원 화면으로
```

- 길드 행을 먼저 flush하는 이유: 사람 행의 `guild_id`를 바꾸면 MySQL이 외래 키 검사로 길드 행에 공유 잠금을 겁니다. 두 수락이 공유 잠금을 쥔 채 길드 행을 고치려 하면 서로 기다립니다(교착). 길드 행의 배타 잠금을 먼저 잡으면 둘째 수락은 처음부터 기다립니다.

## ④ 거절

```mermaid
sequenceDiagram
  autonumber
  participant GL as 게임(길드장)
  participant S as GuildCommandService
  participant DB as MySQL
  participant N as RealtimeNotifier
  participant GA as 게임(신청자)

  GL->>S: POST …/join-requests/105/reject {requestId}
  S->>DB: 길드장인가 → 신청 105가 이 길드 것? (아니면 404) → 지움 → 커밋
  S-->>GL: 200 {joinRequestId}
  S->>N: (커밋 뒤) sendToGuild(길드, [신청자], GUILD_JOIN_REJECTED)
  N-->>GA: GUILD_JOIN_REJECTED → 0.5초 모아 G4, 내 신청 목록에서 빠짐(안내 문구는 후속). 바로 다시 신청 가능
```

## ⑤ 탈퇴

```mermaid
sequenceDiagram
  autonumber
  participant GM as 게임(길드원)
  participant S as GuildCommandService
  participant DB as MySQL
  participant N as RealtimeNotifier
  participant GO as 게임(남은 길드원)

  GM->>S: POST /accounts/me/guild/leave {requestId}
  S->>DB: 내 사람 행: 길드 없으면 403
  alt 길드장이고 다른 길드원 있음
    S-->>GM: 409 GUILD_LEADER_CANNOT_LEAVE
  else 길드장 혼자
    S->>S: ⑥ 해체와 같은 길 → 200 {guildId, disbanded: true}
  else 길드원
    S->>DB: 길드 행 인원 −1(먼저 flush) → 내 사람 행 무소속 → 커밋
    S-->>GM: 200 {guildId, disbanded: false}
    S->>N: (커밋 뒤) GUILD_MEMBER_LEFT(reason LEFT) → 남은 길드원 + 나
    N-->>GO: 0.5초 모아 G4(길드원 목록 다시 받기)
    N-->>GM: 내가 나감 → G4로 미소속 화면
  end
```

## ⑥ 해체

```mermaid
sequenceDiagram
  autonumber
  participant GL as 게임(길드장)
  participant T as GuildMembershipTx
  participant DB as MySQL
  participant Ch as 채팅 ChatDisbandListener
  participant N as RealtimeNotifier

  GL->>T: POST /accounts/me/guild/disband {requestId} (중복 방지 → 새 트랜잭션)
  T->>DB: 내 사람 행 — 길드 없으면 403 GUILD_NOT_MEMBER, 길드원이면 403 GUILD_NOT_LEADER
  T->>DB: 길드 행 SELECT … FOR UPDATE(길드 행 중 맨 먼저) — 최신 값으로 길드장 다시 확인
  T->>DB: 길드원 ID·신청자 ID를 잠금 읽기(FOR UPDATE, 알림 대상 — 방금 수락된 사람도 보임)
  T->>DB: 벌크: 길드원 모두 무소속(version 올림)
  T->>DB: 벌크: 받은 신청 모두 지움
  T->>DB: 길드 행 지움 → 길드 수 행 −1
  T->>T: GuildDisbandedEvent(guildId, 해체 직전 길드원) 발행 → 커밋
  T-->>GL: 200 {guildId}
  T-)Ch: (커밋 뒤) 해체 이벤트 → 새 트랜잭션에서 그 길드의 guild_chat_message 행 지움(채팅 몫, V11)
  T->>N: (커밋 뒤) GUILD_DISBANDED → 길드원 + 신청자
```

- 해체만 비관적 잠금을 씁니다. 지우는 동안 같은 길드의 수락은 길드 행에서 기다렸다가, 해체가 끝나면 다시 해 보고 길드가 없어 403·404로 끝납니다.

## ⑦ 같은 길드에 수락 둘이 동시에(정원 1자리 남음)

```mermaid
sequenceDiagram
  autonumber
  participant T1 as 수락 1(신청자 X)
  participant T2 as 수락 2(신청자 Y)
  participant DB as MySQL(길드 7: 29/30, version 5)
  participant W as ProgressWriter

  T1->>DB: 길드 7 읽기 29명(version 5)
  T2->>DB: 길드 7 읽기 29명(version 5)
  T1->>DB: UPDATE guild SET member_count=30, version=6 WHERE version=5 → 1행
  T2->>DB: 같은 UPDATE → T1 커밋까지 기다림
  T1->>DB: X 사람 행 MEMBER, 신청 지움 → 커밋
  DB-->>T2: 0행(version이 6) → 낙관적 락 실패
  T2->>W: 실패 → 새 트랜잭션으로 다시
  W->>DB: 길드 7 읽기 30명 → 정원
  W-->>T2: 409 GUILD_FULL
```

- 길드원 수는 정원을 넘지 않고 `member_count` = 실제 길드원 수가 지켜집니다. DB CHECK(`member_count ≤ max_members`)가 마지막 방어입니다.

## ⑧ 접속 표시

```mermaid
sequenceDiagram
  autonumber
  participant G as 게임
  participant B as 웹서버 B(연결)
  participant P as B: PresenceService
  participant R as Redis
  participant A as 웹서버 A(조회)
  participant GO as 게임(다른 길드원)

  G->>B: WebSocket 연결(인증 통과)
  B->>P: 연결 이벤트(RealtimeConnectedEvent)
  P->>R: SET pw01:presence:57 "B" EX 150 GET
  R-->>P: nil(전에 없었음) → 접속함으로 바뀜
  P-)B: PresenceChangedEvent(57, true) → GuildPresenceNotifier
  B->>B: 57의 길드·길드원 읽기(본인 제외)
  B-->>GO: PRESENCE_CHANGED {guildId, accountId: "57", online: true}(다른 서버면 길드 채널로 넘어감)
  GO->>GO: 길드원 목록의 57 접속 표시를 바로 고침(G4 안 받음)
  loop Pong마다(60초)
    P->>R: SET pw01:presence:57 "B" EX 150 GET
    R-->>P: "B"(있었음) → 보내지 않음
  end
  GO->>A: GET /accounts/me/guild(팝업을 열 때 등)
  A->>R: MGET pw01:presence:12 … :57
  R-->>A: [ "A", …, "B" ]
  A-->>GO: members[].online = true
  G--xB: 연결 끊김
  B->>P: 끊김 이벤트 → B에 57의 다른 연결 없음
  P->>R: presence_release.lua(값이 "B"일 때만 DEL)
  R-->>P: 1(지움) → 끊김으로 바뀜
  P-)B: PresenceChangedEvent(57, false) → GuildPresenceNotifier
  B-->>GO: PRESENCE_CHANGED {…, online: false}
```

- 게임이 다른 서버(C)로 다시 붙으면 C의 `SET … GET`은 "B"를 돌려받아(있었음) 알리지 않습니다. 그 뒤 B의 끊김 처리가 늦게 와도 값이 이미 "C"라 지우지 않고(0) 알리지도 않습니다.
- 서버 B가 갑자기 꺼지면 끊김 처리가 없어 `online: false`가 가지 않습니다. 키는 150초 뒤 사라지고 다음 G4에서 맞춰집니다.
- 알림을 놓치거나 길드 목록에 없는 사람이면 게임은 0.5초 모아 G4를 다시 받습니다. 언제 보내는지 표: [realtime-api.md 접속 표시 처리](../contracts/realtime-api.md#접속-표시-처리).
