@echo off
chcp 65001 >nul

echo ========================================
echo   FRPS 启动脚本 (支持 Docker/非Docker)
echo ========================================
echo.

where docker >nul 2>&1
if %errorlevel% equ 0 (
    echo [检测到 Docker 环境]
    
    docker ps -a --format "{{.Names}}" | findstr /C:"frps" >nul
    if %errorlevel% equ 0 (
        echo [发现已有 frps 容器]
        docker start frps
        echo FRPS (Docker) 已启动!
    ) else (
        echo [启动新的 frps 容器...]
        docker-compose -f docker-compose.frps.yml up -d
        echo FRPS (Docker) 已启动!
    )
    
    echo.
    echo Dashboard: http://localhost:7500
    echo FRP Client port: 7000
    echo HTTP: 8080, HTTPS: 8443
) else (
    echo [未检测到 Docker，使用本地启动]
    
    if exist frps.exe (
        start "FRPS" frps.exe -c frps.toml
        echo FRPS (本地) 已启动!
        echo.
        echo Dashboard: http://localhost:7500
        echo FRP Client port: 7000
        echo HTTP: 8080, HTTPS: 8443
    ) else (
        echo Error: frps.exe not found!
        echo 请从 https://github.com/fatedier/frp/releases 下载
        pause
    )
)

echo.
echo ========================================
pause
