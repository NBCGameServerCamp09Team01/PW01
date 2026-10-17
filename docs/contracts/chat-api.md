# 채팅 API (Chat API)

> 버전: v1 · 상태: 초안 · 호출: 게임 클라이언트(UE) → 웹서버, 받기는 실시간 연결(WebSocket) · 게임 담당: Robbie · 웹서버 담당: Robbie (리뷰: Sang-Hyun-Kim)

메인메뉴의 작은 채팅 창에서 **전체 채팅**(접속한 모두)과 **길드 채팅**(내 길드원만)을 보내고 받습니다(M23). 보내기는 HTTP, 받기는 [realtime-api.md](realtime-api.md) `CHAT_MESSAGE`입니다. 서버가 여러 대여도 받는 사람에게 갑니다(같은 명세 "서버 여러 대").

- 경로·시각·성공 응답 `{data, meta}`·오류 응답·요청 번호: [README.md 공통 규칙](README.md#공통-규칙)
- 인증(토큰, 세션 연장, 401 네 종류): [auth-api.md 인증](auth-api.md#인증). 아래 API는 모두 인증이 필요합니다
- Redis 키·스크립트: [redis-keys.md 채팅](redis-keys.md#채팅v16)
- 아래 "응답 `data`" 표는 성공 응답의 `data` 안쪽 모양입니다.

## 엔드포인트

| ID | 메서드 | 경로 | 인증 | 성공 | 설명 |
|---|---|---|---|---|---|
| CH1 | POST | `/chats/global` | 필요 | 200 | 전체 채팅 보내기 |
| CH2 | POST | `/chats/guild` | 필요 | 200 | 내 길드에 채팅 보내기 |
| CH3 | GET | `/chats/guild` | 필요 | 200 | 내 길드 채팅 내역(최신부터 커서) |

- 보낼 길드는 요청에 넣지 않습니다. 서버가 **보낸 사람의 길드**로 정합니다(남의 길드에 쓸 수 없음).
- **전체 채팅은 서버에 저장하지 않습니다.** 받은 것을 바로 접속한 모두에게 보내고, 연결이 끊긴 동안의 전체 채팅은 다시 받을 수 없습니다. 전체 내역 `GET /chats/global`은 이름만 예약합니다(저장하게 되면 엽니다).
- 길드 채팅은 **3일** 보관합니다. 놓친 길드 채팅은 CH3로 채웁니다.

## 채팅 한 줄

CH1·CH2 응답, CH3 내역, 실시간 `CHAT_MESSAGE`의 `data`가 모두 이 모양입니다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `messageId` | string | 메시지 번호. **게임은 모양(숫자·UUID)에 기대지 않습니다** — 같은지 비교하거나 커서로 그대로 돌려 보내는 데만 씁니다. 지금 길드 = 저장 번호(10진수), 전체 = UUID |
| `scope` | string | `GLOBAL`(전체) · `GUILD`(길드) |
| `guildId` | string \| null | `GUILD`면 길드 ID(10진수 문자열, 길드 명세 `guild-api.md`의 길드 ID), `GLOBAL`이면 `null` |
| `senderAccountId` | string | 보낸 계정 ID |
| `senderNickname` | string | 보낸 때의 닉네임(나중에 바뀌어도 그 줄은 그대로) |
| `text` | string | 글(앞뒤 공백을 자른 것) |
| `sentAt` | string(UTC) | 서버가 받은 시각(밀리초까지). 게임은 PC 시간대로 `HH:MM`, 날짜가 바뀌는 줄 위에 날짜선 |

예시: `examples/chat-send-response.json`

## 규칙

| 항목 | 값 | 서버 설정 |
|---|---|---|
| 글 길이 | 앞뒤 공백을 자른 뒤 **1~100자**. 글자는 **코드 포인트**로 셉니다(이모지 하나가 1자) | `pw01.chat.max-length` |
| 쓸 수 없는 글 | 빈 글(공백만), 줄바꿈·탭 같은 **제어 문자**(가운데에 있으면). 서버는 글을 몰래 바꾸지 않습니다(자르기만) | — |
| 횟수 제한 | **10초에 5번**까지. 전체·길드를 **함께** 셉니다. 넘으면 429 `CHAT_RATE_LIMITED` | `pw01.chat.rate.*` |
| 도배 쉬기 | 횟수 제한에 **처음 걸린 10초마다 경고 1**(한 10초 안에 몇 번을 더 두드려도 1), **1분 안에 경고 3번이면 60초 동안 채팅을 쉽니다**(전체·길드 모두). 쉬는 동안은 429 `CHAT_MUTED` | `pw01.chat.mute.*` |
| 길드 채팅 보관 | 3일. 그보다 오래된 줄은 내역에 나오지 않습니다 | `pw01.chat.guild.retention` |
| 내역 묶음 | 기본 10줄, `size` 최대 50 | `pw01.chat.guild.page-size*` |

- 횟수 제한·도배 쉬기는 서버가 여러 대여도 **같은 수**로 셉니다(Redis 한곳, 스크립트 한 번).
- 금칙어·신고·귓속말은 없습니다(나중 확장).

## CH1. 전체 채팅 보내기 — `POST /chats/global`

요청

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `requestId` | string(UUID) | 예 | 이 요청의 번호(소문자·하이픈 36자). **다시 보낼 때 같은 값**. [한 번만 반영](#한-번만-반영) |
| `text` | string | 예 | 글. [규칙](#규칙) |

예시: `examples/chat-send-request.json`

### 판정 순서

| 순서 | 판정 | 걸리면 |
|---|---|---|
| 0 | 형식(필수·UUID·모르는 칸) | 400 `VALIDATION_FAILED` · `INVALID_REQUEST_BODY` |
| 1 | 글 규칙(빈 글·길이·제어 문자) | 400 `CHAT_TEXT_INVALID`(`errors[].field = "text"`) |
| 2 | 같은 `requestId`가 이미 처리됐나 | [한 번만 반영](#한-번만-반영) |
| 3 | 도배 쉬는 중인가 | 429 `CHAT_MUTED` |
| 4 | 횟수 제한(이 요청까지 세어 10초에 5번 넘나, 넘으면 경고를 세고 경고 3이면 쉬기 시작) | 429 `CHAT_RATE_LIMITED` 또는 이번에 쉬기가 시작되면 429 `CHAT_MUTED` |
| 5 | 메시지를 만들어(번호·시각) 접속한 모두에게 보냄 | 200 |

### 응답

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 보냄, 또는 이미 보낸 요청 | 성공 응답, `data` = [채팅 한 줄](#채팅-한-줄) |
| 400 | 형식, 글 규칙 | `VALIDATION_FAILED` · `INVALID_REQUEST_BODY` · `CHAT_TEXT_INVALID` |
| 401 | 인증 실패 | auth-api.md 네 코드 |
| 409 | 같은 키 다른 본문, 처리 중 | `IDEMPOTENCY_KEY_REUSED` · `REQUEST_IN_PROGRESS` |
| 429 | 횟수 제한, 도배 쉬기 | `CHAT_RATE_LIMITED` · `CHAT_MUTED`(+ `retryAfterSeconds`, `Retry-After`) |
| 503 | MySQL·Redis에 닿지 못함 | `SERVICE_UNAVAILABLE`(`retryable: true`) |

- 실시간 전달은 응답과 따로입니다. 응답이 200이어도 어떤 사람에게는 가지 않을 수 있습니다(연결이 끊긴 사람, 서버 사이 전달이 잠깐 끊김 — realtime-api.md "서버 여러 대").

## CH2. 길드 채팅 보내기 — `POST /chats/guild`

요청은 CH1과 같습니다. 판정 순서는 CH1의 4번 뒤에 아래가 들어갑니다.

| 순서 | 판정 | 걸리면 |
|---|---|---|
| 4-1 | 보낸 사람이 길드에 들어 있나 | 403 `GUILD_NOT_MEMBER` |
| 5 | 길드 채팅을 저장하고(커밋), 커밋 뒤에 **그 길드원에게만** 보냄 | 200 |

- 응답 상태 코드는 CH1과 같고, 403 `GUILD_NOT_MEMBER`가 더해집니다.
- 저장이 실패하면(503) 아무에게도 보내지 않습니다. 보내기는 저장이 커밋된 뒤입니다.
- 횟수 제한은 길드 확인보다 먼저라, 길드 없이 CH2를 여러 번 보내도 수가 셉니다.

## CH3. 길드 채팅 내역 — `GET /chats/guild`

쿼리

| 이름 | 타입 | 기본 | 규칙 |
|---|---|---|---|
| `before` | string | 없음(가장 최신부터) | 앞 묶음의 `nextCursor`를 그대로. 그 줄보다 옛것부터(그 줄은 빼고). 10진수 문자열이 아니면 400 `VALIDATION_FAILED` |
| `size` | integer | 10 | 1~50. 밖이면 400 `VALIDATION_FAILED` |

응답 `data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `messages` | array | [채팅 한 줄](#채팅-한-줄) 목록. **새것 → 옛것** 순. 게임은 뒤집어 옛것이 위·최신이 아래로 그림 |
| `nextCursor` | string \| null | 더 옛 묶음을 받을 때 `before`로 보낼 값. `null`이면 더 없음(또는 보관 기간 끝) |

| 상태 코드 | 의미 | 본문 |
|---|---|---|
| 200 | 성공(내역이 없으면 빈 목록) | 위 표 |
| 400 | `before`·`size` | `VALIDATION_FAILED` |
| 401 | 인증 실패 | auth-api.md 네 코드 |
| 403 | 길드 없음 | `GUILD_NOT_MEMBER` |
| 503 | MySQL에 닿지 못함 | `SERVICE_UNAVAILABLE` |

- 내역 읽기는 횟수 제한·도배 쉬기에 걸리지 않습니다.
- 커서는 번호 기준이라 그사이 새 글이 와도 겹치거나 빠지지 않습니다.
- 새 길드원도 가입 전 3일 안의 내역을 모두 봅니다.

예시: `examples/chat-history-response.json`

## 한 번만 반영

응답을 받지 못해 CH1·CH2를 다시 보내도(연결 끊김·503·버튼 두 번) 채팅은 **한 번만** 저장·전달됩니다.

| 경우 | 서버 응답 |
|---|---|
| 같은 `requestId` + 같은 본문, 처음 요청이 성공함 | **처음 응답 그대로**(같은 `messageId`, 24시간, `pw01.idempotency.ttl`). 다시 보내지 않고 횟수도 세지 않음 |
| 같은 `requestId` + 같은 본문, 처음 요청이 아직 처리 중 | 409 `REQUEST_IN_PROGRESS`(`retryable: true`) |
| 같은 `requestId` + **다른** 본문 | 409 `IDEMPOTENCY_KEY_REUSED`(`retryable: false`). 게임 버그 |
| 처음 요청이 4xx·5xx로 끝남(429 포함) | 기억하지 않음. 같은 `requestId`로 다시 보내면 처음처럼 다시 판정 |

- 서버는 계정 + `requestId`로 처음 응답을 Redis에 기억합니다([redis-keys.md](redis-keys.md) `pw01:idem`). 채팅은 DB 마지막 방어를 두지 않습니다 — 24시간이 지난 뒤 같은 요청이 오면 새 글로 보냅니다(게임은 채팅을 보관해 두었다 다시 보내지 않으므로 생기지 않음).

## 게임 처리 규칙

| 무엇 | 규칙 |
|---|---|
| `requestId` | 새로 보낸 글마다 새 값. 실패한 줄의 [다시]는 **같은 `requestId`·같은 본문** |
| 보관·재전송 | 채팅은 디스크에 보관하지 않고, 다시 로그인했을 때 다시 보내지 않습니다(README "보관 대상"에 넣지 않음). 실패하면 채팅 창의 그 줄에 "보내지 못함 [다시]" |
| 자동 다시 보내기 | 공통 규칙 그대로(`retryable: true`·응답 없음일 때 같은 본문으로). "다시 시도 / 종료" 묻기는 쓰지 않습니다 |
| 429 | 자동으로 다시 보내지 않습니다. `retryAfterSeconds` 동안 보내기 버튼을 막고 남은 초를 보입니다. `CHAT_RATE_LIMITED`는 "잠시 뒤에 보내 주세요", `CHAT_MUTED`는 "도배로 N초 동안 채팅을 쉽니다" |
| 자기 메시지 | 응답의 `data`로 바로 그립니다. 같은 `messageId`의 실시간 `CHAT_MESSAGE`가 오면 버립니다 |
| 받기 | 실시간 `CHAT_MESSAGE`: `scope`로 탭을 고르고, `GUILD`인데 `guildId`가 지금 내 길드가 아니면 버림, 같은 `messageId`는 한 번만 |
| 순서 | 받은 순서대로 아래에 붙입니다. 서버가 여러 대면 다른 서버에서 온 메시지끼리 순서가 바뀔 수 있습니다(받아들임) |
| 놓친 길드 채팅 | 실시간 연결이 다시 붙을 때, 길드가 바뀔 때, 창을 열 때 CH3 첫 묶음을 받아 `messageId`로 겹침을 없애 합칩니다 |
| 글 길이 | 입력 칸도 코드 포인트 100자로 막습니다(최종 판정은 서버). 글은 서식 없이(일반 글) 그립니다 |

## 오류

이 명세만의 오류 코드입니다. 공통 오류는 [README.md 오류 코드](README.md#오류-코드)에 있습니다.

| 코드 | HTTP | 상황 | `retryable` | 게임 쪽 처리(제안) |
|---|---|---|---|---|
| `CHAT_TEXT_INVALID` | 400 | 빈 글, 100자 넘음, 제어 문자(`errors[].field = "text"`) | false | 입력 칸 유지, "글을 확인해 주세요" |
| `GUILD_NOT_MEMBER` | 403 | 길드 없이 CH2·CH3(길드 명세와 같은 코드) | false | 길드 탭에 "길드에 가입하면 길드 채팅을 볼 수 있습니다" |
| `CHAT_RATE_LIMITED` | 429 | 10초에 5번 넘음(`retryAfterSeconds` = 그 10초가 끝날 때까지) | false | 남은 초 동안 보내기 막음 |
| `CHAT_MUTED` | 429 | 도배 쉬는 중(`retryAfterSeconds` = 남은 쉬기 시간) | false | 남은 초 동안 보내기 막음, 도배 안내 |

- 429의 `retryAfterSeconds`는 남은 시간을 초로 올림한 값(최소 1)이고, 같은 값이 `Retry-After` 헤더에도 붙습니다.

예시: `examples/chat-error-rate-limited.json`, `examples/chat-error-muted.json`

## 정할 것

| 무엇 | 지금 | 누가 |
|---|---|---|
| 전체 채팅 저장 | 저장 안 함(`GET /chats/global` 이름만 예약) | Robbie·Sang-Hyun-Kim |
| 금칙어·신고·귓속말 | 없음 | 나중 |
| 같은 글 반복(복붙) 막기 | 안 함(횟수 제한·도배 쉬기로 대신) | Robbie |
| 스테이지 안 채팅 창 | 메인메뉴만(받기는 스테이지 중에도 되고, 돌아오면 보임) | Robbie |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v1 | 2026-10-16 | 초안(M23 채팅): CH1 전체 보내기·CH2 길드 보내기·CH3 길드 내역, 채팅 한 줄 모양, 글 규칙(코드 포인트 100, 제어 문자), 횟수 제한(10초 5번, 전체·길드 함께)·도배 쉬기(1분 안에 제한 3번 → 60초), 길드 채팅 3일 보관·내역 10/50, 한 번만 반영(`requestId`), 게임 처리 규칙, 오류 넷 |
