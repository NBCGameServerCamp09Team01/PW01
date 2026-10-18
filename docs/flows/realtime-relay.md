# 실시간 서버 사이 전달 흐름 (M23 뼈대, SF-11)

> 상태: 초안 · 명세: [realtime-api.md 서버 여러 대](../contracts/realtime-api.md#서버-여러-대), [메시지 종류](../contracts/realtime-api.md#메시지-종류) · Redis: [redis-keys.md 실시간 서버 사이 전달](../contracts/redis-keys.md#실시간-서버-사이-전달v15) · 배포 모양: 로드 밸런서 뒤 웹서버 여러 대(로컬은 웹서버 `compose.apps.yaml`의 nginx + 앱 둘)

로드 밸런서는 HTTP 요청을 요청마다 아무 서버로 보내고, WebSocket은 처음 붙은 서버에 계속 붙여 둡니다. 그래서 "알림을 보내는 HTTP를 받은 서버"와 "받는 사람의 WebSocket이 붙은 서버"가 다를 수 있습니다. 서버들은 Redis Pub/Sub 채널로 메시지를 서로 넘기고, 각 서버는 **자기에게 붙은 사람에게만** 보냅니다.

- ① 같은 서버 · ② 다른 서버(길드 채널) · ③ 전체(전체 채널) · ④ 다른 곳 로그인(세션 다시 확인) · ⑤ Redis가 잠깐 끊김 · ⑥ 서버끼리 알림: 웨이브 정의 바뀜(`CONTENT_CHANGED`, 게임에 안 감)

## 참여자

| 이름 | 저장소·위치 | 하는 일 |
|---|---|---|
| 기능 서비스(예: 채팅 `ChatService`) | 웹서버 각 기능 | DB 커밋 뒤 `RealtimeNotifier`의 보내기를 부름 |
| `RealtimeNotifier` | 웹서버 `realtime/service` | 보내기 입구 넷(`send`·`sendToAccounts`·`sendToGuild`·`sendToAll`). 한도 검사 → 이 서버 전달 → 채널에 올림 |
| `RealtimeLocalDelivery` | 웹서버 `realtime/service` | 이 서버 연결 목록에서 대상을 골라 WebSocket으로 보냄 |
| `RealtimeConnectionRegistry` | 웹서버 `realtime/service` | 계정 → 연결(이 서버 메모리) |
| `RealtimeRelayPublisher` | 웹서버 `realtime/repository` | 서버 사이 메시지(JSON)를 채널에 올림(`convertAndSend`). 실패해도 예외를 던지지 않음 |
| `RealtimeRelayListener` | 웹서버 `realtime/service` | 채널에서 받아 거름(자기 것·판·길드 맞춤) → `RealtimeLocalDelivery` 또는 `RealtimeHeartbeat.revalidate` |
| `RealtimeRelayConfig` | 웹서버 `config` | 구독 컨테이너: 전체·지정 채널 + 길드 패턴 `pw01:realtime-relay:guild:*`, 받기 스레드 하나 |
| `RealtimeHeartbeat` | 웹서버 `realtime/service` | Pong 연장과 "세션 다시 확인"이 같이 쓰는 판정 `revalidate` |
| `RealtimeSessionListener` | 웹서버 `realtime/service` | 로그인 이벤트 → 이 서버 연결에 4001 + 다른 서버에 세션 다시 확인 |
| `StageContentEndpoint`·`StageContentReloader` (새, 판 12) | 웹서버 `stage/` | 관리 포트 신호로 웨이브 정의를 다시 읽고, 바뀌었으면 `RealtimeNotifier.notifyContentChanged()`로 `CONTENT_CHANGED`를 올림. 받은 쪽은 `RealtimeEventPublisher`가 `ServerContentChangedEvent`를 내고 `StageContentChangeListener`가 다시 읽기를 **전용 스레드**(`StageContentSafetyPoll`)에 맡김 |
| Redis 채널 | `pw01:realtime-relay:global` / `:guild:<길드 ID>` / `:target` | 서버 사이 전달(키 아님, 저장 안 함) |
| `UWarriorRealtimeSubsystem` | 게임 `Network/` | WebSocket 메시지 받기(모르는 종류는 무시) |

## ① 같은 서버에 붙은 사람

```mermaid
sequenceDiagram
  autonumber
  participant G1 as 게임 1 (A에 붙음)
  participant LB as 로드 밸런서
  participant Svc as A: 기능 서비스
  participant N as A: RealtimeNotifier
  participant D as A: RealtimeLocalDelivery
  participant P as A: RealtimeRelayPublisher
  participant R as Redis 채널

  G1->>LB: POST (예: 길드 채팅 보내기)
  LB->>Svc: A로
  Svc->>Svc: 저장·커밋
  Svc->>N: sendToGuild("7", 길드원, CHAT_MESSAGE)
  N->>N: 한도 검사(계정 500·8KB)
  N->>D: deliverToAccounts(길드원)
  D-->>G1: WebSocket 메시지(이 서버 길드원에게 바로)
  N->>P: publishToGuild("7", 길드원)
  P->>R: PUBLISH pw01:realtime-relay:guild:7 {v:1, kind:DELIVER, origin:A, …}
  R-->>A: (A도 구독 중) RealtimeRelayListener — origin이 자기 → 버림
  Svc-->>LB: 200
```

- 자기 서버에는 채널을 거치지 않고 바로 보냅니다. Redis가 막혀도 같은 서버 사람은 받습니다.

## ② 다른 서버에 붙은 사람(길드마다 채널)

```mermaid
sequenceDiagram
  autonumber
  participant A as 웹서버 A
  participant R as Redis
  participant L as B: RealtimeRelayListener
  participant Reg as B: RealtimeConnectionRegistry
  participant D as B: RealtimeLocalDelivery
  participant G2 as 게임 2 (B에 붙음, 길드 7)
  participant G3 as 게임 3 (B에 붙음, 길드 8)

  A->>R: PUBLISH pw01:realtime-relay:guild:7 {guildId:"7", accountIds:["12","57"], message}
  R-->>L: 패턴 pw01:realtime-relay:guild:* 로 받음(받기 스레드 하나)
  L->>L: 읽기(모르는 칸 무시) → origin ≠ B → v=1 → 채널 길드 7 = guildId 7
  L->>D: deliverToAccounts([12, 57], message)
  D->>Reg: find(12), find(57)
  Reg-->>D: 12만 B에 있음
  D-->>G2: WebSocket 메시지(같은 id)
  Note over G3: 길드 8 사람은 목록에 없어 받지 않음
```

- 채널의 길드와 메시지의 `guildId`가 다르면 버립니다(다른 길드에 가지 않게).
- 받는 서버는 길드를 다시 묻지 않습니다. 대상은 보낸 서버가 넣은 길드원 목록입니다.

## ③ 전체 채팅(전체 채널)

```mermaid
sequenceDiagram
  autonumber
  participant Svc as A: 채팅 서비스
  participant N as A: RealtimeNotifier
  participant R as Redis
  participant LB as B: RealtimeRelayListener
  participant DB as B: RealtimeLocalDelivery

  Svc->>N: sendToAll(CHAT_MESSAGE)
  N->>N: A의 연결 모두에게 바로(deliverToAll)
  N->>R: PUBLISH pw01:realtime-relay:global {message}
  R-->>LB: 받음
  LB->>DB: deliverToAll(message)
  Note over DB: B의 연결 모두에게
```

- 전체 채팅은 지금 서버에 저장하지 않습니다(`NoStoreGlobalChatHistory`). 나중에 들어온 사람은 그 전 전체 채팅을 볼 수 없습니다.

## ④ 다른 곳 로그인 — 이전 연결이 다른 서버에 있을 때

```mermaid
sequenceDiagram
  autonumber
  participant Old as 이전 기기 (A에 붙음)
  participant New as 새 기기
  participant B as 웹서버 B
  participant SL as B: RealtimeSessionListener
  participant R as Redis
  participant L as A: RealtimeRelayListener
  participant HB as A: RealtimeHeartbeat

  New->>B: POST /auth/login (로드 밸런서가 B로)
  B->>B: 새 세션(이전 세션은 "다른 곳 로그인" 상태)
  B->>SL: SessionIssuedEvent
  SL->>SL: B 연결 목록에 이전 연결 없음
  SL->>R: PUBLISH pw01:realtime-relay:target {kind:SESSION_CHECK, accountIds:["12"]}
  R-->>L: 받음
  L->>HB: revalidate(이전 연결)
  HB->>HB: extendSession(이전 토큰) → AUTH_SESSION_REPLACED
  HB-->>Old: SESSION_REPLACED 메시지 + 종료 코드 4001 (보통 1초 안)
  Note over HB: 새 기기가 먼저 A에 붙었다면 그 연결은 새 세션 → 판정 정상 → 닫지 않음
```

- 이 전달을 놓쳐도 이전 연결의 다음 Pong(최대 60초)에서 같은 판정으로 `4001`이 됩니다.
- 로그아웃은 서버 사이로 넘기지 않습니다(게임이 스스로 연결을 닫음).

## ⑤ Redis가 잠깐 끊김

```mermaid
sequenceDiagram
  autonumber
  participant A as 웹서버 A
  participant R as Redis
  participant B as 웹서버 B
  participant G2 as 게임 2 (B, 길드 7)

  Note over R: 구독 연결이 끊김
  A->>A: 이 서버 길드원에게는 바로 보냄
  A--xR: PUBLISH 실패 → 경고 로그만(부른 기능은 성공)
  Note over B: 그사이 메시지는 B에 오지 않음(Pub/Sub은 저장하지 않음)
  R-->>B: 다시 연결되면 구독 컨테이너가 다시 구독([Relay] subscribed …)
  G2->>B: (길드 화면) GET /guilds/me/chats — 내역을 다시 불러와 messageId로 합침
```

- 놓칠 수 있다는 것은 명세의 원칙입니다. 길드 채팅은 내역으로 채우고, 전체 채팅은 지금은 잃은 채로 둡니다.

## ⑥ 서버끼리 알림: 웨이브 정의 바뀜(판 12)

게임에 보내는 메시지가 아니라 **서버끼리** 쓰는 kind입니다([redis-keys.md](../contracts/redis-keys.md#실시간-서버-사이-전달v15) v1.9). 운영자가 S3 웨이브 정의를 바꾸고 서버 A의 관리 포트에 다시 읽기를 보내면, A가 바꾼 뒤 다른 서버에 알립니다. 정의 쪽 경우별 흐름은 [server-wave.md ⑥](server-wave.md)에 있습니다.

```mermaid
sequenceDiagram
  autonumber
  participant OP as 운영(Session Manager)
  participant A as 웹서버 A StageContentEndpoint (새)
  participant PUB as RealtimeRelayPublisher
  participant R as Redis 전체 채널
  participant L as 웹서버 B RealtimeRelayListener
  participant BG as 웹서버 B StageContentSafetyPoll 스레드 (새)
  participant RL as 웹서버 B StageContentReloader (새)

  OP->>A: POST localhost:8081/actuator/stagecontent
  A->>A: 다시 읽기 → CHANGED
  A->>PUB: RealtimeNotifier.notifyContentChanged() → publishContentChanged()
  PUB->>R: PUBLISH {"v":1,"kind":"CONTENT_CHANGED","origin":"<A>"}
  R-->>A: (A 자신도 받음) origin이 자기 → 버림
  R-->>L: 받음
  L->>BG: ServerContentChangedEvent (새) → StageContentChangeListener → reloadSoon("relay")
  Note over L: 받기 스레드는 여기서 바로 돌아감(S3 읽기로 채팅 전달이 밀리지 않게)
  BG->>RL: reload("relay")
  RL->>RL: S3 HEAD → 바뀜 → GET → 검사 → 교체
```

- 이 kind를 모르는 옛 서버(배포 중 섞여 돌 때)는 `[Relay] dropped: unknown kind=CONTENT_CHANGED …`로 버리고, 5분 주기 확인으로 따라옵니다. Redis가 끊긴 동안 놓친 알림도 같은 주기 확인이 메웁니다.
- 게임 연결(`RealtimeLocalDelivery`)로는 보내지 않습니다. 받기 로그는 `[Relay] content changed origin=…`입니다.

## 로그로 확인하기

| 무엇 | 로그(웹서버) |
|---|---|
| 서버 번호 | 뜰 때 `[Relay] serverId=<8자> host=<호스트>`. 모든 HTTP 응답 헤더 `X-Server-Id`와 같은 값 |
| 구독 | `[Relay] subscribed channel=…` / `pattern=pw01:realtime-relay:guild:*` |
| 이 서버에서 보냄 | `[Realtime] sent type=… id=… RealtimeConnection[accountId=…]` |
| 버림 | `[Relay] dropped: …`(이유), `[Realtime] not sent: …`(한도) |
| 올리기 실패 | `[Relay] publish failed channel=…` |

같은 메시지 `id`로 두 서버 로그를 찾으면 어느 서버에서 누구에게 갔는지 이어집니다.
