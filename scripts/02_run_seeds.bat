@echo off
chcp 65001 > nul
cd /d "%~dp0"
set SERVER=localhost
set DB=ThuVien2

echo === [2/3] RUNNING SEED SCRIPTS (STAGES 1-5) ===
sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "..\db\002_seed\001_master_lookups.sql"
if errorlevel 1 exit /b 1
sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "..\db\002_seed\002_entities.sql"
if errorlevel 1 exit /b 1
sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "..\db\002_seed\003_entity_relationships.sql"
if errorlevel 1 exit /b 1
sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "..\db\002_seed\004_borrow_return.sql"
if errorlevel 1 exit /b 1
sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "..\db\002_seed\005_fines.sql"
if errorlevel 1 exit /b 1
