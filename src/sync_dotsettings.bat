@echo off
setlocal EnableExtensions
chcp 65001 >nul

echo.
echo ============================================================
echo  Sync Visual Studio / ReSharper DotSettings
echo ============================================================
echo.

rem Sync ReSharper team-shared DotSettings from repo root into build tree.
rem Preferred source naming: repo root/<repo-name>.DotSettings.
rem Generated target naming: build/**/<solution-name>.sln.DotSettings.
rem Usage: sync_dotsettings.bat [build_dir_relative_to_src]   default: build

set "SRC_DIR=%~dp0"
if "%~1"=="" (set "BUILD_DIR=%SRC_DIR%build") else (set "BUILD_DIR=%SRC_DIR%%~1")
for %%I in ("%SRC_DIR%..") do set "REPO_ROOT=%%~fI"
for %%I in ("%REPO_ROOT%") do set "REPO_NAME=%%~nxI"

echo [Info] Source script dir : %SRC_DIR%
echo [Info] Repository root   : %REPO_ROOT%
echo [Info] Repository name   : %REPO_NAME%
echo [Info] Build directory   : %BUILD_DIR%
echo.

set "DEFAULT_SETTINGS=%REPO_ROOT%\%REPO_NAME%.DotSettings"
set "SRC_DEFAULT_SETTINGS=%SRC_DIR%%REPO_NAME%.DotSettings"
set "FALLBACK_SETTINGS="
if not exist "%DEFAULT_SETTINGS%" (
    if exist "%SRC_DEFAULT_SETTINGS%" (
        set "DEFAULT_SETTINGS=%SRC_DEFAULT_SETTINGS%"
    ) else (
        for %%D in ("%REPO_ROOT%\*.DotSettings" "%SRC_DIR%*.DotSettings") do (
            if not defined FALLBACK_SETTINGS set "FALLBACK_SETTINGS=%%~fD"
        )
    )
)

if exist "%DEFAULT_SETTINGS%" (
    set "SOURCE_SETTINGS=%DEFAULT_SETTINGS%"
) else (
    set "SOURCE_SETTINGS=%FALLBACK_SETTINGS%"
)

if not defined SOURCE_SETTINGS (
    echo [Skip] No .DotSettings file found.
    echo [Hint] Put one of these files in place:
    echo        %REPO_ROOT%\%REPO_NAME%.DotSettings
    echo        %SRC_DIR%%REPO_NAME%.DotSettings
    echo.
    goto :done
)

echo [Info] Source settings  : %SOURCE_SETTINGS%
echo.

if not exist "%BUILD_DIR%\" (
    echo [Skip] Build directory does not exist yet.
    echo [Hint] Run CMake configure first, for example:
    echo        cmake -B build -A x64
    echo.
    goto :done
)

set "COPIED_COUNT=0"
rem Match each *.sln under build/ (top-level and nested subprojects)
for /r "%BUILD_DIR%" %%S in (*.sln) do (
    echo [Found] Solution: %%~fS
    if exist "%REPO_ROOT%\%%~nxS.DotSettings" (
        copy /Y "%REPO_ROOT%\%%~nxS.DotSettings" "%%~dpS" >nul
        echo [Copy]  %%~nxS.DotSettings ^<- %REPO_ROOT%\%%~nxS.DotSettings
    ) else (
        copy /Y "%SOURCE_SETTINGS%" "%%~dpS%%~nxS.DotSettings" >nul
        echo [Copy]  %%~nxS.DotSettings ^<- %SOURCE_SETTINGS%
    )
    set /a COPIED_COUNT+=1
)

rem Fallback before first cmake: create the expected root solution setting file.
if not exist "%BUILD_DIR%\*.sln" (
    echo [Info] No top-level .sln found. Creating default root settings file.
    copy /Y "%SOURCE_SETTINGS%" "%BUILD_DIR%\%REPO_NAME%.sln.DotSettings" >nul
    echo [Copy]  %REPO_NAME%.sln.DotSettings ^<- %SOURCE_SETTINGS%
    set /a COPIED_COUNT+=1
)

echo.
echo [Done] Synced %COPIED_COUNT% DotSettings file(s).
echo.

:done
echo ============================================================
echo.
endlocal
pause
exit /b 0
