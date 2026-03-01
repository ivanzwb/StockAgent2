@echo off
chcp 65001 >nul
echo StockAgent2 内网穿透启动脚本
echo ========================================
echo.

REM 检查frpc.ini是否存在
if not exist "frpc.ini" (
    echo 错误: frpc.ini 文件不存在
    echo 请先编辑 frpc.ini 配置你的frp服务器信息
    pause
    exit /b 1
)

echo 正在启动内网穿透服务...
echo.

REM 使用docker运行frp客户端
docker run -d --name stockagent2-frpc --network host -v "%~dp0frpc.ini:/etc/frp/frpc.ini" snowdreamtech/frpc:latest -c /etc/frp/frpc.ini

if %errorlevel% equ 0 (
    echo 内网穿透服务已启动成功!
    echo 请查看 frpc.ini 中的 remote_port 配置的端口进行访问
    echo.
    echo 使用以下命令停止穿透服务:
    echo   docker stop stockagent2-frpc
    echo   docker rm stockagent2-frpc
) else (
    echo 启动失败，请检查配置
)

echo.
pause
