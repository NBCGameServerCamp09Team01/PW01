# Git 작업 규칙

세 저장소(PW01, ProjectWarrior, PW01WebServer) 모두 같은 규칙을 씁니다. **git 명령은 항상 해당 저장소 폴더 안에서** 실행합니다.

## 작업 순서: pull → 작업 → push

```bat
:: 0. 작업할 저장소 폴더로 이동
cd PW01\PW01WebServer

:: 1. 최신 받기
git switch main
git pull --ff-only

:: 2. 브랜치 만들기
git switch -c feat/login-api

:: 3. 작업하고 확인한 뒤 커밋
git add <파일>
git commit -m "feat: 로그인 API 추가"

:: 4. push
git push -u origin feat/login-api

:: 5. GitHub에서 Pull Request 생성 → 리뷰 → 병합
```

- 세 저장소를 한 번에 최신으로 받으려면 루트에서 `tools\pull-all.bat` 를 실행합니다.
- 작업 시작 전과 PR 올리기 전에 한 번씩 pull 합니다. 오래 묵힌 브랜치일수록 충돌이 커집니다.
- `main`에는 직접 커밋·push 하지 않습니다. force push는 금지입니다.

## 브랜치 이름

| 접두어 | 용도 | 예 |
|---|---|---|
| `feat/` | 새 기능 (코드) | `feat/ds-register` |
| `fix/` | 버그 수정 | `fix/result-null-check` |
| `content/` | 맵·에셋·데이터 등 콘텐츠 작업 | `content/map-forest-lighting` |

- 소문자와 `-`만 씁니다. 이슈 번호가 있으면 앞에 붙입니다: `feat/12-ds-register`
- 문서만 고칠 때는 `docs/` 접두어도 씁니다: `docs/result-api-v1`

## 커밋 메시지

```
<type>: <무엇을 했는지 한 줄 요약>

(선택) 왜 바꿨는지, 참고 사항
```

- type: `feat`, `fix`, `content`, `docs`, `refactor`, `test`, `chore`
- 요약은 한국어로 50자 안쪽, 마침표 없이 씁니다.
- 예: `fix: DS 재등록 시 중복 키 생성 문제 수정`
- 한 커밋에는 한 가지 목적만 담습니다.

## Git LFS 주의사항 (ProjectWarrior)

- 처음 한 번 `git lfs install` 을 실행합니다 (`tools\setup.bat` 이 대신 실행).
- `.uasset`, `.umap` 등 이진 파일은 LFS로 올라가야 합니다. 어떤 파일을 LFS로 추적할지는 ProjectWarrior의 `.gitattributes`가 정하며, 코드 소유 팀원이 관리합니다.
- 커밋 전에 `git lfs status` 로 이진 파일이 LFS 대상인지 확인합니다. LFS 없이 큰 파일이 커밋되면 저장소가 커지고 되돌리기 어렵습니다.
- 이진 파일은 병합이 안 됩니다. 같은 파일을 두 사람이 동시에 고치면 한쪽 작업이 사라집니다. 수정 전에 담당자와 먼저 이야기합니다.
- GitHub LFS에는 저장 용량·전송량 한도가 있습니다. 불필요한 대용량 파일을 여러 번 커밋하지 않습니다.
- `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/` 는 커밋하지 않습니다.

## 맵 1개 = 담당 1명

- 맵(`.umap`)마다 담당자를 1명 정합니다. 담당자만 그 맵을 저장합니다.
- 다른 사람 맵에 무언가 필요하면 담당자에게 요청하거나, 담당을 넘겨받은 뒤 작업합니다.
- 담당 목록은 ProjectWarrior 쪽 문서에서 관리합니다 (담당자가 위치 결정).

## Pull Request

- 제목은 커밋 메시지 형식을 따릅니다.
- 본문에 무엇을 바꿨는지, 어떻게 확인했는지 적습니다. 콘텐츠 PR은 수정한 맵·에셋 목록을 적습니다.
- `docs/contracts/` 명세를 바꾸는 PR은 게임·웹서버 담당자 모두에게 리뷰를 요청합니다.
