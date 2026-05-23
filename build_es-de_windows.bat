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

    echo.
    echo [Clean] Checking external dependencies...

    REM setup 여부 확인 (소스 다운로드)
    set SETUP_OK=1
    if not exist "external\pugixml\" set SETUP_OK=0
    if not exist "external\harfbuzz\" set SETUP_OK=0
    if not exist "external\freetype\" set SETUP_OK=0
    if not exist "external\libgit2\" set SETUP_OK=0
    if not exist "external\icu\" set SETUP_OK=0

    if !SETUP_OK!==0 (
        echo [Clean] External sources not found. Running setup first...
        echo         This downloads source code and may take several minutes.
        call tools\Windows_dependencies_setup.bat
        if !errorlevel! neq 0 (
            echo [Clean] Setup FAILED.
            goto :end
        )
        echo [Clean] Setup complete.
    ) else (
        echo [Clean] External sources OK.
    )

    REM build 여부 확인 (컴파일된 라이브러리)
    set DEPS_BUILT=1
    if not exist "external\icu\icu4c\bin64\icudt77.dll" set DEPS_BUILT=0
    if not exist "external\harfbuzz\build\harfbuzz.lib" set DEPS_BUILT=0
    if not exist "external\freetype\build\freetype.lib" set DEPS_BUILT=0
    if not exist "external\libgit2\build\git2.dll"      set DEPS_BUILT=0
    if not exist "external\pugixml\pugixml.dll"         set DEPS_BUILT=0

    if !DEPS_BUILT!==0 (
        echo [Clean] Compiled libraries not found. Building dependencies...
        echo         This may take 30-60 minutes.
        call tools\Windows_dependencies_build.bat
        if !errorlevel! neq 0 (
            echo [Clean] Dependency build FAILED.
            goto :end
        )
        echo [Clean] Dependencies built successfully.
    ) else (
        echo [Clean] Compiled libraries OK. Skipping dependency build.
    )
)

echo [1/6] Check dependencies...
set DEPS_OK=1
if not exist "external\icu\icu4c\bin64\icudt77.dll" set DEPS_OK=0
if not exist "external\harfbuzz\build\harfbuzz.lib" set DEPS_OK=0
if not exist "external\freetype\build\freetype.lib" set DEPS_OK=0
if not exist "external\libgit2\build\git2.dll" set DEPS_OK=0
if not exist "external\pugixml\pugixml.dll" set DEPS_OK=0

if !DEPS_OK!==0 (
    echo Dependencies missing. Building dependencies first...
    echo This may take 30-60 minutes...
    call tools\Windows_dependencies_build.bat
    if !errorlevel! neq 0 ( echo Dependencies build FAILED & goto :end )
) else (
    echo Dependencies OK.
)

REM Poppler 별도 체크 (setup.bat 에서 설치, build.bat 에는 없음)
if not exist "external\poppler\Library\include\poppler\cpp\poppler-document.h" (
    echo Poppler not found. Downloading...
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
    echo Poppler OK.
) else (
    echo Poppler OK.
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

set PACKAGE_NAME=ES-DE_windows_%BUILD_DATE%
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
