@echo off
echo Testing monitoring deployment...

REM Check Docker
docker --version
if errorlevel 1 (
    echo ERROR: Docker is not installed
    exit /b 1
)

REM Check Docker Compose
docker-compose --version
if errorlevel 1 (
    echo ERROR: Docker Compose is not installed
    exit /b 1
)

echo.
echo SUCCESS: Docker and Docker Compose are available
echo.

REM Check compose file
if exist "..\..\compose\monitoring-compose.yml" (
    echo SUCCESS: Monitoring compose file found
) else (
    echo ERROR: Monitoring compose file not found
    exit /b 1
)

echo.
echo Monitoring stack can be deployed!
echo.
echo To deploy monitoring:
echo   1. Run: deploy-monitoring.bat start
echo   2. Open: http://localhost:9090 (Prometheus)
echo   3. Open: http://localhost:3000 (Grafana, admin/admin123)
echo   4. Open: http://localhost:9093 (AlertManager)

pause
