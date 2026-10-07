# AGENTS.md — PW01 작업 공간 공통 규칙

이 작업 공간에서 일하는 AI 에이전트(Claude Code, Codex 등)가 따르는 규칙입니다. 사람 팀원도 같은 규칙을 따릅니다.

## 1. 구조와 책임

| 폴더 | 저장소 | 책임 |
|---|---|---|
| `.` (Root) | PW01 | 공통 규칙, 공통 문서(`docs/`), 공유 스크립트(`tools/`) |
| `ProjectWarrior/` | ProjectWarrior | Unreal Engine 5.8.3 게임. 코드 소유 팀원(leejunhyeok3907) 담당 |
| `PW01WebServer/` | PW01WebServer | Spring Boot 백엔드 |

- 세 저장소는 서로 독립입니다. Root는 두 폴더를 `.gitignore`로 무시하며 submodule이 아닙니다.
- **하위 폴더에 `AGENTS.md` 또는 `CLAUDE.md`가 있으면, 그 폴더 작업에서는 그 파일이 이 파일보다 우선합니다.** 거기서 다루지 않는 부분은 이 파일을 따릅니다.
- 게임과 웹서버 사이의 약속(API, Redis 키)은 Root `docs/contracts/`가 기준입니다. 한쪽 코드만 바꾸지 말고 명세를 먼저 고칩니다.
- Root 작업 중에 `ProjectWarrior/` 안의 파일을 만들거나 고치지 않습니다. 그 폴더는 담당자가 채웁니다.

## 2. Git

- git 명령은 **대상 파일이 속한 저장소 폴더 안에서만** 실행합니다. 실행 전에 `git rev-parse --show-toplevel`로 어느 저장소인지 확인합니다.
- Root에서 `ProjectWarrior/`, `PW01WebServer/` 파일을 add·commit 하지 않습니다. `git add -f`로 무시 규칙을 우회하지 않습니다.
- `main`·`dev`에 force push 하지 않습니다. 기준 브랜치(Root `main`, 게임·웹서버 `dev`)에 직접 커밋하지 않고, 브랜치 → Pull Request → 리뷰 후 병합합니다. 브랜치·커밋 규칙은 `docs/git-workflow.md`를 따릅니다.
- 사용자가 요청하지 않은 commit·push는 하지 않습니다.
- 히스토리를 바꾸는 명령(`reset --hard`, `rebase`, `push --force`, `clean -fd`)은 사용자 확인 후에만 실행합니다.

## 3. Unreal Engine (ProjectWarrior)

- `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`는 커밋하지 않습니다.
- `.uasset`, `.umap`은 **사람 담당자의 승인 없이 저장·이동·삭제·이름 변경하지 않습니다.** 이진 파일이라 병합이 불가능하고, 충돌하면 한쪽 작업이 사라집니다. 에디터 자동화(MCP 등)를 통한 저장도 포함합니다.
- 맵 1개는 담당자 1명이 수정합니다. 담당이 아닌 맵은 수정하지 않습니다.

## 4. 비밀값

- 비밀번호, 토큰, API 키, 접속 문자열을 코드·문서·커밋 메시지·로그·대화 출력에 남기지 않습니다.
- 비밀값은 환경변수나 `.env` 파일에 둡니다. `.env`와 같은 환경 설정 파일은 각 저장소의 `.gitignore` 대상이며 git으로 동기화하지 않습니다. 커밋할 수 있는 것은 값을 비운 `.env.example`뿐입니다.
- `.env` 내용을 읽거나 출력하지 않습니다.
- 비밀값이 커밋된 것을 발견하면 즉시 사용자에게 알리고, 해당 키를 폐기하라고 요청합니다. 히스토리에서 지우는 것만으로는 부족합니다.

## 5. 확인 후 진행

- 파일 삭제, 대량 변경(여러 파일 이동·이름 변경·일괄 치환), 저장소·브랜치 설정 변경 전에는 사용자에게 무엇을 바꿀지 보여 주고 확인을 받습니다.

## 6. 개인 파일

- `CLAUDE.local.md`, `docs_local/`, `.claude/`(`settings.json` 제외)는 개인용이며 커밋되지 않습니다. 팀이 공유할 규칙은 이 파일이나 `docs/`에 적습니다.

## 7. 구조 참고 문서 (색인)

작업을 시작하기 전에 해당 영역의 문서를 먼저 읽습니다. 내용은 각 문서에 있고, 여기에는 위치와 요약만 둡니다.

| 영역 | 위치 | 요약 |
|---|---|---|
| 작업 공간 전체 | `docs/overview.md` | 구성 요소(게임 클라이언트·웹서버·MySQL·Redis)와 요청 흐름 |
| Git 규칙 | `docs/git-workflow.md` | 저장소별 기준 브랜치(Root `main`, 게임·웹서버 `dev`), 브랜치 이름, 커밋·PR 형식 |
| 게임 ↔ 웹서버 약속 | `docs/contracts/README.md` | 명세 목록, 공통 API 규칙(경로는 기능 이름부터·버전 없음, 시각 UTC, 오류 응답 형식, 모르는 필드), 변경 절차 |
| 웹서버 작업 규칙 | `PW01WebServer/AGENTS.md` | 웹서버 폴더 작업에서 이 파일보다 우선. 3계층·DTO·오류·테스트·Git(AI) 규칙 |
| 웹서버 처음 받기 | `PW01WebServer/README.md` | 준비물, 받기, `.env`, compose, 실행 구성, 빌드 |
| 웹서버 세팅 명세 | `PW01WebServer/docs/initial-setup.md` | 파일·의존성·설정 키·기동 순서·오류 흐름·테스트·CI 각각의 역할 |
| 웹서버 구조 요약 | `PW01WebServer/docs/overview.md` | 패키지, 프로필, 환경 변수 표 |
| 웹서버 새 API 견본 | `PW01WebServer/docs/guides/example-api.md` | Controller → Service → Repository → DB를 따라가기, 파트별 따라 하기 |
| 웹서버 결정·문제 기록 | `PW01WebServer/docs/decisions/`, `PW01WebServer/docs/troubleshooting/` | 초기 설정 결정(W01~W39)과 근거, 겪은 문제와 해결 |
| 게임(UE) | `ProjectWarrior/` | 구조 문서 없음(담당자가 채움). 그 폴더에 `AGENTS.md`·`CLAUDE.md`가 생기면 그것을 따름 |

- 웹서버 문서는 PW01WebServer의 `dev` 브랜치 기준입니다.
- 문서를 새로 만들거나 옮기면 이 표도 함께 고칩니다.
