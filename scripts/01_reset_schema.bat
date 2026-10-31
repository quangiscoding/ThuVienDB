@echo off
chcp 65001 > nul
cd /d "%~dp0"
set SERVER=localhost
set DB=ThuVien2

echo === [1/2] KIEM TRA DATABASE VA RESET SCHEMA ===
sqlcmd -S %SERVER% -d master -C -f 65001 -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'%DB%') CREATE DATABASE [%DB%];"
sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "..\db\001_schema\002_drop-schema.sql"
sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "..\db\001_schema\001_create-schema.sql"