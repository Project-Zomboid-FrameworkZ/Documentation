@echo off
REM ====================================================
REM Batch file to run DocZ documentation generator
REM ====================================================

REM Get the directory where the batch file is located
SET "SCRIPT_DIR=%~dp0"

REM Define paths
SET "DOCZ_LUA=%SCRIPT_DIR%bin\DocZ.lua"
SET "INPUT_DIR=%SCRIPT_DIR%..\..\FrameworkZ\Contents\mods\FrameworkZ\media\lua"
SET "OUTPUT_DIR=%SCRIPT_DIR%output"
SET "TITLE=FrameworkZ API Documentation"

REM Check if DocZ.lua exists
IF NOT EXIST "%DOCZ_LUA%" (
    echo Error: DocZ.lua not found at "%DOCZ_LUA%"
    pause
    EXIT /B 1
)

REM Check if input directory exists
IF NOT EXIST "%INPUT_DIR%" (
    echo Warning: Input directory not found at "%INPUT_DIR%"
    echo Using test example instead...
    SET "INPUT_DIR=%SCRIPT_DIR%"
    SET "TITLE=DocZ Test Documentation"
)

echo ====================================================
echo Running DocZ Documentation Generator
echo ====================================================
echo Input Directory: %INPUT_DIR%
echo Output Directory: %OUTPUT_DIR%
echo Title: %TITLE%
echo ====================================================

REM Run DocZ
lua "%DOCZ_LUA%" -i "%INPUT_DIR%" -o "%OUTPUT_DIR%" -t "%TITLE%"

REM Check if generation was successful
IF %ERRORLEVEL% EQU 0 (
    echo.
    echo ====================================================
    echo Documentation generated successfully!
    echo Open %OUTPUT_DIR%\index.html to view the documentation
    echo ====================================================
    
    REM Ask if user wants to open the documentation
    echo.
    choice /C YN /M "Open documentation in browser"
    if errorlevel 1 if not errorlevel 2 (
        echo Opening documentation...
        start "" "file:///%OUTPUT_DIR%/index.html"
    )
) else (
    echo.
    echo ====================================================
    echo Error: Documentation generation failed!
    echo ====================================================
)

pause
