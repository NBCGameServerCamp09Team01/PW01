# 채팅 흐름 (M23 채팅)

> 상태: 초안(클래스 이름은 채팅 계획서 기준, 구현 PR에서 맞춤) · 명세: [chat-api.md](../contracts/chat-api.md), [realtime-api.md `CHAT_MESSAGE`](../contracts/realtime-api.md#메시지-종류) · Redis: [redis-keys.md 채팅](../contracts/redis-keys.md#채팅v16) · 서버 사이 전달: [realtime-relay.md](realtime-relay.md)

보내기는 HTTP(CH1·CH2), 받기는 실시간 연결(`CHAT_MESSAGE`)입니다. 보내는 HTTP를 받은 서버와 받는 사람의 WebSocket이 붙은 서버가 다를 수 있어, 서버 사이 전달(Redis Pub/Sub)로 넘깁니다.

- ① 전체 채팅(다른 서버로) · ② 길드 채팅(다른 서버로) · ③ 같은 요청을 다시 보냄 · ④ 횟수 제한과 도배 쉬기 · ⑤ 길드 없이 길드 채팅 · ⑥ 다시 붙어 길드 내역으로 채우기 · ⑦ 길드 해체 때 지우기 · ⑧ 보관 기간 지우기

## 참여자

| 이름 | 저장소·위치 | 하는 일 |
|---|---|---|
| `UWarriorChatSubsystem` | 게임 `Chat/` | 보내기(CH1·CH2)·내역(CH3), 실시간 `CHAT_MESSAGE` 받기(공용 `OnMessage` 구독), 탭별 줄 보관·`messageId` 겹침 제거 |
| 채팅 창(`UWarriorChatPanelWidget`, `WBP_ChatPanel`) | 게임 `Chat/`·에셋 | 메인메뉴 `Slot_Chat`에 들어가는 창. 탭·날짜선·`HH:MM`·입력·남은 초 |
| `ChatController` | 웹서버 `chat/controller` | CH1·CH2·CH3 |
| `ChatService` | 웹서버 `chat/service` | 판정 순서(글 → 중복 방지 → 횟수 제한 → 길드 → 저장 → 보내기) |
| `ChatTextPolicy` | 웹서버 `chat/service` | 글 규칙(코드 포인트 100, 제어 문자) |
| `IdempotencyService` | 웹서버 `common/idempotency` | 같은 `requestId`면 처음 응답(`pw01:idem`) |
| `RedisChatRateLimiter` | 웹서버 `chat/repository` | `chat_rate.lua`(횟수 제한 + 도배 쉬기) |
| `GuildDirectory` | 웹서버 `common/chat`(구현 `GuildDirectoryImpl`, 길드) | 보낸 사람의 길드, 길드원 목록 |
| `GuildChatHistory` | 웹서버 `common/chat`(구현 `GuildChatHistoryImpl`, 채팅) | 길드 채팅 저장(V11 `guild_chat_message`)·내역 |
| `GlobalChatHistory` | 웹서버 `common/chat`(구현 `NoStoreGlobalChatHistory`) | 전체 채팅 번호(UUID)·시각만 매김, 저장 안 함 |
| `RealtimeNotifier` | 웹서버 `realtime/service` | `sendToAll`·`sendToGuild` — 이 서버 연결에 바로, 다른 서버에는 채널로 |
| `ChatDisbandListener`·`GuildChatCleanupJob` | 웹서버 `chat/service` | 해체 이벤트 받아 지우기, 하루 한 번 보관 기간 지우기 |

## ① 전체 채팅 — 다른 서버에 붙은 사람에게

```mermaid
sequenceDiagram
  autonumber
  participant G1 as 게임 1 (A에 붙음)
  participant LB as 로드 밸런서
  participant C as A: ChatController·ChatService
  participant R as Redis
  participant N as A: RealtimeNotifier
  participant B as B: RealtimeRelayListener
  participant G2 as 게임 2 (B에 붙음)

  G1->>LB: POST /chats/global {requestId, text}
  LB->>C: A로
  C->>C: ChatTextPolicy.check(text)
  C->>R: pw01:idem 처음 응답 확인(없음 → 처리 중 표시)
  C->>R: EVALSHA chat_rate.lua → {0,0}
  C->>C: NoStoreGlobalChatHistory.append → messageId(UUID)·sentAt
  C->>N: sendToAll(CHAT_MESSAGE)
  N-->>G1: A의 연결 모두(보낸 사람 포함)
  N->>R: PUBLISH pw01:realtime-relay:global
  R-->>B: 전체 채널
  B-->>G2: B의 연결 모두
  C->>R: pw01:idem 처음 응답 기억
  C-->>G1: 200 data = 채팅 한 줄
  G1->>G1: 응답으로 그림, 같은 messageId 실시간은 버림
```

## ② 길드 채팅 — 커밋 뒤에, 그 길드원에게만

```mermaid
sequenceDiagram
  autonumber
  participant G1 as 게임 1 (길드 7, A에 붙음)
  participant C as A: ChatService
  participant D as GuildDirectory
  participant H as GuildChatHistory
  participant DB as MySQL
  participant N as A: RealtimeNotifier
  participant R as Redis 채널
  participant G2 as 게임 2 (길드 7, B에 붙음)

  G1->>C: POST /chats/guild {requestId, text}
  C->>C: 글 검사 · 중복 방지 · chat_rate.lua 통과
  C->>D: guildIdOf(보낸 사람) → "7"
  C->>H: append("7", …) (트랜잭션)
  H->>DB: INSERT guild_chat_message
  C->>DB: 커밋
  C->>D: memberIds("7")
  C->>N: sendToGuild("7", 길드원, CHAT_MESSAGE)
  N-->>G1: A에 붙은 길드원
  N->>R: PUBLISH pw01:realtime-relay:guild:7
  R-->>G2: B가 받아 B에 붙은 길드원에게
  C-->>G1: 200 data = 채팅 한 줄(messageId = 저장 번호)
```

- 저장이 실패하면(503) 보내지 않습니다. 보내기 실패는 응답을 바꾸지 않습니다(놓칠 수 있음 — ⑥으로 채움).
- 받은 게임은 `guildId`가 지금 내 길드가 아니면 버립니다(막 나간 사람).

## ③ 같은 요청을 다시 보냄

```mermaid
sequenceDiagram
  autonumber
  participant G as 게임
  participant C as ChatService
  participant R as Redis

  G->>C: POST /chats/guild {requestId: X, text}
  C->>R: 처음 → 처리·저장·보내기 → 처음 응답 기억
  C--xG: 응답을 잃음(연결 끊김)
  G->>C: 같은 requestId X · 같은 본문(자동 다시 보내기 또는 [다시])
  C->>R: pw01:idem X = 끝남
  C-->>G: 처음 응답 그대로(같은 messageId). 다시 저장·보내기 없음, 횟수도 안 셈
```

- 다른 본문이면 409 `IDEMPOTENCY_KEY_REUSED`, 처음 요청이 아직 처리 중이면 409 `REQUEST_IN_PROGRESS`.

## ④ 횟수 제한과 도배 쉬기

```mermaid
sequenceDiagram
  autonumber
  participant G as 게임
  participant C as ChatService
  participant L as chat_rate.lua

  loop 10초 안에 6번째
    G->>C: POST /chats/global
    C->>L: 창 수 6 > 5 → 처음 넘음 → 경고 1
    C-->>G: 429 CHAT_RATE_LIMITED, retryAfterSeconds = 창 남은 초
  end
  Note over G,L: 1분 안에 서로 다른 창 세 개에서 제한에 걸림
  G->>C: POST /chats/guild
  C->>L: 경고 3 → chat-mute 60초 걸고 경고 지움
  C-->>G: 429 CHAT_MUTED, retryAfterSeconds = 60
  G->>C: 쉬는 동안 보내기(전체·길드 모두)
  C->>L: chat-mute 남음
  C-->>G: 429 CHAT_MUTED, retryAfterSeconds = 남은 초
```

- 게임은 429를 자동으로 다시 보내지 않고, 남은 초 동안 보내기 버튼을 막습니다.
- 서버가 둘이어도 같은 키를 스크립트 한 번으로 세므로, 서버를 바꿔 보내도 수가 같습니다.

## ⑤ 길드 없이 길드 채팅

| 요청 | 결과 |
|---|---|
| CH2 보내기 | 횟수 제한은 셈 → `guildIdOf` 빈 값 → 403 `GUILD_NOT_MEMBER` |
| CH3 내역 | 403 `GUILD_NOT_MEMBER`. 게임 길드 탭은 "길드에 가입하면 길드 채팅을 볼 수 있습니다" |

## ⑥ 다시 붙어 길드 내역으로 채우기

```mermaid
sequenceDiagram
  autonumber
  participant G as 게임(UWarriorChatSubsystem)
  participant RT as 실시간 연결
  participant C as ChatController
  participant H as GuildChatHistory

  RT--xG: 끊김(그사이 길드 채팅을 놓침)
  RT-->>G: 다시 붙음([Realtime] Connected)
  G->>C: GET /chats/guild (before 없음, size 10)
  C->>H: loadLatest(내 길드, null, 10) — 3일 안, 최신부터
  C-->>G: messages(새것 → 옛것), nextCursor
  G->>G: 뒤집어 붙이되 이미 있는 messageId는 건너뜀
```

- 길드가 바뀔 때(`OnMyGuildChanged`)와 채팅 창을 열 때도 같은 순서입니다. 위로 끝까지 스크롤하면 `before = nextCursor`로 이전 10개를 받아 위에 붙입니다.
- 전체 채팅은 저장하지 않으므로 끊긴 동안의 것은 채우지 않습니다.

## ⑦ 길드 해체 때 지우기

```mermaid
sequenceDiagram
  autonumber
  participant S as 길드 GuildMembershipTx
  participant DB as MySQL
  participant L as 채팅 ChatDisbandListener
  participant R as Redis

  S->>DB: 소속 비우기·신청 지우기·길드 지우기 (트랜잭션)
  S->>S: publishEvent(GuildDisbandedEvent("7", …)) — 같은 트랜잭션 안
  S->>DB: 커밋
  DB-->>L: AFTER_COMMIT으로 받음(롤백되면 오지 않음)
  L->>DB: 새 트랜잭션(REQUIRES_NEW): DELETE guild_chat_message WHERE guild_id = 7
  L->>R: (Lv2) DEL pw01:guild-chat-recent:7
```

- 길드는 채팅 표를 모릅니다(외래 키 없음). 지우기가 실패해도 그 길드를 읽을 사람이 없고 ⑧이 3일 뒤 치웁니다.

## ⑧ 보관 기간 지우기

- 하루 한 번(설정 `pw01.chat.cleanup.cron`, UTC) `DELETE … WHERE created_at < 지금 − 3일 LIMIT 1000`을 0줄이 될 때까지 짧은 트랜잭션으로 반복합니다.
- 서버 둘이 같이 돌아도 결과가 같습니다(잠금 없음). 내역은 지우기와 상관없이 늘 3일 안만 읽습니다.
