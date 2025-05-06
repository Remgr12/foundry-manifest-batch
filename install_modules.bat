@echo off
setlocal enabledelayedexpansion

REM --- Configuration ---
set "URL_FILE=links.txt"
set "TEMP_JSON=temp_module_manifest.json"

REM --- Check prerequisites (basic check) ---
where /q wget
if errorlevel 1 (
    echo Error: wget is required but it's not installed. Aborting.
    goto :eof
)
where /q jq
if errorlevel 1 (
    echo Error: jq is required but it's not installed. Aborting.
    goto :eof
)
REM For unzip, you might use tar (Windows 10/11+) or a dedicated unzip.exe
where /q tar 
if errorlevel 1 (
    where /q unzip
    if errorlevel 1 (
      echo Error: unzip or tar (for unzipping) is required but not installed. Aborting.
      goto :eof
    ) else (
      set UNZIP_COMMAND=unzip -q
    )
) else (
  set UNZIP_COMMAND=tar -xf
)


REM --- Argument Parsing & URL Source Determination ---
set "USE_FILE=false"
set "URLS_TO_PROCESS="

if "%~1"=="" (
    echo Usage: %0 [-f] ^| ^<manifest_url1^> [manifest_url2] ...
    echo.
    echo Options:
    echo   ^<url^>...       Provide one or more manifest URLs directly.
    echo   -f             Read manifest URLs from the file '%URL_FILE%' (one URL per line).
    echo.
    echo Error: No manifest URLs provided and -f option not used.
    goto :eof
)

if /i "%~1"=="-f" (
    set "USE_FILE=true"
    if not "%~2"=="" (
        echo Warning: Additional arguments are ignored when using the -f flag.
    )
) else (
    REM Collect all arguments as URLs
    set "CMD_LINE_URLS="
    for %%a in (%*) do (
        set "CMD_LINE_URLS=!CMD_LINE_URLS! %%a"
    )
    echo Reading URLs from command-line arguments.
)

REM --- Process URLs ---
if "%USE_FILE%"=="true" (
    if not exist "%URL_FILE%" (
        echo Error: Cannot read URLs from '%URL_FILE%'. File does not exist.
        goto :eof
    )
    echo Reading URLs from file: %URL_FILE%
    set /a count=0
    for /f "usebackq delims=" %%L in (`type "%URL_FILE%" ^| findstr /v /r /c:"^[ \t]*#" /c:"^[ \t]*$"`) do (
        set /a count+=1
        call :ProcessURL "%%L"
    )
    if !count! equ 0 (
        echo Error: '%URL_FILE%' exists but contains no valid URLs (or only comments/empty lines).
        goto :eof
    )
    echo Found !count! URL(s) in %URL_FILE%.
) else (
    for %%U in (!CMD_LINE_URLS!) do (
        call :ProcessURL "%%U"
    )
)

echo ----------------------------------------
echo Processing complete.
goto :eof


REM --- Subroutine to process a single URL ---
:ProcessURL
set "JSON_URL=%~1"
echo ----------------------------------------
echo Processing manifest URL: %JSON_URL%

REM 1. Download the module.json file
wget --timeout=15 --tries=2 -q -O "%TEMP_JSON%" "%JSON_URL%"
if errorlevel 1 (
    echo Error: Failed to download manifest from %JSON_URL%. Skipping.
    goto :eof
)
echo Manifest downloaded.

REM 2. Extract download URL and module ID (requires jq.exe)
REM This is tricky with jq output in batch. We capture to temp files or use complex FOR /F.
jq -r ".download" "%TEMP_JSON%" > "%TEMP_JSON%.download_url.txt"
set /p DOWNLOAD_URL=<"%TEMP_JSON%.download_url.txt"
del "%TEMP_JSON%.download_url.txt"

jq -r ".id // .name" "%TEMP_JSON%" > "%TEMP_JSON%.module_id.txt"
set /p MODULE_ID=<"%TEMP_JSON%.module_id.txt"
del "%TEMP_JSON%.module_id.txt"


if "%DOWNLOAD_URL%"=="" or "%DOWNLOAD_URL%"=="null" (
    echo Error: Could not extract 'download' URL from manifest (%JSON_URL%). Skipping.
    if exist "%TEMP_JSON%" del "%TEMP_JSON%"
    goto :eof
)
if "%MODULE_ID%"=="" or "%MODULE_ID%"=="null" (
    echo Warning: Could not extract module 'id' or 'name'. Using generic folder name.
    REM Generate a somewhat unique name (less robust than bash's date +%s%N)
    set "MODULE_ID=unknown_module_%time:~0,2%%time:~3,2%%time:~6,2%%time:~9,2%"
    set "MODULE_ID=!MODULE_ID: =0!"
)

echo Module ID/Name: %MODULE_ID%
echo Download URL: %DOWNLOAD_URL%

set "ZIP_FILENAME=%MODULE_ID%.zip"

REM 3. Download the actual module ZIP file
echo Downloading module package...
wget --timeout=30 --tries=2 -q -O "%ZIP_FILENAME%" "%DOWNLOAD_URL%"
if errorlevel 1 (
    echo Error: Failed to download module package from %DOWNLOAD_URL%. Skipping.
    if exist "%TEMP_JSON%" del "%TEMP_JSON%"
    goto :eof
)
echo Module package downloaded: %ZIP_FILENAME%

REM 4. Create the destination folder
echo Creating directory: %MODULE_ID%
if not exist "%MODULE_ID%" mkdir "%MODULE_ID%"
if errorlevel 1 (
    echo Error: Failed to create directory '%MODULE_ID%'. Skipping unzip.
    if exist "%TEMP_JSON%" del "%TEMP_JSON%"
    if exist "%ZIP_FILENAME%" del "%ZIP_FILENAME%"
    goto :eof
)

REM 5. Unzip the package into the folder
echo Unzipping %ZIP_FILENAME% into %MODULE_ID%\
if "%UNZIP_COMMAND:~0,3%"=="tar" (
    %UNZIP_COMMAND% "%ZIP_FILENAME%" -C "%MODULE_ID%"
) else (
    %UNZIP_COMMAND% "%ZIP_FILENAME%" -d "%MODULE_ID%"
)

if errorlevel 1 (
    echo Error: Failed to unzip '%ZIP_FILENAME%' into '%MODULE_ID%'. Manual check required (zip kept).
) else (
    echo Successfully extracted.
    REM 6. Clean up the downloaded zip file on success
    if exist "%ZIP_FILENAME%" del "%ZIP_FILENAME%"
)

REM Clean up the temporary JSON file
if exist "%TEMP_JSON%" del "%TEMP_JSON%"
goto :eof