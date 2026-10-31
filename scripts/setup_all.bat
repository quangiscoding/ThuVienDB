@echo off
chcp 65001 > nul
cd /d "%~dp0"

echo ===================================================
echo   AUTOMATED DATABASE SETUP: THUVIEN2
echo ===================================================

call 01_reset_schema.bat
call 02_run_seeds.bat
call 03_run_programs.bat

echo ===================================================
echo   [OK] HOAN TAT TOAN BO SETUP DATABASE!
echo ===================================================
pause