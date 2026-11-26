@echo off
chcp 65001 > nul
cd /d "%~dp0"
set SERVER=localhost
set DB=ThuVien2

echo === [3/3] APPLYING PROGRAM MODULES (FUNCTIONS -^> VIEWS -^> PROCS -^> TRIGGERS) ===

:: 1. Build Functions
for /d %%d in ("..\db\003_program\*") do (
    if exist "%%~fd\functions\*.sql" (
        for %%f in ("%%~fd\functions\*.sql") do (
            echo [FUNC] %%~nxf
            sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "%%f"
            if errorlevel 1 exit /b 1
        )
    )
)

:: 2. Build Views
for /d %%d in ("..\db\003_program\*") do (
    if exist "%%~fd\views\*.sql" (
        for %%f in ("%%~fd\views\*.sql") do (
            echo [VIEW] %%~nxf
            sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "%%f"
            if errorlevel 1 exit /b 1
        )
    )
)

:: 3. Build Procedures
for /d %%d in ("..\db\003_program\*") do (
    if exist "%%~fd\procedures\*.sql" (
        for %%f in ("%%~fd\procedures\*.sql") do (
            echo [PROC] %%~nxf
            sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "%%f"
            if errorlevel 1 exit /b 1
        )
    )
)

:: 4. Build Triggers
for /d %%d in ("..\db\003_program\*") do (
    if exist "%%~fd\triggers\*.sql" (
        for %%f in ("%%~fd\triggers\*.sql") do (
            echo [TRIG] %%~nxf
            sqlcmd -S %SERVER% -d %DB% -C -b -f 65001 -i "%%f"
            if errorlevel 1 exit /b 1
        )
    )
)
