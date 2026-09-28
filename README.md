# PW01 작업 공간

NBCGameServerCamp09Team01 팀 게임 프로젝트의 **작업 공간 루트**입니다.
이 저장소(PW01)에는 공통 규칙, 공통 문서, 공유 스크립트만 들어 있습니다. 게임과 웹서버는 안쪽 폴더에 **각각 별도 git 저장소**로 둡니다.

## 구조

```
PW01/                          ← Root 저장소 (PW01)
├─ README.md                   ← 이 파일
├─ AGENTS.md                   ← AI 에이전트 공통 규칙
├─ CLAUDE.md                   ← @AGENTS.md (Claude Code용 import)
├─ .mcp.json                   ← MCP 서버 설정 (Unreal 에디터 내장 MCP 서버)
├─ .claude/settings.json       ← Claude Code 공유 설정 (나머지 .claude/ 는 개인, 무시)
├─ CLAUDE.local.md             ← 개인 메모 (커밋 안 됨)
├─ docs/                       ← 팀 공통 문서
│   ├─ README.md               ← 문서 지도
│   ├─ overview.md             ← 시스템 전체 구조
│   ├─ git-workflow.md         ← 브랜치·커밋·LFS 규칙
│   └─ contracts/              ← 게임 ↔ 웹서버 명세 (API, Redis 키)
├─ docs_local/                 ← 개인 문서 (커밋 안 됨)
├─ tools/                      ← 공유 스크립트 (setup / pull-all / status-all)
├─ ProjectWarrior/             ← 별도 저장소: UE 5.8.3 게임 (Root는 무시)
└─ PW01WebServer/              ← 별도 저장소: Spring Boot 백엔드 (Root는 무시)
```

| 폴더 | GitHub 저장소 | 담당 |
|---|---|---|
| `PW01\` (Root) | https://github.com/NBCGameServerCamp09Team01/PW01 | 팀 공통 |
| `ProjectWarrior\` | https://github.com/NBCGameServerCamp09Team01/ProjectWarrior | 코드 소유 팀원 (leejunhyeok3907) |
| `PW01WebServer\` | https://github.com/NBCGameServerCamp09Team01/PW01WebServer | 백엔드 담당 |

Root는 `ProjectWarrior/`, `PW01WebServer/` 를 `.gitignore`로 무시합니다. submodule이 아닙니다.

### 게임 코드가 들어오는 흐름

1. 각자 `tools\setup.bat` 으로 ProjectWarrior를 clone 합니다. 원격이 아직 비어 있어도 빈 저장소로 clone 됩니다.
2. 코드 소유 팀원이 ProjectWarrior 저장소에 UE 프로젝트를 push 합니다.
3. 나머지는 `tools\pull-all.bat` (또는 `ProjectWarrior\` 안에서 `git pull`) 으로 받습니다.

`ProjectWarrior\` 폴더를 미리 만들 필요는 없습니다. clone 이 만듭니다. 빈 폴더를 미리 만들어 두었어도 그 안에 clone 됩니다.

## MCP 설정 (`.mcp.json`)

UE 5.8 내장 `ModelContextProtocol` 플러그인의 서버(`unreal-mcp`, `http://127.0.0.1:8000/mcp`)에 연결합니다. `ProjectWarrior/.mcp.json` 과 같은 값이며, 에디터 설정(포트 8000, 경로 `/mcp`)을 바꾸면 두 파일을 함께 고칩니다. 루트에서 `claude` 를 실행하면 이 파일이 쓰입니다.

- Unreal 에디터가 켜져 있고 MCP 서버가 떠 있어야 연결됩니다. 안 뜨면 에디터 콘솔에서 `ModelContextProtocol.StartServer` 를 실행합니다.
- 처음 실행할 때 Claude Code가 이 서버를 쓸지 묻습니다. 승인하면 됩니다. 접속 키 같은 비밀값은 이 파일에 적지 않고 환경변수로 넘깁니다.

## 가장 중요한 규칙: git은 각 폴더 안에서

```
PW01\                 → Root 문서·규칙만 커밋
PW01\ProjectWarrior\  → 게임 파일은 여기서 git
PW01\PW01WebServer\   → 웹서버 파일은 여기서 git
```

