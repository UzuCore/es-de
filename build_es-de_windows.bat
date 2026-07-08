@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

set SOURCE_DIR=D:\Github\es-de
set RELEASE_DIR=%SOURCE_DIR%\release
set VS_DEV_CMD=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat
set SEVENZIP=C:\Program Files\7-Zip\7z.exe

set CL=/utf-8

if not exist "%VS_DEV_CMD%" (
    echo Visual Studio Developer Command not found at:
    echo   %VS_DEV_CMD%
    echo Please edit VS_DEV_CMD path in this script.
    goto :end
)

if not exist "%SEVENZIP%" (
    echo 7-Zip not found at:
    echo   %SEVENZIP%
    echo Please install 7-Zip or edit SEVENZIP path in this script.
    goto :end
)

call "%VS_DEV_CMD%" -arch=x64 -host_arch=x64 > nul
if %errorlevel% neq 0 (
    echo Failed to initialize Visual Studio environment.
    goto :end
)

cd /d "%SOURCE_DIR%"

set /p CLEAN=Clean build? (y/N): 
if /i "%CLEAN%"=="Y" (
    echo Removing build artifacts...
    del /q CMakeCache.txt 2> nul
    rmdir /s /q CMakeFiles 2> nul
    if exist Makefile del /q Makefile
    for /d %%d in (es-app es-core es-pdf-converter es-core-suspend) do (
        if exist "%%d\CMakeFiles" rmdir /s /q "%%d\CMakeFiles"
    )
)

REM ==========================================================
REM [1/6] 의존성 통합 점검
REM   폴더 존재 여부가 아니라 폴더 안의 핵심 파일 존재 여부로 판정
REM ==========================================================
echo [1/6] Check dependencies...

REM (1) setup.bat 산출물 확인 - 각 라이브러리의 핵심 파일(소스 또는 다운로드 산출물) 체크
set SETUP_OK=1
if not exist "external\pugixml\CMakeLists.txt"          set SETUP_OK=0
if not exist "external\harfbuzz\CMakeLists.txt"         set SETUP_OK=0
if not exist "external\harfbuzz\build\"                 set SETUP_OK=0
if not exist "external\freetype\CMakeLists.txt"         set SETUP_OK=0
if not exist "external\freetype\build\"                 set SETUP_OK=0
if not exist "external\libgit2\CMakeLists.txt"          set SETUP_OK=0
if not exist "external\libgit2\build\"                  set SETUP_OK=0
if not exist "external\icu\icu4c\source\icu_filters.json" set SETUP_OK=0
if not exist "external\curl\bin\libcurl-x64.dll"        set SETUP_OK=0
if not exist "external\SDL2\lib\x64\SDL2.lib"           set SETUP_OK=0
if not exist "external\ffmpeg\bin\avcodec-61.dll"       set SETUP_OK=0
if not exist "external\glew\lib\Release\x64\glew32.lib" set SETUP_OK=0
if not exist "external\FreeImage\Dist\x64\FreeImage.lib" set SETUP_OK=0
if not exist "external\gettext\bin\libintl-8.dll"       set SETUP_OK=0

REM (2) setup.bat 가 루트로 복사한 라이브러리 파일 확인
set ROOT_LIBS_OK=1
if not exist "libcurl-x64.lib"    set ROOT_LIBS_OK=0
if not exist "libcurl-x64.dll"    set ROOT_LIBS_OK=0
if not exist "SDL2.lib"           set ROOT_LIBS_OK=0
if not exist "SDL2.dll"           set ROOT_LIBS_OK=0
if not exist "FreeImage.lib"      set ROOT_LIBS_OK=0
if not exist "FreeImage.dll"      set ROOT_LIBS_OK=0
if not exist "glew32.lib"         set ROOT_LIBS_OK=0
if not exist "glew32.dll"         set ROOT_LIBS_OK=0
if not exist "avcodec.lib"        set ROOT_LIBS_OK=0
if not exist "avformat.lib"       set ROOT_LIBS_OK=0
if not exist "avutil.lib"         set ROOT_LIBS_OK=0
if not exist "libintl-8.lib"      set ROOT_LIBS_OK=0

REM (3) build.bat 산출물(컴파일된 라이브러리) 확인
set DEPS_BUILT=1
if not exist "external\icu\icu4c\bin64\icudt77.dll" set DEPS_BUILT=0
if not exist "external\harfbuzz\build\harfbuzz.lib" set DEPS_BUILT=0
if not exist "external\freetype\build\freetype.lib" set DEPS_BUILT=0
if not exist "external\libgit2\build\git2.dll"      set DEPS_BUILT=0
if not exist "external\pugixml\pugixml.dll"         set DEPS_BUILT=0

