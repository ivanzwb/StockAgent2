@echo off
chcp 65001 >nul

echo 停止 FRPS...

where docker >nul 2>&1
if %errorlevel% equ 0 (
    docker stop frps 2>nul
    echo Docker 容器已停止
)

taskkill /F /IM frps.exe 2>nul
echo 本地进程已停止

echo Done!
pause
