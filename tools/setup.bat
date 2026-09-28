@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem ============================================================
rem  PW01 작업 공간 설정: 게임·웹서버 저장소를 루트 안에 clone
rem  사용법: tools\setup.bat game / web / all   (생략하면 all)
rem  이미 폴더가 있으면 건너뜁니다. 비밀번호·토큰은 묻지 않습니다.
rem ============================================================

set "ORG_URL=https://github.com/NBCGameServerCamp09Team01"
for %%I in ("%~dp0..") do set "ROOT=%%~fI"

set "INTERACTIVE="
if "%~1"=="" set "INTERACTIVE=1"

set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=all"
if /I "%TARGET%"=="game" goto :check
if /I "%TARGET%"=="web" goto :check
if /I "%TARGET%"=="all" goto :check
echo [오류] 인자는 game, web, all 중 하나입니다.
echo 사용법: tools\setup.bat [game^|web^|all]
goto :fail

:check
where git >nul 2>&1
if errorlevel 1 (
  echo [오류] git이 설치되어 있지 않습니다.
  echo        https://git-scm.com/download/win 에서 설치한 뒤 다시 실행하세요.
  goto :fail
)
git lfs version >nul 2>&1
if errorlevel 1 (
  echo [오류] Git LFS가 설치되어 있지 않습니다.
  echo        https://git-lfs.com 에서 설치한 뒤 다시 실행하세요.
  goto :fail
)
git lfs install >nul
if errorlevel 1 (
  echo [오류] git lfs install 실패
  goto :fail
)

echo 작업 공간 루트: %ROOT%
set "FAILED="
if /I "%TARGET%"=="game" call :clone ProjectWarrior
if /I "%TARGET%"=="web" call :clone PW01WebServer
if /I "%TARGET%"=="all" call :clone ProjectWarrior
if /I "%TARGET%"=="all" call :clone PW01WebServer

echo.
if defined FAILED goto :fail
echo 완료. 루트 폴더에서 claude 를 실행해 작업을 시작하세요.
if defined INTERACTIVE pause
exit /b 0

:fail
if defined INTERACTIVE pause
exit /b 1

rem ---- 저장소 1개 clone ----
rem  이미 git 저장소면 건너뜀. 빈 폴더면 그 안에 clone.
rem  원격이 아직 비어 있어도 clone 해 두고, 코드가 올라오면 pull-all.bat 으로 받음.
:clone
echo.
if exist "%ROOT%\%~1\.git" goto :clone_skip_git
if not exist "%ROOT%\%~1\" goto :clone_do
dir /b /a "%ROOT%\%~1" 2>nul | findstr "^" >nul
if not errorlevel 1 goto :clone_skip_dirty

:clone_do
echo [clone] %~1
git clone "%ORG_URL%/%~1.git" "%ROOT%\%~1"
if errorlevel 1 (
  echo [오류] %~1 clone 실패. 저장소 권한과 GitHub 로그인을 확인하세요.
  set "FAILED=1"
  exit /b 0
)
git -C "%ROOT%\%~1" rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 echo [안내] %~1 원격 저장소가 아직 비어 있습니다. 코드가 올라오면 tools\pull-all.bat 으로 받으세요.
exit /b 0

:clone_skip_git
echo [건너뜀] %~1 은 이미 clone 되어 있습니다. 최신 코드는 tools\pull-all.bat 으로 받으세요.
exit /b 0

:clone_skip_dirty
echo [건너뜀] %~1 폴더가 있지만 git 저장소가 아니고 비어 있지도 않습니다. 폴더 내용을 확인하세요.
set "FAILED=1"
exit /b 0
