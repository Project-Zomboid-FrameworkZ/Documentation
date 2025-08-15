@echo off
REM ====================================================
REM Batch file to run Doxygen with a specific config file
REM ====================================================

REM Get the directory where the batch file is located
SET "SCRIPT_DIR=%~dp0"

REM Define the relative path to doxygen.exe inside the bin folder
SET "DOXYGEN_EXE=%SCRIPT_DIR%bin\doxygen.exe"

REM Define the path to the Doxygen configuration file in the root directory
SET "CONFIG_FILE=%SCRIPT_DIR%FrameworkZ_Doxygen_Config"

REM Check if doxygen.exe exists
IF NOT EXIST "%DOXYGEN_EXE%" (
    echo Error: Doxygen executable not found at "%DOXYGEN_EXE%"
    pause
    EXIT /B 1
)

REM Check if the config file exists
IF NOT EXIST "%CONFIG_FILE%" (
    echo Error: Doxygen config file not found at "%CONFIG_FILE%"
    pause
    EXIT /B 1
)

REM Run Doxygen with the specified config file
echo Generating documentation...
"%DOXYGEN_EXE%" "%CONFIG_FILE%"

REM Check if Doxygen ran successfully
IF %ERRORLEVEL% EQU 0 (
    echo Documentation generated.
) ELSE (
    echo Doxygen encountered an error. Exit code: %ERRORLEVEL%
)

REM Optional: Pause to keep the window open
pause
