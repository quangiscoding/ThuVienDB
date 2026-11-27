@echo off
chcp 65001 > nul
cd /d "%~dp0"
set SERVER=localhost
set DB=ThuVien2

echo === [1/3] CHECKING DATABASE AND RESETTING SCHEMA ===
sqlcmd -S %SERVER% -d master -C -b -f 65001 -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'%DB%') CREATE DATABASE [%DB%];"
if errorlevel 1 exit /b 1
sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "..\db\001_schema\002_drop-schema.sql"
if errorlevel 1 exit /b 1
sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "..\db\001_schema\001_create-schema.sql"
if errorlevel 1 exit /b 1
