@echo off
setlocal
title A.R.I.S.E Unified Launcher

set "PROJECT_ROOT=%~dp0"

echo =======================================================
echo          A.R.I.S.E. 2.0 Unified Launcher
echo =======================================================
echo.

echo Cleaning up orphaned processes on Port 8002 and 8081...

for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8002') do (
    if NOT "%%a"=="0" if NOT "%%a"=="" taskkill /F /PID %%a >nul 2>&1
)

for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8081') do (
    if NOT "%%a"=="0" if NOT "%%a"=="" taskkill /F /PID %%a >nul 2>&1
)

echo.
echo [1/3] Starting Python AI Metric Service...

cd /d "%PROJECT_ROOT%arise-python-service"

IF NOT EXIST "venv\Scripts\uvicorn.exe" (
    echo Building Python environment...
    IF NOT EXIST "venv" python -m venv venv
    venv\Scripts\python.exe -m pip install -r requirements.txt
)

start "Python Service" cmd /k "cd /d ""%PROJECT_ROOT%arise-python-service"" && call venv\Scripts\activate.bat && python -m uvicorn main:app --host 0.0.0.0 --port 8002 --reload"

echo.
echo [2/3] Starting Spring Boot Orchestrator...

cd /d "%PROJECT_ROOT%arise-backend"

IF EXIST "portable-maven\apache-maven-3.9.6\bin\mvn.cmd" (
    start "Spring Boot Service" cmd /k "cd /d ""%PROJECT_ROOT%arise-backend"" && portable-maven\apache-maven-3.9.6\bin\mvn.cmd spring-boot:run"
) ELSE (
    where mvn >nul 2>nul
    if %errorlevel%==0 (
        start "Spring Boot Service" cmd /k "cd /d ""%PROJECT_ROOT%arise-backend"" && mvn spring-boot:run"
    ) else (
        echo Downloading Portable Maven...
        powershell -Command "Invoke-WebRequest -Uri 'https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.6/apache-maven-3.9.6-bin.zip' -OutFile 'maven.zip'"
        powershell -Command "Expand-Archive -Path 'maven.zip' -DestinationPath 'portable-maven' -Force"
        del maven.zip

        start "Spring Boot Service" cmd /k "cd /d ""%PROJECT_ROOT%arise-backend"" && portable-maven\apache-maven-3.9.6\bin\mvn.cmd spring-boot:run"
    )
)

echo.
echo Waiting for backend services to boot...

timeout /t 5 /nobreak >nul

echo.
echo [3/3] Starting Flutter Desktop Client...

cd /d "%PROJECT_ROOT%arise_2"

:: Self-Healing Build Step: Guard against missing Visual Studio / CMake C++ wrapper files
IF NOT EXIST "windows\flutter\ephemeral\cpp_client_wrapper\core_implementations.cc" (
    echo [!] Missing Flutter Windows C++ wrappers. Self-healing environment...
    if exist "build" rmdir /s /q "build"
    if exist ".dart_tool" rmdir /s /q ".dart_tool"
    if exist "windows\flutter\ephemeral" rmdir /s /q "windows\flutter\ephemeral"
    call flutter clean
    call flutter pub get
    call flutter build windows
)

:: Run using system flutter which has the VS 2026 generator fix applied
start "A.R.I.S.E Flutter Client" cmd /k "cd /d ""%PROJECT_ROOT%arise_2"" && flutter run -d windows"

echo.
echo =======================================================
echo   All A.R.I.S.E services launched successfully
echo =======================================================
pause
