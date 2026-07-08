@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

set SOURCE_DIR=D:\Github\es-de
set ADB=C:\platform-tools\adb.exe
set IMAGE_NAME=es-de-builder
set GRADLE_VOLUME=es-de-gradle-cache
set PKG=org.es_de.frontend

set APK_BUILD=%SOURCE_DIR%\docker\ES-DE_Dec_3.4.1.apk

set RELEASE_DIR=%SOURCE_DIR%\release
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyMMdd"') do set DATE=%%i
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"
set APK_OUT=%RELEASE_DIR%\ES-DE+a_android_%DATE%.apk

if not exist "%ADB%" set ADB=adb

cd /d "%SOURCE_DIR%"

echo.
echo ========================================
echo   ES-DE+a Android Builder
echo ========================================
echo.
echo   1) Build only              (default)
echo   2) Build + Install + Run
echo   3) Install + Run only      (use last APK)
echo   4) Quick build --only 5,6  (Kotlin/res/Gradle)
echo   5) Rebuild Docker image + full build
echo   6) Clean build + Install   (nuke android/ + Gradle cache + bundled APK)
echo.
set /p CHOICE=Select (1~6, default 1): 
if "%CHOICE%"=="" set CHOICE=1

if "%CHOICE%"=="3" goto :install

if "%CHOICE%"=="6" (
    echo [INFO] Clean build: removing all build artifacts...

    REM 1) Gradle 캐시 볼륨 제거 (모듈 메타데이터까지 초기화)
    docker volume rm %GRADLE_VOLUME% > nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK]  Gradle cache volume removed
    ) else (
        echo [OK]  Gradle cache volume did not exist
    )

    REM 2) android/ 폴더 제거
    if exist "%SOURCE_DIR%\android" (
        rmdir /s /q "%SOURCE_DIR%\android"
        echo [OK]  android/ deleted
    ) else (
        echo [OK]  android/ already clean
    )

    REM 3) 번들된 APK 제거 (재추출 강제)
    if exist "%APK_BUILD%" (
        del /q "%APK_BUILD%"
        echo [OK]  bundled APK deleted
    ) else (
        echo [OK]  bundled APK already absent
    )
)

docker image inspect %IMAGE_NAME% > nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Docker image not found. Building now...
    goto :build_image
)

if "%CHOICE%"=="5" (
    echo [INFO] Removing Docker image for rebuild...
    docker rmi %IMAGE_NAME%
    goto :build_image
)

echo [OK] Docker image found
goto :build_apk

:build_image
echo.
echo --- Building Docker image ---
docker build -t %IMAGE_NAME% -f docker\Dockerfile docker\
if %errorlevel% neq 0 (
    echo [ERR] Docker image build failed
    goto :end
)
echo [OK] Docker image built

:build_apk
echo.
echo --- Building APK ---

if "%CHOICE%"=="4" (
    python docker\build_android.py --no-install --only 5,6
) else (
    python docker\build_android.py --no-install
)

if %errorlevel% neq 0 (
    echo [ERR] APK build failed
    goto :end
)

if not exist "%APK_BUILD%" (
    echo [ERR] APK not found: %APK_BUILD%
    goto :end
)

copy /Y "%APK_BUILD%" "%APK_OUT%"
if %errorlevel% neq 0 (
    echo [ERR] Copy to release folder failed
    goto :end
)
echo [OK] Build done: %APK_OUT%

if "%CHOICE%"=="1" goto :end
if "%CHOICE%"=="4" goto :end
if "%CHOICE%"=="5" goto :end

:install
if "%CHOICE%"=="3" (
    for /f "delims=" %%f in ('dir /b /o-d "%RELEASE_DIR%\ES-DE+a_android_*.apk" 2^>nul') do (
        set APK_OUT=%RELEASE_DIR%\%%f
        goto :do_install
    )
    echo [ERR] No APK in release folder. Build first.
    goto :end
)

:do_install
echo.
echo --- Installing to device ---
echo   APK: %APK_OUT%

%ADB% devices 2>nul | findstr /r "device$" > nul
if %errorlevel% neq 0 (
    echo [WARN] No Android device connected.
    goto :end
)

echo   Uninstalling old version...
%ADB% uninstall %PKG% > nul 2>&1

echo   Clearing app data...
%ADB% shell "rm -rf /sdcard/Android/data/%PKG%/ /sdcard/ES-DE/" > nul 2>&1

echo   Installing APK...
%ADB% install --no-incremental "%APK_OUT%"
if %errorlevel% neq 0 (
    echo [ERR] Install failed
    goto :end
)
echo [OK] Install complete

%ADB% logcat -c > nul 2>&1
echo   Launching app...
%ADB% shell am start -n %PKG%/.MainActivity > nul 2>&1

echo.
echo === Done! ===

:end
echo.
pause
