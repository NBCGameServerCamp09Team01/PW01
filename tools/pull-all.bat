@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem ============================================================
rem  세 저장소(Root, ProjectWarrior, PW01WebServer)를 각 폴더 안에서 pull
rem  fast-forward만 허용합니다. 병합이 필요하면 멈추고 알려 줍니다.
rem ============================================================

for %%I in ("%~dp0..") do set "ROOT=%%~fI"

where git >nul 2>&1
if errorlevel 1 (
  echo [오류] git이 설치되어 있지 않습니다. https://git-scm.com/download/win
  goto :end
)

call :pull "%ROOT%" "PW01 - Root"
call :pull "%ROOT%\ProjectWarrior" "ProjectWarrior"
call :pull "%ROOT%\PW01WebServer" "PW01WebServer"

:end
echo.
if "%~1"=="" pause
exit /b 0

rem ---- 저장소 1개 pull ----
:pull
echo.
echo ===== %~2 =====
if not exist "%~1\.git" (
  echo [건너뜀] git 저장소가 없습니다: %~1
  exit /b 0
)
pushd "%~1"
rem 로컬에 커밋이 없고 원격도 비어 있으면: 아직 코드가 안 올라온 상태
git rev-parse --verify HEAD >nul 2>&1
if not errorlevel 1 goto :pull_do
git ls-remote --heads origin 2>nul | findstr "^" >nul
if not errorlevel 1 goto :pull_do
echo [대기] 원격 저장소가 아직 비어 있거나 연결할 수 없습니다. 코드가 올라온 뒤 다시 실행하세요.
popd
exit /b 0

:pull_do
git pull --ff-only
if errorlevel 1 echo [주의] 자동으로 받을 수 없습니다. 이 폴더에서 git status 로 확인하세요.
popd
exit /b 0
