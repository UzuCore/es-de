@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM =============================================================================
REM  build_android.bat
REM  ES-DE Android APK 빌드 + 자동 설치/실행
REM
REM  사전 조건:
REM    - Docker Desktop 설치 및 실행 중
REM    - platform-tools (adb.exe) 설치
REM    - docker\ 폴더에 Dockerfile, build.sh, ES-DE_3.4.1-58.apk 존재
REM =============================================================================

set SOURCE_DIR=D:\Github\es-de
set RELEASE_DIR=%SOURCE_DIR%\release
set ADB=C:\platform-tools\adb.exe
set APK_BUILD=%SOURCE_DIR%\ES-DE_UzuCore_3.4.1.apk
set IMAGE_NAME=es-de-builder
set PKG=org.es_de.frontend

REM 날짜 기반 최종 APK 경로
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyMMdd"') do set DATE=%%i
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"
set APK_OUT=%RELEASE_DIR%\ES-DE_android_%DATE%.apk

REM adb 경로 확인
if not exist "%ADB%" (
    echo [WARN] adb.exe not found at %ADB%
    echo        설치 후 이 파일 상단의 ADB 경로를 수정하세요.
    set ADB=adb
)

cd /d "%SOURCE_DIR%"

REM =============================================================================
REM 옵션 선택
REM =============================================================================
echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo   ES-DE Android Builder
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.
echo   1) 빌드 + 설치 + 실행  (기본)
echo   2) 빌드만
echo   3) 설치 + 실행만  (이전 빌드 APK 사용)
echo   4) Docker 이미지 재빌드 후 전체 빌드
echo.
set /p CHOICE=선택 (1/2/3/4, 기본 1): 
if "%CHOICE%"=="" set CHOICE=1

REM =============================================================================
REM Docker 이미지 확인
REM =============================================================================
if "%CHOICE%"=="3" goto :install

docker image inspect %IMAGE_NAME% > nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [INFO] Docker 이미지가 없습니다. 최초 빌드 시작 (~25분)...
    goto :build_image
)

if "%CHOICE%"=="4" (
    echo.
    echo [INFO] Docker 이미지 삭제 후 재빌드...
    docker rmi %IMAGE_NAME%
    goto :build_image
)

echo [OK] Docker 이미지 존재
goto :build_apk

:build_image
echo.
echo ━━━ Docker 이미지 빌드 중... ━━━
docker build -t %IMAGE_NAME% -f docker\Dockerfile docker\
if %errorlevel% neq 0 (
    echo [ERR] Docker 이미지 빌드 실패
    goto :end
)
echo [OK] Docker 이미지 빌드 완료

REM =============================================================================
REM APK 빌드
REM =============================================================================
:build_apk
echo.
echo ━━━ APK 빌드 중... ━━━

docker run --rm ^
    -v "%SOURCE_DIR%:/workspace" ^
    -v "%SOURCE_DIR%\docker\build.sh:/usr/local/bin/build.sh:ro" ^
    -v "%SOURCE_DIR%\docker\generate_android_project.py:/usr/local/bin/generate_android_project.py:ro" ^
    -v "%SOURCE_DIR%\docker\platform_util_android.cpp:/opt/prebuilt/platform_util_android.cpp:ro" ^
    -v "%SOURCE_DIR%\docker\platform_util_android.h:/opt/prebuilt/platform_util_android.h:ro" ^
    -v "%SOURCE_DIR%\docker\input_overlay.cpp:/opt/prebuilt/input_overlay.cpp:ro" ^
    -v "%SOURCE_DIR%\docker\input_overlay.h:/opt/prebuilt/input_overlay.h:ro" ^
    -v "es-de-gradle-cache:/root/.gradle" ^
    %IMAGE_NAME%

if %errorlevel% neq 0 (
    echo [ERR] APK 빌드 실패
    goto :end
)

if not exist "%APK_BUILD%" (
    echo [ERR] APK 파일이 생성되지 않았습니다.
    goto :end
)

REM release 폴더로 이동
move /Y "%APK_BUILD%" "%APK_OUT%" > nul
echo [OK] 빌드 완료: %APK_OUT%

if "%CHOICE%"=="2" goto :end

REM =============================================================================
REM 설치 + 실행
REM =============================================================================
:install
echo.
echo ━━━ 폰에 설치 중... ━━━

REM 기기 연결 확인
%ADB% devices 2>nul | findstr /r "device$" > nul
if %errorlevel% neq 0 (
    echo [WARN] 연결된 Android 기기가 없습니다.
    echo        USB 디버깅이 켜져 있는지 확인하세요.
    goto :end
)

REM 기존 앱 제거
echo   기존 앱 제거...
%ADB% uninstall %PKG% > nul 2>&1

REM 앱 데이터 초기화
echo   앱 데이터 초기화...
%ADB% shell "rm -rf /sdcard/Android/data/%PKG%/ /sdcard/ES-DE/" > nul 2>&1

REM APK 설치
echo   APK 설치 중...
%ADB% install --no-incremental "%APK_OUT%"
if %errorlevel% neq 0 (
    echo [ERR] 설치 실패
    goto :end
)
echo [OK] 설치 완료

REM 실행
%ADB% logcat -c > nul 2>&1
echo   앱 실행 중...
%ADB% shell am start -n %PKG%/.MainActivity > nul 2>&1

echo.
echo ━━━ 완료! ━━━
echo.
echo   유용한 명령어:
echo     빌드만:        선택 2
echo     설치만:        선택 3
echo     이미지 재빌드: 선택 4

:end
echo.
echo 아무 키나 누르면 종료...
pause > nul
