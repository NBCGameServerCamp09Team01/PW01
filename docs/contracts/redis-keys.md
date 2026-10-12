# Redis 키 규칙

> 버전: v1.2 · 상태: 합의(v1.2 중복 방지 키는 10/12 회의 확인, PR 리뷰 전) · 사용: PW01WebServer · 담당: Sang-Hyun-Kim · 리뷰: Robbie

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

- `<아이디>`는 **입력 그대로**입니다. 아이디는 대소문자를 구분하므로(`Warrior01`과 `warrior01`은 다른 계정) 소문자로 맞추지 않습니다. 맞추면 서로 다른 계정이 잠김을 같이 씁니다.
- 아이디 형식(영문 대소문자·숫자 4~20자)에 맞지 않는 로그인은 실패 키를 만들지 않습니다(키 길이를 묶음).
- 다른 곳에서 로그인하면 이전 세션 키는 TTL까지 남습니다(이전 기기에 "다른 곳에서 로그인"을 알리려고).
- 크기(Redis 7.4, `MEMORY USAGE`): 세션 키 136바이트, 계정 세션 키 144바이트.
- `pw01:idem`: `<requestId>`는 소문자 UUID입니다. 키에 기능 이름을 넣지 않습니다(10/12 확인). 다른 API에 같은 `requestId`를 쓰면 본문 해시가 달라 409 `IDEMPOTENCY_KEY_REUSED`입니다. 계정 ID를 넣는 것은 남의 `requestId`로 남의 처음 응답을 받지 못하게 하려는 것입니다.
- `pw01:idem`: 본문 해시는 서버가 요청 DTO를 다시 JSON으로 쓴 문자열의 해시입니다(칸 순서·공백이 달라도 같은 요청). 토큰·비밀번호는 값에 넣지 않고, 인증 API에는 쓰지 않습니다.
- `pw01:idem`: 스테이지 플레이 시작·결과 제출에는 쓰지 않습니다. 둘은 DB(시작 `requestId`, 플레이 ID)로 이미 한 번만 반영됩니다.
- 앞으로 더할 키(그 기능에서 이 표에 먼저 적음): 접속 상태·알림 채널, 속도 제한.

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

## 정할 것

| 무엇 | 지금 | 누가 |
|---|---|---|
| 접속 점검 간격, 허용 연속 실패 횟수 | 위 "값의 관계"에 맞춰 | Robbie·Juunnmmoo |
| 키 이름 규칙 | 용도 먼저(`pw01:<용도>:<식별자>`, v1). v0 틀은 도메인 먼저였음 | Sang-Hyun-Kim |
| Redis 클러스터(배포 때) | 세션 스크립트는 키 둘을 함께 다룬다. 클러스터 모드에서는 두 키가 같은 슬롯이어야 하므로 클러스터 모드를 끄거나(복제만) 해시 태그를 쓴다 | Sang-Hyun-Kim(배포 때) |

## 변경 이력

| 버전 | 날짜 | 내용 |
|---|---|---|
| v0 | 2026-09-28 | 문서 틀 생성 |
| v1 | 2026-10-07 | 첫 흐름 키 3개(세션·계정 세션·로그인 실패), Redis 접근 규칙, 설정 값(세션 10분·요청마다 연장, 1분 안에 5번 실패하면 1분 잠김, 모두 설정으로 바꿈), 명령 순서, Lua 4개 |
| v1.1 | 2026-10-07 | 인증 방식 결정 기록 추가(불투명 토큰 + Redis 세션, HandlerInterceptor, 이유·대가·다시 볼 때). 키·스크립트는 바뀌지 않음 |
| v1.2 | 2026-10-12 | 중복 방지 키 `pw01:idem:<계정 ID>:<requestId>`(S3 투자부터), 설정 2개(기억 24시간, 처리 중 30초), 명령 순서, JSON 문자열 값 규칙. 기능 이름 없음·Redis 꺼지면 503·거절은 기억하지 않음(10/12 회의 확인) |
