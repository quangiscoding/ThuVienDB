@echo off
chcp 65001 > nul
cd /d "%~dp0"

echo ===================================================
echo   AUTOMATED DATABASE SETUP: THUVIEN2
echo ===================================================

call 01_reset_schema.bat
if errorlevel 1 (
    echo [ERROR] Phase 1 schema reset failed.
    exit /b 1
)

call 02_run_seeds.bat
if errorlevel 1 (
    echo [ERROR] Phase 2 seed scripts failed.
    exit /b 1
)

call 03_run_programs.bat
if errorlevel 1 (
    echo [ERROR] Phase 3 program deployment failed.
    exit /b 1
)

echo ===================================================
echo   [OK] THUVIEN2 DATABASE SETUP COMPLETED!
echo ===================================================
