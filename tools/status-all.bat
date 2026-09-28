@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem ============================================================
rem  세 저장소의 현재 브랜치와 변경 사항을 한 번에 표시 (읽기 전용)
rem  원격과의 앞섬/뒤처짐은 마지막 fetch 기준입니다.
rem ============================================================

for %%I in ("%~dp0..") do set "ROOT=%%~fI"

where git >nul 2>&1
if errorlevel 1 (
  echo [오류] git이 설치되어 있지 않습니다. https://git-scm.com/download/win
  goto :end
)

call :status "%ROOT%" "PW01 - Root"
call :status "%ROOT%\ProjectWarrior" "ProjectWarrior"
call :status "%ROOT%\PW01WebServer" "PW01WebServer"

:end
echo.
if "%~1"=="" pause
exit /b 0

rem ---- 저장소 1개 상태 ----
:status
echo.
echo ===== %~2 =====
if not exist "%~1\.git" (
  echo [없음] git 저장소가 없습니다: %~1
  exit /b 0
)
pushd "%~1"
git status -sb
popd
exit /b 0