REM --- 자동 복구: setup ---
if !SETUP_OK!==0 (
    echo   [!] External sources are missing or incomplete. Running setup...
    echo       Cleaning incomplete external folders first...

    REM 빈 폴더나 불완전한 폴더 제거 (setup.bat 가 깨끗한 상태에서 시작하도록)
    if exist "external\pugixml"  rmdir /S /Q "external\pugixml"
    if exist "external\harfbuzz" rmdir /S /Q "external\harfbuzz"
    if exist "external\freetype" rmdir /S /Q "external\freetype"
    if exist "external\libgit2"  rmdir /S /Q "external\libgit2"
    if exist "external\icu"      rmdir /S /Q "external\icu"
    if exist "external\curl"     rmdir /S /Q "external\curl"
    if exist "external\SDL2"     rmdir /S /Q "external\SDL2"
    if exist "external\ffmpeg"   rmdir /S /Q "external\ffmpeg"
    if exist "external\glew"     rmdir /S /Q "external\glew"
    if exist "external\FreeImage" rmdir /S /Q "external\FreeImage"
    if exist "external\gettext"  rmdir /S /Q "external\gettext"

    echo       This downloads source code and may take several minutes.
    call tools\Windows_dependencies_setup.bat
    if !errorlevel! neq 0 ( echo Setup FAILED & goto :end )
    echo   [+] Setup complete.

    REM setup 후엔 컴파일도 다시 필요함
    set DEPS_BUILT=0
) else if !ROOT_LIBS_OK!==0 (
    echo   [!] Root-level libs missing ^(setup was incomplete^). Re-running setup...
    call tools\Windows_dependencies_setup.bat
    if !errorlevel! neq 0 ( echo Setup FAILED & goto :end )
    echo   [+] Setup complete.
    set DEPS_BUILT=0
) else (
    echo   [+] External sources OK.
)

REM --- 자동 복구: dependency build ---
if !DEPS_BUILT!==0 (
    echo   [!] Compiled libs missing. Building dependencies...
    echo       This may take 30-60 minutes.
    call tools\Windows_dependencies_build.bat
    if !errorlevel! neq 0 ( echo Dependency build FAILED & goto :end )

    REM build.bat 결과 재검증
    set DEPS_BUILT=1
    if not exist "external\icu\icu4c\bin64\icudt77.dll" set DEPS_BUILT=0
    if not exist "external\harfbuzz\build\harfbuzz.lib" set DEPS_BUILT=0
    if not exist "external\freetype\build\freetype.lib" set DEPS_BUILT=0
    if not exist "external\libgit2\build\git2.dll"      set DEPS_BUILT=0
    if not exist "external\pugixml\pugixml.dll"         set DEPS_BUILT=0
    if !DEPS_BUILT!==0 (
        echo   [X] Dependency build finished but some outputs are still missing:
        if not exist "external\icu\icu4c\bin64\icudt77.dll" echo       - external\icu\icu4c\bin64\icudt77.dll
        if not exist "external\harfbuzz\build\harfbuzz.lib" echo       - external\harfbuzz\build\harfbuzz.lib
        if not exist "external\freetype\build\freetype.lib" echo       - external\freetype\build\freetype.lib
        if not exist "external\libgit2\build\git2.dll"      echo       - external\libgit2\build\git2.dll
        if not exist "external\pugixml\pugixml.dll"         echo       - external\pugixml\pugixml.dll
        goto :end
    )
    echo   [+] Dependencies built.
) else (
    echo   [+] Compiled libs OK.
)

