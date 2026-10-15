# Redis 키 규칙

> 버전: v1.5 · 상태: 합의(v1.3 랭킹 절·v1.4 체크포인트 절·v1.5 서버 사이 전달 절은 초안, PR 리뷰 전) · 사용: PW01WebServer · 담당: Sang-Hyun-Kim · 리뷰: Robbie

웹서버가 Redis에 쓰는 키의 이름·타입·만료 규칙입니다. 새 키를 쓰기 전에 여기에 먼저 추가합니다.

v1은 첫 흐름(S1: 회원가입·로그인·메인화면 값·접속 점검·로그아웃)의 키 셋입니다. 인증은 불투명 토큰 + Redis 세션이고 JWT는 쓰지 않습니다.

v1.2는 상태를 바꾸는 요청의 중복 방지 키(S3 투자부터)를 더합니다. 게임 쪽 규칙은 [README.md 상태를 바꾸는 요청과 재전송](README.md#상태를-바꾸는-요청과-재전송)에 있습니다.

## 인증 방식(결정 기록)

> 10/7 결정. 이 문서의 세션 키·스크립트가 왜 이런 모양인지의 근거입니다. 다시 정할 때는 이 절을 먼저 고칩니다.

| 무엇 | 정한 것 |
|---|---|
| 로그인 상태 유지 | **불투명 토큰 + Redis 세션.** JWT는 쓰지 않습니다 |
| 토큰 | 32바이트 임의 값, URL-safe Base64(패딩 없음, 43자). 토큰에는 정보가 없고, 게임은 해석하지 않고 `Authorization: Bearer <토큰>`으로 붙입니다 |
| 저장 | Redis에 토큰 해시 → 계정 ID, 계정 ID → 지금 토큰 해시(계정당 세션 1개, 새 로그인이 이김) |
| 인증 위치 | Spring MVC `HandlerInterceptor`. Spring Security 필터는 쓰지 않고, 비밀번호 해시(BCrypt)에만 `spring-security-crypto`를 씁니다 |

**JWT 대신 이 방식을 고른 이유**

- Redis가 이미 필수입니다. 세션·로그인 실패 횟수를 Redis에 두고, Redis가 없으면 서비스를 멈춥니다(503). JWT의 가장 큰 장점인 "저장소를 보지 않고 누구인지 안다"를 쓸 곳이 없습니다.
- JWT를 넣으면 장치가 늘어납니다. 로그아웃·다른 곳 로그인을 바로 반영하려면 결국 Redis를 다시 봐야 하고, Redis 조회를 아끼려면 서버 메모리 끊김 표시, 서버 사이 알림(Pub/Sub), 토큰 수명과 세션 수명이라는 시계 두 개, 점검 때 새 토큰 발급, 서명 키 관리가 필요합니다.
- 아낄 비용이 거의 없습니다. 싱글 게임이라 요청이 적고, Redis 조회는 1ms 안쪽입니다.
- 이 방식이면 Redis 조회 한 번으로 로그아웃·다른 곳 로그인·제재가 다음 요청에 바로 반영되고, 토큰 갱신과 서명 키가 없습니다.

**HandlerInterceptor를 고른 이유**

- 필요한 일이 "헤더 → 토큰 모양 → 세션 → 다른 곳 로그인" 확인과 세션 연장뿐입니다. Spring Security 필터 체인은 이보다 설정이 크고, 오류 응답을 공통 형식(`GlobalExceptionHandler`)에 맞추는 일이 따로 생깁니다.
- 인터셉터에서 던진 예외도 `@RestControllerAdvice`로 와서 다른 API와 같은 오류 본문이 됩니다.

**이 결정의 대가(알고 고른 것)**

- 인증이 필요한 요청마다 Redis 읽기 하나와 스크립트 하나가 돕니다.
- Redis 장애는 곧 인증 불가(503)입니다.
- 과제 키워드(JWT, Stateless)를 그대로 따르지 않으므로, 발표·문서에서 위 이유를 설명합니다.

**다시 볼 때**

- 서버 밖의 다른 서비스가 토큰을 직접 검증해야 할 때
- 인증 요청 수가 늘어 Redis 부하가 문제가 될 때

## 이름 규칙

- 형식: `pw01:<용도>:<식별자>`. 소문자, 구분자는 `:`, 여러 낱말은 `-`로 잇습니다(예: `account-session`).
- 이 문서의 `<…>`는 자리 표시입니다. 실제 키에 꺾쇠나 중괄호를 넣지 않습니다(중괄호는 Redis 클러스터에서 해시 태그로 읽힙니다).
- 만료(TTL)가 필요한 키는 반드시 TTL을 적습니다. 첫 흐름의 키는 모두 TTL이 있습니다.
- 토큰 원문은 키·값·로그에 넣지 않습니다. 키에는 토큰의 SHA-256 해시(소문자 16진수 64자)를 씁니다.

## Redis 접근

| 값 모양 | 쓰는 것 | 예 |
|---|---|---|
| 문자열·정수 | `StringRedisTemplate`(Spring Boot 기본 빈) | 첫 흐름 키 셋 전부, Lua 스크립트 인자 |
| 객체(JSON) | `jsonRedisTemplate`(`RedisTemplate<String, Object>`, 값은 JSON 직렬화기) | 아직 쓰는 키 없음 |
| JSON 문자열 | `StringRedisTemplate` + 서버의 `JsonMapper`로 직접 쓰고 읽음 | `pw01:idem`(중복 방지) |
| Pub/Sub 메시지(JSON 문자열) | 보내기: `StringRedisTemplate.convertAndSend(채널, 문자열)` / 받기: `RedisMessageListenerContainer`(전용 구독 연결) | `pw01:realtime-relay:*`(v1.5, [아래](#실시간-서버-사이-전달v15)) |

- Lua 스크립트에 넘기는 키·인자는 문자열 직렬화기를 거쳐야 합니다. JSON 직렬화기를 거치면 `600`이 `"600"`이 되어 `EXPIRE`가 실패합니다.
- 새 키를 표에 더할 때 "값 모양" 칸에 어느 쪽인지 적습니다.
- 중복 방지 키를 JSON 문자열로 두는 이유: 처음 응답을 기능마다 다른 응답 타입으로 다시 읽어야 해서, 값 안에 타입 정보를 넣지 않고 읽는 쪽이 타입을 정합니다. `SET … NX`·`SET … XX`도 문자열 값으로 그대로 씁니다.

## 설정 값

시간·횟수는 코드와 스크립트에 숫자로 쓰지 않고 설정에서 읽습니다. 기본값은 10/7 회의 값이고, `application.properties`(또는 프로필 파일, 환경 변수)만 고치면 바뀝니다.

| 값 | 기본값 | 설정 이름 | 환경 변수로 덮을 때 |
|---|---|---|---|
| 세션 수명 | 10분. 인증이 필요한 요청(접속 점검 포함)마다 그 시점부터 다시 건다 | `pw01.auth.session.ttl=10m` | `PW01_AUTH_SESSION_TTL` |
| 로그인 실패 허용 | 5번. 5번째로 틀리면 그 응답부터 잠김 | `pw01.auth.login-fail.max-attempts=5` | `PW01_AUTH_LOGINFAIL_MAXATTEMPTS` |
| 실패를 세는 시간 | 1분. 첫 실패부터 이 시간 안의 실패만 센다 | `pw01.auth.login-fail.window=1m` | `PW01_AUTH_LOGINFAIL_WINDOW` |
| 잠김 시간 | 1분(잠긴 때부터) | `pw01.auth.login-fail.lock=1m` | `PW01_AUTH_LOGINFAIL_LOCK` |
| 중복 방지: 처음 응답을 기억하는 시간 | 24시간 | `pw01.idempotency.ttl=24h` | `PW01_IDEMPOTENCY_TTL` |
| 중복 방지: 처리 중 표시 시간 | 30초. 서버가 처리 중에 죽어도 이 시간이 지나면 풀린다 | `pw01.idempotency.in-progress-ttl=30s` | `PW01_IDEMPOTENCY_INPROGRESSTTL` |
| 체크포인트 `state` 최대 크기(v1.4) | 64KB. 넘으면 C1이 400 | `pw01.play-checkpoint.max-state-size=64KB` | `PW01_PLAYCHECKPOINT_MAXSTATESIZE` |

- 시간은 초 단위여야 합니다(Redis `EXPIRE`가 초 단위). 1초보다 짧거나 초 아래 값이 있으면 서버가 뜨지 않습니다.

### 값의 관계

- **세션 수명 > 접속 점검 간격 × 허용 연속 실패 횟수.** 점검 간격과 허용 실패 횟수는 게임 쪽 값이고, 웹서버(Robbie)·게임(Juunnmmoo)이 이 관계에 맞춰 정합니다. 세션 수명을 바꿀 때도 이 관계를 다시 봅니다.
- 플레이 중에는 HTTP 요청이 없으므로 연장은 WebSocket Ping/Pong이 맡습니다(연결은 레벨을 옮겨도 살아 있습니다).
- **처리 중 표시 시간 > 요청 하나의 처리 시간**(진행 저장 재시도 포함). 짧으면 처리 중에 표시가 사라져 같은 요청이 한 번 더 실행됩니다. 그래도 DB 방어가 두 번 반영을 막지만 응답이 `ALREADY_SAVED`로 바뀝니다.
- **기억 시간 ≥ 게임이 같은 요청을 다시 보낼 수 있는 기간.** 지나면 DB 방어로 `ALREADY_SAVED` + 지금 값을 돌려줍니다(두 번 반영되지는 않음).

## 키 목록

| 키 패턴 | 자료형 | TTL | 용도 | 값 모양 | 쓰는 곳 | 장애 시 |
|---|---|---|---|---|---|---|
| `pw01:session:<토큰 해시>` | String | 세션 수명, 요청마다 다시 | 토큰 → 계정 | 계정 ID(10진수 문자열) | 로그인 때 만듦, 인증이 필요한 요청마다 읽고 연장, 로그아웃 때 삭제 | 503 |
| `pw01:account-session:<계정 ID>` | String | 세션 키와 함께 늘림 | 계정의 지금 세션(계정당 1개, 새 로그인이 이김) | 지금 토큰 해시(문자열) | 로그인 때 덮어씀, 요청마다 비교·연장, 로그아웃 때 조건부 삭제, 제재 때 삭제 | 503 |
| `pw01:login-fail:<아이디>` | String(정수) | 첫 실패 때 실패를 세는 시간, 허용 횟수에 닿으면 잠김 시간으로 다시 | 로그인 실패 횟수 | 실패 횟수(정수) | 로그인 전 확인, 실패 때 증가, 성공 때 삭제 | 503 |
| `pw01:idem:<계정 ID>:<requestId>` | String(JSON 문자열) | 처리 중: 처리 중 표시 시간 / 끝남: 기억 시간 | 상태를 바꾸는 요청을 한 번만 실행하고, 다시 오면 처음 응답을 돌려줌 | `{"state":"IN_PROGRESS"\|"DONE","bodyHash":"<본문 SHA-256>","body":"<처음 응답 data의 JSON 문자열, 처리 중이면 null>"}` | 스탯 투자(S3), 스킬 해금(S4), 우편함(나중). Service가 `IdempotencyService.run(...)`으로 부름 | 503 |
| `pw01:play-checkpoint:<stagePlayId>` | String(JSON 문자열) | 플레이 마감(`expiresAt`)까지. 저장할 때마다 남은 시간으로 다시 | 진행 중인 플레이의 마지막 체크포인트(v1.4, [아래](#플레이-체크포인트v14)) | `{"accountId":"1","clearedWave":2,"contentVersion":1,"elapsedSeconds":96.4,"savedAt":"…Z","state":{…}}` | C1 저장(덮어씀), C2 읽음, 결과 저장·포기·만료 때 삭제 | 503(C1·C2). 삭제 실패는 무시(마감 때 사라짐) |

- `<아이디>`는 **입력 그대로**입니다. 아이디는 대소문자를 구분하므로(`Warrior01`과 `warrior01`은 다른 계정) 소문자로 맞추지 않습니다. 맞추면 서로 다른 계정이 잠김을 같이 씁니다.
- 아이디 형식(영문 대소문자·숫자 4~20자)에 맞지 않는 로그인은 실패 키를 만들지 않습니다(키 길이를 묶음).
- 다른 곳에서 로그인하면 이전 세션 키는 TTL까지 남습니다(이전 기기에 "다른 곳에서 로그인"을 알리려고).
- 크기(Redis 7.4, `MEMORY USAGE`): 세션 키 136바이트, 계정 세션 키 144바이트.
- `pw01:idem`: `<requestId>`는 소문자 UUID입니다. 키에 기능 이름을 넣지 않습니다(10/12 확인). 다른 API에 같은 `requestId`를 쓰면 본문 해시가 달라 409 `IDEMPOTENCY_KEY_REUSED`입니다. 계정 ID를 넣는 것은 남의 `requestId`로 남의 처음 응답을 받지 못하게 하려는 것입니다.
- `pw01:idem`: 본문 해시는 서버가 요청 DTO를 다시 JSON으로 쓴 문자열의 해시입니다(칸 순서·공백이 달라도 같은 요청). 토큰·비밀번호는 값에 넣지 않고, 인증 API에는 쓰지 않습니다.
- `pw01:idem`: 스테이지 플레이 시작·결과 제출에는 쓰지 않습니다. 둘은 DB(시작 `requestId`, 플레이 ID)로 이미 한 번만 반영됩니다. 체크포인트 저장(C1)에도 쓰지 않습니다(덮어쓰기라 다시 와도 결과가 같음).
- 앞으로 더할 키(그 기능에서 이 표에 먼저 적음): 접속 상태, 속도 제한. M23 채팅·길드 키는 각 담당이 `## 채팅`·`## 길드` 절을 만들어 적습니다(예정 이름: 채팅 횟수 제한 `pw01:chat-rate:<계정 ID>`, 길드 소속 캐시 `pw01:guild-members:<길드 ID>`, 길드 채팅 최신 묶음 캐시 `pw01:guild-chat-recent:<길드 ID>`, 접속 상태 `pw01:presence:…`). 서버 사이 전달 채널은 키가 아니므로 이 표에 넣지 않고 [실시간 서버 사이 전달](#실시간-서버-사이-전달v15) 절에 둡니다.

## 명령 순서(첫 흐름)

| 때 | 명령 | 묶음 |
|---|---|---|
| 로그인 `POST /auth/login`, 비밀번호 확인 전 | `GET pw01:login-fail:<아이디>` → 허용 횟수 이상이면 `TTL`로 남은 잠김 시간을 읽고, 비밀번호를 보지 않고 429 | 읽기(잠겼을 때 둘) |
| 로그인 실패 | `login_fail.lua` → {횟수, 남은 잠김 초}. 남은 잠김 초가 0보다 크면 429, 아니면 401 | Lua(INCR과 EXPIRE를 한 번에) |
| 로그인 성공 | `DEL pw01:login-fail:<아이디>` 뒤 `session_login.lua` | Lua(세션 키 둘을 한 번에) |
| 인증이 필요한 요청마다(인터셉터) | `GET pw01:session:<해시>` → 없으면 `AUTH_SESSION_NOT_FOUND` / 있으면 `session_extend.lua` → 1 통과(세션 수명으로 다시), 0 `AUTH_SESSION_NOT_FOUND`, 2 `AUTH_SESSION_REPLACED` | 읽기 하나 + Lua(비교 + 두 키 연장) |
| 접속 점검 `POST /auth/heartbeat` | 인터셉터가 이미 연장했다. 늘어난 만료 시각만 돌려준다 | — |
| 로그아웃 `POST /auth/logout` | 인터셉터 뒤 `session_logout.lua` | Lua(비교 + 삭제) |
| 제재를 손으로 걸 때(제재 기능은 아직 없음) | DB `status`를 `SUSPENDED`로 바꾸고 `DEL pw01:account-session:<계정 ID>` → 그 계정의 모든 토큰이 다음 요청에서 401, 다음 로그인은 제재 오류 | 한 명령 |

- 서버가 여러 대여도 모두 같은 Redis를 보므로, 로그아웃·다른 곳 로그인·제재가 다음 요청에 바로 반영됩니다. 서버 메모리 표시나 Pub/Sub은 쓰지 않습니다.
- 스크립트는 웹서버 `src/main/resources/redis/*.lua`에 두고 `DefaultRedisScript`로 부릅니다.

## 명령 순서(중복 방지, v1.2)

`IdempotencyService.run(계정 ID, requestId, 요청 본문, 응답 타입, 처리)`가 아래 순서로 부릅니다. 스크립트 없이 명령 하나씩입니다(각 명령이 조건부라 한 번에 묶을 필요가 없음).

| 때 | 명령 | 결과 |
|---|---|---|
| 처리 전 | `SET pw01:idem:<계정 ID>:<requestId> {IN_PROGRESS, 해시} NX EX <처리 중 표시 시간>` | 성공 → 처리 시작 |
| 위가 실패(이미 있음) | `GET` 같은 키 | `DONE` + 같은 해시 → 처음 응답 그대로 / `IN_PROGRESS` + 같은 해시 → 409 `REQUEST_IN_PROGRESS`(`retryable: true`) / 다른 해시 → 409 `IDEMPOTENCY_KEY_REUSED`(`retryable: false`) / 그사이 사라짐 → 처음 줄을 한 번 더 |
| 처리가 성공(2xx)으로 끝남 | `SET 같은 키 {DONE, 해시, 처음 응답} XX EX <기억 시간>` | 처음 응답 기억. 처리 중 표시가 먼저 사라졌으면 기억하지 못하고 경고 로그만 남김(다시 오면 DB 방어) |
| 처리가 거절·실패(4xx·5xx)로 끝남 | `DEL 같은 키` | 기억하지 않음. 같은 `requestId`로 다시 보내면 처음처럼 다시 판정(10/12 확인) |
| Redis에 닿지 못함 | — | 503 `SERVICE_UNAVAILABLE`(10/12 확인). 인증이 필요한 요청은 그 전에 세션 확인에서 이미 503 |

- **마지막 방어는 기능마다 DB에 둡니다.** Redis 기억이 없어도 두 번 반영되지 않아야 합니다. 투자: 변경 내역 유일 제약 `(account_id, source_type, source_id, kind)`, `source_id = <requestId>:<스탯 태그>` → `saveStatus: ALREADY_SAVED`.

## 스크립트

### session_login.lua

```lua
-- 로그인 성공 뒤 세션 만들기. 두 키를 한 번에 쓴다(가운데서 멈추면 새 토큰이 "다른 곳에서 로그인"이 되는 일을 막음).
-- KEYS[1] = pw01:session:<새 토큰 해시>
-- KEYS[2] = pw01:account-session:<계정 ID>
-- ARGV[1] = 계정 ID, ARGV[2] = 새 토큰 해시, ARGV[3] = 세션 수명(초)
-- 돌려줌: 이전 토큰 해시(없으면 빈 문자열). 이전 세션 키는 지우지 않고 TTL까지 둔다 → 이전 기기는 AUTH_SESSION_REPLACED
redis.call('SET', KEYS[1], ARGV[1], 'EX', ARGV[3])
local previous = redis.call('SET', KEYS[2], ARGV[2], 'EX', ARGV[3], 'GET')
if not previous then
  return ''
end
return previous
```

### session_extend.lua

```lua
-- 인증이 필요한 요청마다(접속 점검 포함) 두 키의 TTL을 함께 늘린다.
-- 계정 키가 지금 내 해시일 때만 늘린다(그사이 다른 곳에서 로그인했으면 늘리지 않음).
-- KEYS[1] = pw01:session:<토큰 해시>
-- KEYS[2] = pw01:account-session:<계정 ID>
-- ARGV[1] = 토큰 해시, ARGV[2] = 세션 수명(초)
-- 돌려줌: 1 = 늘림, 0 = 세션 없음(세션 키나 계정 키가 없음), 2 = 다른 곳에서 로그인
if redis.call('EXISTS', KEYS[1]) == 0 then
  return 0
end
local current = redis.call('GET', KEYS[2])
if not current then
  return 0
end
if current ~= ARGV[1] then
  return 2
end
redis.call('EXPIRE', KEYS[1], ARGV[2])
redis.call('EXPIRE', KEYS[2], ARGV[2])
return 1
```

### session_logout.lua

```lua
-- 로그아웃. 내 세션 키는 늘 지우고, 계정 키는 지금 값이 내 해시일 때만 지운다.
-- (다른 곳에서 로그인한 뒤 이전 기기의 로그아웃이 새 기기의 세션을 지우지 않게)
-- KEYS[1] = pw01:session:<토큰 해시>
-- KEYS[2] = pw01:account-session:<계정 ID>
-- ARGV[1] = 토큰 해시
-- 돌려줌: 1 = 두 키를 지움, 0 = 내 세션 키만 지움(계정 키는 다른 토큰 것이거나 없음)
redis.call('DEL', KEYS[1])
if redis.call('GET', KEYS[2]) == ARGV[1] then
  redis.call('DEL', KEYS[2])
  return 1
end
return 0
```

### login_fail.lua

```lua
-- 로그인 실패를 하나 센다(INCR과 EXPIRE를 한 번에).
-- 첫 실패에 "실패를 세는 시간"을 TTL로 걸어 그 안의 실패만 센다. 허용 횟수에 닿으면 그때부터 잠김 시간으로 TTL을 다시 건다.
-- KEYS[1] = pw01:login-fail:<아이디(입력 그대로)>
-- ARGV[1] = 허용 실패 횟수, ARGV[2] = 실패를 세는 시간(초), ARGV[3] = 잠김 시간(초)
-- 돌려줌: {실패 횟수, 남은 잠김 초}. 잠기지 않았으면 남은 잠김 초는 0
local count = redis.call('INCR', KEYS[1])
local max = tonumber(ARGV[1])
if count == 1 then
  redis.call('EXPIRE', KEYS[1], ARGV[2])
end
if count < max then
  return {count, 0}
end
if count == max then
  redis.call('EXPIRE', KEYS[1], ARGV[3])
end
return {count, redis.call('TTL', KEYS[1])}
```

## 플레이 체크포인트(v1.4)

진행 중인 스테이지 플레이의 판 안 값([stage-play-api.md C1·C2](stage-play-api.md#c1c2-체크포인트)). 플레이당 키 하나를 덮어씁니다.

- 키에 계정 ID를 넣지 않습니다. 주인 확인은 MySQL `stage_play`로 먼저 하고(남의 플레이는 404), 값의 `accountId`는 점검용입니다.
- 만료는 플레이 마감까지 남은 초(올림, 최소 1초)입니다. 결과 저장·포기·만료 처리 때 `DEL`합니다. MySQL 트랜잭션이 커밋된 뒤에 지우고, 실패해도 결과·포기 응답은 바꾸지 않습니다.
- 크기: `state`는 설정 최대 크기(처음 64KB) 이하. 지금 게임의 체크포인트는 약 2KB입니다.

### 명령 순서(체크포인트)

| API | 순서 |
|---|---|
| C1 저장 | MySQL로 내 플레이·진행 중·마감 확인 → 요청 값 검사 → `play_checkpoint_put.lua`(비교와 저장을 한 번에) → -1이면 409 `CHECKPOINT_OUT_OF_ORDER` |
| C2 받기 | MySQL로 내 플레이 확인 → `GET` → 없으면 204 |
| 판 끝(R1·P4·만료) | 커밋 뒤 `DEL pw01:play-checkpoint:<stagePlayId>` |

### play_checkpoint_put.lua

```lua
-- KEYS[1] = pw01:play-checkpoint:<stagePlayId>
-- ARGV[1] = 새 clearedWave(정수), ARGV[2] = 저장할 JSON 문자열, ARGV[3] = 만료(초)
-- 돌려줌: 1 = 저장함, -1 = 저장된 clearedWave보다 작음(저장 안 함)
local current = redis.call('GET', KEYS[1])
if current then
  local saved = cjson.decode(current)
  if tonumber(saved.clearedWave) > tonumber(ARGV[1]) then
    return -1
  end
end
redis.call('SET', KEYS[1], ARGV[2], 'EX', tonumber(ARGV[3]))
return 1
```

- 같은 `clearedWave`는 덮어씁니다(같은 요청을 다시 보낸 경우).

## 랭킹(v1.3)

[ranking-api.md](ranking-api.md)의 순위 보드입니다. **원천은 MySQL**(랭킹 클리어 기록·스테이지 최고 기록·지역 점수·전체 총합·진행 표)이고, Redis 보드는 언제든 다시 채울 수 있는 사본입니다. 그래서 랭킹 키가 사라지거나 어긋나도 데이터를 잃지 않습니다.

### 보드와 순서

- 키 안의 `<보드>`:

| 보드 | `<보드>` | 예 |
|---|---|---|
| 스테이지 전체 | `stage:<stageId>:d<난이도>:all` | `stage:stage.01.01:d0:all` |
| 스테이지 주간 | `stage:<stageId>:d<난이도>:week:<YYYY-Www>` | `stage:stage.01.01:d0:week:2026-W42` |
| 지역 전체·주간 | `region:<regionId>:d<난이도>:all` · `…:week:<YYYY-Www>` | `region:region.01:d0:all` |
| 전체 총합 전체·주간 | `total:d<난이도>:all` · `…:week:<YYYY-Www>` | `total:d0:all` |
| 진행 | `progress:all` | `progress:all` |

- 주는 ISO 주(월요일 00:00 UTC 시작)입니다.
- 순서: 보드 점수가 높을수록 위 → 같으면 먼저 달성 → 같으면 기록 순번이 작은 쪽.
- **ZSet 점수 = −(보드 점수)**: 오름차순(`ZRANGE`)으로 읽으면 높은 점수가 먼저 옵니다. 보드 점수는 정수(스테이지 1,000~10,000, 지역·전체 총합은 그 합, 진행은 스테이지 수)라 double로 정확합니다.
- **멤버 = `<달성 epoch 밀리초 13자리>:<기록 순번 20자리>:<계정 ID>:<상세>`**(앞 두 칸은 0으로 채움). 예: `1760249400123:00000000000000000042:12:183400`.
  - Redis는 점수가 같으면 멤버를 바이트(문자) 순서로 세웁니다. 앞 두 칸의 자리 수를 고정했으므로 문자 순서 = "먼저 달성 → 먼저 기록"입니다. 기록 순번이 유일하므로 그 뒤 칸은 순서에 영향이 없습니다.
  - 점수 하나(double)에 점수·달성 시각(밀리초)·순번을 함께 넣을 수 없어서 이렇게 나눴습니다. 달성 13자리는 2286년까지입니다.
  - `<상세>`: 스테이지 보드 = 그 기록의 클리어 시간 ms, 지역·전체 총합 보드 = 클리어한 스테이지 수, 진행 보드 = 가장 먼 스테이지 키. 응답의 `playTimeSeconds`·`clearedStageCount`·`furthestStageId`에 씁니다.
- 멤버가 기록마다 바뀌므로, 계정 ID로 지금 멤버를 찾는 해시를 함께 둡니다. 둘은 늘 스크립트 하나로 같이 고칩니다.
- 빈 ZSet은 Redis가 지웁니다. 그래서 "보드가 있다(채워져 있다)"는 해시의 특수 필드 `@`로 판단합니다. 기록이 하나도 없는 보드도 `@`만 있는 해시로 있습니다.
- 세 보드 모두 점수가 내려가지 않습니다(스테이지 최고·그 합·클리어 수). 그래서 "더 좋을 때만 바꿈" 하나로 갱신합니다.

### 키

| 키 패턴 | 자료형 | TTL | 용도 | 값 모양 | 쓰는 곳 | 장애 시 |
|---|---|---|---|---|---|---|
| `pw01:rank:<보드>` | ZSet | 전체·진행: 고칠 때마다 지금 + 전체 보드 수명 / 주간: 그 주 끝 + 주간 보관 기간(`EXPIREAT`) | 순위 | 점수 = −보드 점수, 멤버 = 위 멤버 | 결과 커밋 뒤 고침, RK1~RK8 조회 | MySQL로 대신 |
| `pw01:rank:<보드>:member` | Hash | ZSet과 같음 | 계정 → 지금 멤버, 보드 있음 표시 | 필드 = 계정 ID(10진수) → 멤버, 필드 `@` → `1` | 같음 | MySQL로 대신 |
| `pw01:rank:<보드>:build` | ZSet | 임시 보드 수명 | 다시 채우는 중의 임시 보드 | 위 ZSet과 같음 | 다시 채우기, 그사이 결과 커밋 | 다시 채우기 실패(다음에 다시) |
| `pw01:rank:<보드>:build:member` | Hash | 임시 보드 수명 | 임시 보드의 계정 → 멤버, 채우는 중 표시 | 위 해시와 같음 | 같음 | 같음 |
| `pw01:rank-lock:<보드>` | String | 다시 채우기 잠금 시간 | 한 보드를 서버 하나만 다시 채우게 | 그 서버의 임의 토큰 | 다시 채우기 시작·끝 | 다시 채우지 않고 MySQL로 대신 |

- 값 모양은 모두 문자열·정수이고 `StringRedisTemplate` + `DefaultRedisScript`로 씁니다.
- 랭킹 키의 "장애 시"는 **랭킹 명령만 실패하는 부분 장애**입니다. Redis 전체 장애면 그 전에 인증(세션 확인)에서 503입니다.
- 크기(어림): 계정 하나가 ZSet 멤버 약 45바이트 + 해시 필드 하나. 계정 1만 명 × (스테이지 + 지역) 10개 × (전체 + 주간)이면 수십 MB 안쪽입니다. 실제 값은 구현 뒤 `MEMORY USAGE`로 적습니다.
- 전체 보드에도 수명(30일)을 거는 이유: 운영 Redis가 메모리 부족 때 "만료가 있는 키부터" 지우는 정책이면, 만료 없는 랭킹 키는 남고 세션 키가 먼저 지워집니다. 랭킹은 사본이라 만료돼도 다시 채웁니다(운영 정책은 `noeviction` + 경보로 정함).

### 설정 값

| 값 | 기본값 | 설정 이름 | 환경 변수로 덮을 때 |
|---|---|---|---|
| 전체 보드 수명 | 30일. 전체·진행 보드를 고치거나 다시 채울 때마다 이 시간으로 다시 건다 | `pw01.ranking.all-board-ttl=30d` | `PW01_RANKING_ALLBOARDTTL` |
| 주간 보드 보관 기간 | 14일. 그 주가 끝난 뒤 이만큼 지나면 주간 보드 키가 사라진다 | `pw01.ranking.weekly-retention=14d` | `PW01_RANKING_WEEKLYRETENTION` |
| 다시 채우기 잠금 시간 | 30초 | `pw01.ranking.rebuild-lock-ttl=30s` | `PW01_RANKING_REBUILDLOCKTTL` |
| 임시 보드 수명 | 60초. 다시 채우다 서버가 죽어도 이 시간이 지나면 사라진다 | `pw01.ranking.build-ttl=60s` | `PW01_RANKING_BUILDTTL` |
| 다시 채우기 한 번에 넣는 줄 | 500 | `pw01.ranking.build-batch-size=500` | `PW01_RANKING_BUILDBATCHSIZE` |

- 시간은 초 단위입니다(위 [설정 값](#설정-값)과 같은 규칙).
- **임시 보드 수명 > 다시 채우기 잠금 시간 > 보드 하나를 다시 채우는 시간.** 잠금이 먼저 풀리면 다른 서버가 같은 보드를 다시 채우기 시작하고, 앞 서버의 끝내기는 잠금 토큰이 달라 실패합니다(잘못 바꿔 끼우지 않음). 계정 1만 명 보드는 1초 안쪽으로 예상하고, 구현 뒤 잰 값을 적습니다.

### 명령 순서(랭킹)

| 때 | 명령 | 결과 |
|---|---|---|
| 클리어 결과가 **커밋된 뒤**(서버 이벤트) | `rank_update.lua`를 스테이지 전체·주간, (스테이지 최고가 올랐으면) 지역·전체 총합 전체 기간, 지역·전체 총합 주간(그 주 합을 MySQL에서 읽음), (처음 클리어면) 진행 보드에 한 번씩 | 보드·임시 보드가 있으면 더 좋은 기록일 때만 바꿈. 둘 다 없으면 넣지 않음(다음 조회 때 MySQL에서 채우면 들어 있음) |
| 위가 실패(Redis 명령 오류·시간 초과) | — | 보드마다 경고 로그 + 그 서버 메모리에 "다시 채울 보드" 표시. 결과 저장은 이미 끝나 있음 |
| 목록(RK1·3·5·7) | `rank_page.lua` | 보드 없음 → 다시 채우기 / 시작 위치 + 줄 목록 |
| 내 줄(RK2·4·6·8) | `rank_me.lua` | 보드 없음 → 다시 채우기 / 전체 수 + 내 순위·멤버·점수(없으면 전체 수만) |
| 다시 채우기(보드 없음, 또는 다시 채울 보드 표시) | `rank_build_start.lua` → MySQL 읽기 → `rank_build_add.lua`(묶음마다) → `rank_build_finish.lua` | 끝나면 보드가 통째로 바뀌고 표시를 지움. 시작에서 잠금을 못 얻으면 이번 요청은 MySQL로 대신 |
| 랭킹 명령이 실패 | — | 경고 로그, 이번 요청은 MySQL로 대신 |

- 다시 채우기는 MySQL을 읽기 **전에** 임시 보드(`@`)를 만듭니다. 그 뒤에 커밋된 결과는 `rank_update.lua`가 임시 보드에도 넣으므로, 바꿔 끼운 보드에서 빠지지 않습니다. 그 전에 커밋된 결과는 MySQL 읽기에 들어 있습니다.
- 전체 보드는 스테이지 최고 기록·지역 점수·전체 총합·진행 표에서, 주간 보드는 랭킹 클리어 기록 표에서 그 주만 걸러 계정별 최고(지역·전체 총합은 그 합)를 읽습니다.
- "다시 채울 보드" 표시는 서버 메모리에 있어 서버가 다시 뜨면 사라집니다(알고 고른 한계, [ranking-api.md](ranking-api.md#서버가-순위를-두는-곳과-장애-때-응답)).

### 랭킹 유의사항

- **"처리 중 표시" 키가 둘입니다.** 중복 방지 `pw01:idem`의 `IN_PROGRESS`(v1.2)와 랭킹 다시 채우기 잠금 `pw01:rank-lock:<보드>`가 "한 번에 하나만 하게 막는 표시"라는 같은 일을 따로 합니다. 모양(토큰 비교, 수명)이 달라 지금은 묶지 않습니다. 셋째 쓰임이 생기면 공용 틀로 묶을지 봅니다.
- **키 앞부분 `pw01:rank:`·`pw01:rank-lock:`은 랭킹 전용**입니다. 다른 기능은 쓰지 않습니다.
- 랭킹 스크립트는 한 보드의 키 2~5개를 함께 다룹니다. 클러스터 모드면 같은 슬롯이어야 하므로 아래 "정할 것"(클러스터 모드를 끄고 복제만)을 따릅니다.

### rank_update.lua

```lua
-- 한 계정의 줄을 보드에 넣는다. 그 계정의 지금 줄보다 좋을 때만 바꾼다(ZSet 점수 = −보드 점수가 작을수록, 같으면 멤버 문자 순서).
-- 보드가 있으면 보드에, 다시 채우는 중이면 임시 보드에도 넣는다. 둘 다 없으면 넣지 않는다.
-- KEYS[1] = pw01:rank:<보드>          KEYS[2] = pw01:rank:<보드>:member
-- KEYS[3] = pw01:rank:<보드>:build    KEYS[4] = pw01:rank:<보드>:build:member
-- ARGV[1] = 계정 ID, ARGV[2] = 멤버, ARGV[3] = ZSet 점수(−보드 점수)
-- ARGV[4] = 보드 만료 시각(epoch 초). 0이면 만료를 건드리지 않음(서버는 늘 값을 넘김)
-- 돌려줌: 1 = 바꿈, 0 = 그대로(더 좋지 않음), -1 = 보드가 없어 넣지 않음
local function put(z, h)
  local score = tonumber(ARGV[3])
  local old = redis.call('HGET', h, ARGV[1])
  if old then
    local oldScore = tonumber(redis.call('ZSCORE', z, old))
    if oldScore and (score > oldScore or (score == oldScore and ARGV[2] >= old)) then
      return 0
    end
    redis.call('ZREM', z, old)
  end
  redis.call('ZADD', z, score, ARGV[2])
  redis.call('HSET', h, ARGV[1], ARGV[2])
  return 1
end

local result = -1
if redis.call('HEXISTS', KEYS[2], '@') == 1 then
  result = put(KEYS[1], KEYS[2])
  if ARGV[4] ~= '0' then
    redis.call('EXPIREAT', KEYS[1], ARGV[4])
    redis.call('EXPIREAT', KEYS[2], ARGV[4])
  end
end
if redis.call('HEXISTS', KEYS[4], '@') == 1 then
  local r = put(KEYS[3], KEYS[4])
  local ttl = redis.call('PTTL', KEYS[4])
  if ttl > 0 then
    redis.call('PEXPIRE', KEYS[3], ttl)
  end
  if result == -1 then
    result = r
  end
end
return result
```

### rank_page.lua

```lua
-- 순위 목록 한 묶음. 커서(마지막으로 준 줄의 점수·멤버) 다음부터 읽는다.
-- KEYS[1] = pw01:rank:<보드>, KEYS[2] = pw01:rank:<보드>:member
-- ARGV[1] = 읽을 줄 수(limit + 1, 한 줄 더 읽어 다음이 있는지 안다)
-- ARGV[2] = 커서 줄의 ZSet 점수(없으면 빈 문자열), ARGV[3] = 커서 줄의 멤버
-- 돌려줌: 보드가 없으면 nil / {시작 위치(0부터), {멤버, 점수, 멤버, 점수, …}}
if redis.call('HEXISTS', KEYS[2], '@') == 0 then
  return false
end
local start = 0
if ARGV[2] ~= '' then
  local s = redis.call('ZSCORE', KEYS[1], ARGV[3])
  if s and tonumber(s) == tonumber(ARGV[2]) then
    start = redis.call('ZRANK', KEYS[1], ARGV[3]) + 1
  else
    -- 커서 줄이 그사이 바뀌었으면(그 계정의 기록이 올라 멤버가 바뀜) 값으로 위치를 센다
    start = redis.call('ZCOUNT', KEYS[1], '-inf', '(' .. ARGV[2])
    local same = redis.call('ZRANGE', KEYS[1], ARGV[2], ARGV[2], 'BYSCORE')
    for _, m in ipairs(same) do
      if m <= ARGV[3] then
        start = start + 1
      end
    end
  end
end
local rows = redis.call('ZRANGE', KEYS[1], start, start + tonumber(ARGV[1]) - 1, 'WITHSCORES')
return {start, rows}
```

### rank_me.lua

```lua
-- 내 순위.
-- KEYS[1] = pw01:rank:<보드>, KEYS[2] = pw01:rank:<보드>:member
-- ARGV[1] = 계정 ID
-- 돌려줌: 보드가 없으면 nil / 기록이 없으면 {전체 수} / {전체 수, 순위(0부터), 멤버, 점수}
if redis.call('HEXISTS', KEYS[2], '@') == 0 then
  return false
end
local total = redis.call('ZCARD', KEYS[1])
local m = redis.call('HGET', KEYS[2], ARGV[1])
if not m then
  return {total}
end
local r = redis.call('ZRANK', KEYS[1], m)
if not r then
  return {total}
end
return {total, r, m, redis.call('ZSCORE', KEYS[1], m)}
```

### rank_build_start.lua

```lua
-- 다시 채우기 시작. 잠금을 얻고 빈 임시 보드(@만 있음)를 만든다.
-- KEYS[1] = pw01:rank-lock:<보드>, KEYS[2] = pw01:rank:<보드>:build, KEYS[3] = pw01:rank:<보드>:build:member
-- ARGV[1] = 서버 토큰, ARGV[2] = 잠금 시간(초), ARGV[3] = 임시 보드 수명(초)
-- 돌려줌: 1 = 시작, 0 = 다른 서버가 채우는 중
if not redis.call('SET', KEYS[1], ARGV[1], 'NX', 'EX', ARGV[2]) then
  return 0
end
redis.call('DEL', KEYS[2], KEYS[3])
redis.call('HSET', KEYS[3], '@', '1')
redis.call('EXPIRE', KEYS[3], ARGV[3])
return 1
```

### rank_build_add.lua

```lua
-- MySQL에서 읽은 기록 묶음을 임시 보드에 넣는다. 비교 규칙은 rank_update.lua와 같다.
-- KEYS[1] = pw01:rank:<보드>:build, KEYS[2] = pw01:rank:<보드>:build:member
-- ARGV = 계정 ID, 멤버, ZSet 점수(−보드 점수)를 한 줄씩 이어 붙임(줄 수 × 3)
-- 돌려줌: 바꾼 줄 수, 임시 보드가 사라졌으면 -1
if redis.call('HEXISTS', KEYS[2], '@') == 0 then
  return -1
end
local changed = 0
for i = 1, #ARGV, 3 do
  local id, member, score = ARGV[i], ARGV[i + 1], tonumber(ARGV[i + 2])
  local old = redis.call('HGET', KEYS[2], id)
  local oldScore = old and tonumber(redis.call('ZSCORE', KEYS[1], old))
  if not (oldScore and (score > oldScore or (score == oldScore and member >= old))) then
    if old then
      redis.call('ZREM', KEYS[1], old)
    end
    redis.call('ZADD', KEYS[1], score, member)
    redis.call('HSET', KEYS[2], id, member)
    changed = changed + 1
  end
end
local ttl = redis.call('PTTL', KEYS[2])
if ttl > 0 then
  redis.call('PEXPIRE', KEYS[1], ttl)
end
return changed
```

### rank_build_finish.lua

```lua
-- 다시 채우기 끝. 잠금이 아직 내 것이고 임시 보드가 살아 있으면 보드를 통째로 바꿔 끼운다.
-- KEYS[1] = pw01:rank:<보드>, KEYS[2] = pw01:rank:<보드>:member
-- KEYS[3] = pw01:rank:<보드>:build, KEYS[4] = pw01:rank:<보드>:build:member, KEYS[5] = pw01:rank-lock:<보드>
-- ARGV[1] = 서버 토큰, ARGV[2] = 보드 만료 시각(epoch 초). 0이면 만료 없음(서버는 늘 값을 넘김)
-- 돌려줌: 1 = 바꿔 끼움, 0 = 잠금을 잃었거나 임시 보드가 만료됨(바꾸지 않음)
if redis.call('GET', KEYS[5]) ~= ARGV[1] or redis.call('HEXISTS', KEYS[4], '@') == 0 then
  return 0
end
if redis.call('EXISTS', KEYS[3]) == 1 then
  redis.call('RENAME', KEYS[3], KEYS[1])
else
  redis.call('DEL', KEYS[1])
end
redis.call('RENAME', KEYS[4], KEYS[2])
if ARGV[2] == '0' then
  redis.call('PERSIST', KEYS[1])
  redis.call('PERSIST', KEYS[2])
else
  redis.call('EXPIREAT', KEYS[1], ARGV[2])
  redis.call('EXPIREAT', KEYS[2], ARGV[2])
end
redis.call('DEL', KEYS[5])
return 1
```

## 실시간 서버 사이 전달(v1.5)

웹서버가 여러 대(로드 밸런서 뒤)일 때 실시간 알림을 받는 사람이 붙은 서버까지 넘기는 Pub/Sub 채널입니다([realtime-api.md 서버 여러 대](realtime-api.md#서버-여러-대), 흐름 [docs/flows/realtime-relay.md](../flows/realtime-relay.md)). **키가 아니므로** 값·TTL이 없고 `SCAN`에 보이지 않습니다. 다른 기능은 채널을 직접 쓰지 않고 웹서버 `RealtimeNotifier`의 보내기 입구만 부릅니다.

### 채널

| 채널 | 실리는 것 | 서버가 듣는 법 | 받은 서버가 하는 일 |
|---|---|---|---|
| `pw01:realtime-relay:global` | 접속한 모두에게 갈 메시지(전체 채팅) | `SUBSCRIBE` | 자기 연결 모두에게 보냄 |
| `pw01:realtime-relay:guild:<길드 ID>` | **그 길드 하나**의 메시지(길드 채팅·길드 알림·길드원 접속 표시). 길드마다 채널 하나 | 패턴 하나 `PSUBSCRIBE pw01:realtime-relay:guild:*` | 메시지의 계정 목록 중 자기에게 붙은 사람에게만 |
| `pw01:realtime-relay:target` | 계정을 지정한 메시지(한 사람·여러 사람)와 세션 다시 확인(`SESSION_CHECK`) | `SUBSCRIBE` | 목록 중 자기에게 붙은 사람에게만 |

- 모든 서버가 세 가지를 모두 듣습니다. 길드 채널은 패턴 하나로 들으므로 길드가 생기고 없어져도 구독을 바꾸지 않습니다. 패턴으로 듣는 채널은 `PUBSUB CHANNELS`에 나오지 않고 `PUBSUB NUMPAT`에 셈으로만 나옵니다.
- 보낸 서버는 자기 연결에는 채널을 거치지 않고 바로 보내고, 채널에서 돌아온 자기 메시지(`origin`이 자기)는 버립니다.

### 메시지 모양(JSON 문자열)

```json
{
  "v": 1,
  "kind": "DELIVER",
  "origin": "a1b2c3d4",
  "guildId": "7",
  "accountIds": ["12", "57"],
  "message": { "type": "CHAT_MESSAGE", "id": "…", "sentAt": "…Z", "data": {} }
}
```

| 칸 | 값 | 설명 |
|---|---|---|
| `v` | `1` | 모양 판. 모르는 판은 버리고 경고 로그를 남깁니다(배포 중 옛·새 서버가 섞일 때) |
| `kind` | `DELIVER` / `SESSION_CHECK` | 게임에 보내기 / 그 계정 연결의 세션을 Pong 때와 같은 판정으로 다시 확인(다른 곳 로그인이면 `4001`) |
| `origin` | 문자열 | 보낸 서버 번호(서버가 뜰 때 정하는 임의 값). 자기 메시지를 알아보고 로그에서 서버를 가릅니다 |
| `guildId` | 문자열 | 길드 채널만. 채널 이름의 길드와 다르면 버립니다 |
| `accountIds` | 문자열 배열 | 길드·지정 채널만. 받을 계정(ID는 문자열 — 공통 규칙) |
| `message` | 실시간 메시지 그대로 | [realtime-api.md 메시지](realtime-api.md#메시지). `SESSION_CHECK`이면 없음 |

- 받는 서버는 **모르는 칸을 무시**하고 읽습니다(새 서버가 칸을 더해도 옛 서버가 깨지지 않게). 깨진 메시지·한도 초과는 버리고 경고 로그(메시지 `id`만, `data`는 찍지 않음).
- 한도: 메시지 8KB, 계정 목록 500개(설정 `pw01.realtime.relay.max-message-bytes`·`max-targets`).

### 성질과 장애

- **놓칠 수 있음**: Pub/Sub은 그 순간 듣고 있는 서버에만 갑니다. Redis와의 구독 연결이 끊긴 동안의 메시지는 사라지고, 연결이 돌아오면 다시 구독합니다(기본 5초 간격). 놓친 길드 채팅은 게임이 내역을 다시 불러와 채웁니다.
- 구독은 평소 명령이 쓰는 연결과 다른 **전용 연결**을 씁니다(구독 중인 연결은 다른 명령을 못 함).
- 보내기가 실패해도(Redis 장애) 부른 기능에 예외를 던지지 않습니다. 같은 서버 사람에게는 이미 보냈고, 경고 로그만 남깁니다.
- 받기는 서버마다 스레드 하나로 처리합니다(한 서버에서 온 메시지 순서를 지키려고). 다른 서버에서 온 메시지끼리의 순서는 보장하지 않습니다.
- 클러스터 모드를 켜면(지금은 끔) 샤드 Pub/Sub(`SPUBLISH`/`SSUBSCRIBE`)으로 바꿔야 하고, 샤드 Pub/Sub에는 패턴 구독이 없으므로 길드 채널은 "자기에게 붙은 길드원의 길드만 구독"으로 바꿉니다(채널 이름·메시지 모양은 그대로).

### 설정 값

| 값 | 기본값 | 설정 이름 |
|---|---|---|
| 서버 사이 전달 켜기 | 켬(끄면 자기 연결에만) | `pw01.realtime.relay.enabled=true` |
| 전체 채널 | `pw01:realtime-relay:global` | `pw01.realtime.relay.global-channel` |
| 길드 채널 앞부분 | `pw01:realtime-relay:guild:` | `pw01.realtime.relay.guild-channel-prefix` |
| 지정 채널 | `pw01:realtime-relay:target` | `pw01.realtime.relay.target-channel` |
| 메시지 최대 크기 | 8KB | `pw01.realtime.relay.max-message-bytes=8192` |
| 계정 목록 최대 | 500 | `pw01.realtime.relay.max-targets=500` |

## 정할 것

| 무엇 | 지금 | 누가 |
|---|---|---|
| 접속 점검 간격, 허용 연속 실패 횟수 | 위 "값의 관계"에 맞춰 | Robbie·Juunnmmoo |
| 키 이름 규칙 | 용도 먼저(`pw01:<용도>:<식별자>`, v1). v0 틀은 도메인 먼저였음 | Sang-Hyun-Kim |
| Redis 클러스터(배포 때) | 세션 스크립트는 키 둘을, 랭킹 스크립트는 한 보드의 키 2~5개를 함께 다룬다. 클러스터 모드에서는 그 키들이 같은 슬롯이어야 하므로 클러스터 모드를 끄거나(복제만) 해시 태그를 쓴다. 서버 사이 전달(v1.5)도 클러스터 모드에서는 샤드 Pub/Sub으로 바꿔야 한다. 배포 ElastiCache는 클러스터 모드 끔(10/14) | Sang-Hyun-Kim(배포 때) |
| 랭킹 "다시 채울 보드" 표시를 잃지 않게 | 서버 메모리. 확장 때 아웃박스 표 또는 관리자 다시 채우기 명령 | Sang-Hyun-Kim |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v0 | 2026-09-28 | 문서 틀 생성 |
| v1 | 2026-10-07 | 첫 흐름 키 3개(세션·계정 세션·로그인 실패), Redis 접근 규칙, 설정 값(세션 10분·요청마다 연장, 1분 안에 5번 실패하면 1분 잠김, 모두 설정으로 바꿈), 명령 순서, Lua 4개 |
| v1.1 | 2026-10-07 | 인증 방식 결정 기록 추가(불투명 토큰 + Redis 세션, HandlerInterceptor, 이유·대가·다시 볼 때). 키·스크립트는 바뀌지 않음 |
| v1.3 | 2026-10-12 | 랭킹 절: 보드 이름(스테이지·지역·전체 총합 × 난이도 × 전체·주간, 진행), ZSet 점수 = −보드 점수, 멤버 = 달성 ms + 기록 순번 + 계정 ID + 상세, 키(ZSet + 계정 → 멤버 해시, 임시 보드, 다시 채우기 잠금), 설정 5개(전체 보드 30일, 주간 보관 14일, 잠금 30초, 임시 보드 60초, 묶음 500), 명령 순서(커밋 뒤 갱신, 실패 표시, 다시 채우기, 부분 장애 때 MySQL), Lua 6개, 유의사항. v1.2(중복 방지 키, `docs/s3-stat-api`) 다음 판 |
| v1.4 | 2026-10-13 | 플레이 체크포인트 절: 키 `pw01:play-checkpoint:<stagePlayId>`(String JSON, 만료 = 플레이 마감), 설정 `state` 최대 크기 64KB, 명령 순서(C1 비교·저장 한 번에, C2 읽기, 판 끝 때 커밋 뒤 삭제), Lua `play_checkpoint_put.lua` |
| v1.5 | 2026-10-15 | 실시간 서버 사이 전달 절(M23 뼈대): Pub/Sub 채널 셋 종류(전체 `pw01:realtime-relay:global`, 길드마다 `pw01:realtime-relay:guild:<길드 ID>` + 패턴 구독, 지정 `pw01:realtime-relay:target`), 메시지 모양(`v`·`kind`·`origin`·`guildId`·`accountIds`·`message`), 놓칠 수 있음·전용 구독 연결·받기 스레드 하나, 설정 6개. "Redis 접근" 표에 Pub/Sub 줄, M23 채팅·길드 예정 키 이름 안내. 키는 늘지 않음 |
