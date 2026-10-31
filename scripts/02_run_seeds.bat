@echo off
chcp 65001 > nul
cd /d "%~dp0"
set SERVER=localhost
set DB=ThuVien2

echo === [2/2] RUNNING SEED SCRIPTS (STAGES 1-2) ===
sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "..\db\002_seed\001_master.sql"
sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "..\db\002_seed\002_entities.sql"
@REM sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "..\db\002_seed\003_borrow_return.sql"
@REM sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "..\db\002_seed\004_fines.sql"