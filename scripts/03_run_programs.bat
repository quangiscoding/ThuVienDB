@echo off
chcp 65001 > nul
cd /d "%~dp0"
set SERVER=localhost
set DB=ThuVien2

echo === [3/3] APPLYING PROGRAM MODULES (FUNCTIONS -^> VIEWS -^> PROCS -^> TRIGGERS) ===

:: 1. Build Functions
for /r "..\db\003_program" %%f in (*functions\*.sql) do (
    echo [FUNC] %%~nxf
    sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "%%f"
)

:: 2. Build Views
for /r "..\db\003_program" %%f in (*views\*.sql) do (
    echo [VIEW] %%~nxf
    sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "%%f"
)

:: 3. Build Procedures
for /r "..\db\003_program" %%f in (*procedures\*.sql) do (
    echo [PROC] %%~nxf
    sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "%%f"
)

:: 4. Build Triggers
for /r "..\db\003_program" %%f in (*triggers\*.sql) do (
    echo [TRIG] %%~nxf
    sqlcmd -S %SERVER% -d %DB% -C -f 65001 -i "%%f"
)