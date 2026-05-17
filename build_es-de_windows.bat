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

for /f "tokens=2 delims==" %%i in ('wmic os get LocalDateTime /value') do set DATETIME=%%i
set BUILD_DATE=%DATETIME:~2,6%

set PACKAGE_NAME=ES-DE_%BUILD_LABEL%_%BUILD_DATE%
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

echo Creating user directories...
mkdir "%PACKAGE_DIR%\Emulators" 2> nul
mkdir "%PACKAGE_DIR%\ROMs" 2> nul

echo [6/6] Creating zip archive with 7-Zip...
"%SEVENZIP%" a -tzip -mx9 "%ZIP_FILE%" "%PACKAGE_DIR%\*" > nul
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