REM Poppler 별도 체크
if not exist "external\poppler\Library\include\poppler\cpp\poppler-document.h" (
    echo   [!] Poppler not found. Downloading...
    cd external

    if exist poppler-24.08.0 rmdir /S /Q poppler-24.08.0
    if exist poppler rmdir /S /Q poppler
    if exist Release-24.08.0-0.zip del Release-24.08.0-0.zip

    curl -LO https://github.com/oschwartz10612/poppler-windows/releases/download/v24.08.0-0/Release-24.08.0-0.zip
    if not exist Release-24.08.0-0.zip ( echo Poppler download FAILED & cd .. & goto :end )

    "%SEVENZIP%" x Release-24.08.0-0.zip > nul
    if not exist poppler-24.08.0\Library\ (
        echo Poppler extraction FAILED
        cd ..
        goto :end
    )

    rename poppler-24.08.0 poppler

    copy /Y poppler\Library\lib\poppler-cpp.lib ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\charset.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\deflate.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\freetype.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\iconv.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\jpeg8.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\lcms2.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\Lerc.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\libcrypto-3-x64.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\libcurl.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\liblzma.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\libpng16.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\libssh2.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\openjp2.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\poppler.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\poppler-cpp.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\tiff.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\zlib.dll ..\es-pdf-converter\ > nul
    copy /Y poppler\Library\bin\zstd.dll ..\es-pdf-converter\ > nul

    cd ..
    echo   [+] Poppler OK.
) else (
    echo   [+] Poppler OK.
)

echo [2/6] Select build type:
echo   1) Release  - Optimized build (default)
echo   2) Debug    - Debug build with symbols
set /p BUILD_TYPE=Select (1/2, default 1): 

if "%BUILD_TYPE%"=="2" (
    set CMAKE_BUILD_TYPE=Debug
    set BUILD_LABEL=debug
) else (
    set CMAKE_BUILD_TYPE=Release
    set BUILD_LABEL=release
)

if not exist "CMakeCache.txt" (
    echo [3/6] Running CMake configuration...
    cmake -G "NMake Makefiles JOM" -DCMAKE_BUILD_TYPE=!CMAKE_BUILD_TYPE! .
    if !errorlevel! neq 0 ( echo CMake FAILED & goto :end )
) else (
    echo [3/6] CMake cache exists, skipping configuration.
)

echo [4/6] Building with jom...
jom -j%NUMBER_OF_PROCESSORS%
if %errorlevel% neq 0 ( echo Build FAILED & goto :end )

echo [5/6] Packaging ES-DE...
if not exist "ES-DE.exe" (
    echo ES-DE.exe not found after build.
    goto :end
)

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyMMdd"') do set BUILD_DATE=%%i

set PACKAGE_NAME=ES-DE+a_windows_%BUILD_DATE%
set PACKAGE_DIR=%RELEASE_DIR%\%PACKAGE_NAME%
set ZIP_FILE=%RELEASE_DIR%\%PACKAGE_NAME%.zip

if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"
if exist "%PACKAGE_DIR%" rmdir /s /q "%PACKAGE_DIR%"
if exist "%ZIP_FILE%" del /q "%ZIP_FILE%"
mkdir "%PACKAGE_DIR%"

echo Copying exe and dlls...
copy "ES-DE.exe" "%PACKAGE_DIR%\" > nul
copy "*.dll" "%PACKAGE_DIR%\" > nul 2>&1

echo Copying resource folders...
if exist "resources" xcopy /e /i /q /y "resources" "%PACKAGE_DIR%\resources" > nul
if exist "themes" xcopy /e /i /q /y "themes" "%PACKAGE_DIR%\themes" > nul
if exist "licenses" xcopy /e /i /q /y "licenses" "%PACKAGE_DIR%\licenses" > nul
if exist "locale" xcopy /e /i /q /y "locale" "%PACKAGE_DIR%\locale" > nul
if exist "es-pdf-converter\es-pdf-convert.exe" copy "es-pdf-converter\es-pdf-convert.exe" "%PACKAGE_DIR%\" > nul

echo Copying es-pdf-converter dlls...
if exist "es-pdf-converter\poppler-cpp.dll" copy "es-pdf-converter\poppler-cpp.dll" "%PACKAGE_DIR%\" > nul
if exist "es-pdf-converter\poppler.dll" copy "es-pdf-converter\poppler.dll" "%PACKAGE_DIR%\" > nul

echo Creating user directories...
mkdir "%PACKAGE_DIR%\Emulators" 2> nul
mkdir "%PACKAGE_DIR%\ROMs" 2> nul

echo [6/6] Creating zip archive with 7-Zip...
"%SEVENZIP%" a -tzip -mx10 "%ZIP_FILE%" "%PACKAGE_DIR%\*" > nul
if %errorlevel% neq 0 ( echo Zip FAILED & goto :end )

echo.
echo Done!
echo   Folder: %PACKAGE_DIR%
echo   Zip:    %ZIP_FILE%
echo.

set /p RUN=Run ES-DE.exe now? (y/N): 
if /i "%RUN%"=="Y" (
    start "" "%PACKAGE_DIR%\ES-DE.exe"
)

:end
echo.
echo Press any key to exit...
pause > nul