지금 어느 저장소에 있는지 헷갈리면 `git rev-parse --show-toplevel` 로 확인하세요.
세 저장소를 한 번에 보려면 `tools\status-all.bat`, 한 번에 받으려면 `tools\pull-all.bat` 를 씁니다.

## 역할별 시작 순서

### 1) 소유자 (Organization 관리자)

1. GitHub에 저장소 3개 생성 — 완료
2. Root·웹서버 초기 파일 push — 1회만 (명령은 소유자가 따로 보관)
3. `tools\setup.bat game` 으로 ProjectWarrior를 빈 저장소로 clone 해 두고, 코드가 올라오면 `tools\pull-all.bat`
4. 세 저장소 모두 `main` 브랜치 보호 설정
   Settings → Branches(또는 Rules) → `main`: Pull Request 필수, force push 금지, 삭제 금지
5. 팀원 초대와 저장소 권한 부여
6. Git LFS 사용량 확인: Organization Settings → Billing (게임 저장소가 커서 한도를 넘을 수 있음)

### 2) 코드 소유 팀원 (ProjectWarrior 담당)

1. Root 받기
   ```bat
   git clone https://github.com/NBCGameServerCamp09Team01/PW01.git
   ```
2. UE 프로젝트를 `PW01\ProjectWarrior\` 에 둡니다.
   - 이미 ProjectWarrior 저장소를 쓰고 있다면 그 폴더를 옮기거나, `PW01\` 안에서 `git clone https://github.com/NBCGameServerCamp09Team01/ProjectWarrior.git` 합니다.
3. `.gitignore`, `.gitattributes`(LFS 추적 설정)는 ProjectWarrior 저장소가 직접 관리합니다.
4. 아래 "ProjectWarrior 담당자에게 요청할 것"을 검토합니다.

### 3) 다른 팀원

1. Root를 받고 `tools\setup.bat` 을 실행합니다.
   ```bat
   git clone https://github.com/NBCGameServerCamp09Team01/PW01.git
   cd PW01
   tools\setup.bat
   ```
   - 게임만 받으려면 `tools\setup.bat game`, 웹서버만 받으려면 `tools\setup.bat web`
   - 스크립트 없이 받으려면 `PW01\` 안에서:
     ```bat
     git clone https://github.com/NBCGameServerCamp09Team01/ProjectWarrior.git
     git clone https://github.com/NBCGameServerCamp09Team01/PW01WebServer.git
     ```
2. 루트(`PW01\`)에서 `claude` 를 실행합니다.
   - 루트의 `CLAUDE.md` → `AGENTS.md` 가 먼저 읽히고, 하위 폴더 작업 때는 그 폴더의 `CLAUDE.md` 가 추가로 적용됩니다.
3. 작업 전에 [docs/git-workflow.md](docs/git-workflow.md) 를 읽습니다.

필요한 것: [Git for Windows](https://git-scm.com/download/win), [Git LFS](https://git-lfs.com) (게임 저장소), Unreal Engine 5.8.3 런처 버전 (게임 작업 시)

## ProjectWarrior 담당자에게 요청할 것 (선택, 담당자 판단)

Root에서는 ProjectWarrior 안에 파일을 만들지 않습니다. 필요하면 담당자가 직접 추가합니다.

- `CLAUDE.md` (또는 `AGENTS.md`): UE 작업 규칙 (에셋 저장 승인, 빌드 방법 등)
- `.github/pull_request_template.md`: PR 체크리스트 (수정한 맵·에셋 목록, 에디터에서 열어 확인했는지)
- `docs/`: 게임 쪽 문서 (Root `docs/` 와 같은 뼈대: `README.md` 문서 지도, `overview.md` 구조)
- `.gitignore`에 `Binaries/ Intermediate/ Saved/ DerivedDataCache/` 포함 여부
- `.gitattributes`에 `*.uasset`, `*.umap` LFS 추적 (필요하면 `lockable`) 설정 여부

## 개인 파일

- `CLAUDE.local.md`, `docs_local/`, `.claude/`(settings.json 제외)는 커밋되지 않습니다. 개인 메모는 여기에 두세요.
- `.env` 같은 환경 설정 파일도 커밋되지 않습니다. 비밀값은 저장소에 올리지 않습니다.
