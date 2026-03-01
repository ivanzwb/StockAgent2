#!/bin/bash

# StockAgent2 内网穿透启动脚本
# 使用前请先配置 frpc.ini 中的服务器地址和端口

# 检查frpc.ini是否存在
if [ ! -f "frpc.ini" ]; then
    echo "错误: frpc.ini 文件不存在"
    echo "请先编辑 frpc.ini 配置你的frp服务器信息"
    exit 1
fi

# 检测操作系统
OS="$(uname -s)"
FRPC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "正在启动内网穿透服务..."

if [ "$OS" = "Linux" ] || [ "$OS" = "Darwin" ]; then
    # Linux/Mac: 尝试直接运行 frpc
    if command -v frpc &> /dev/null; then
        nohup frpc -c frpc.ini > /dev/null 2>&1 &
    elif command -v docker &> /dev/null; then
        # 回退到 Docker
        docker run -d \
            --name stockagent2-frpc \
            --network host \
            -v "$FRPC_DIR/frpc.ini:/etc/frp/frpc.ini" \
            snowdreamtech/frpc:latest \
            -c /etc/frp/frpc.ini
    else
        echo "错误: 未找到 frpc 或 docker"
        echo "请安装 frpc 或 Docker"
        exit 1
    fi
elif [[ "$OS" == MINGW* ]] || [[ "$OS" == MSYS* ]] || [[ "$OS" == CYGWIN* ]] || [ "$OS" = "Windows_NT" ]; then
    # Windows (Git Bash, MSYS2, Cygwin, or PowerShell)
    FRPC_EXE="$FRPC_DIR/frpc.exe"
    
    # 如果 frpc.exe 不存在，尝试下载
    if [ ! -f "$FRPC_EXE" ]; then
        echo "正在下载 frpc.exe..."
        FRPC_URL="https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_windows_amd64.zip"
        
        if command -v curl &> /dev/null; then
            curl -L "$FRPC_URL" -o frp.zip
        elif command -v wget &> /dev/null; then
            wget "$FRPC_URL" -O frp.zip
        else
            echo "错误: 未找到 curl 或 wget，请手动下载 frpc.exe"
            echo "下载地址: https://github.com/fatedier/frp/releases"
            exit 1
        fi
        
        # 解压
        if command -v unzip &> /dev/null; then
            unzip -o frp.zip
            mv frp_0.52.3_windows_amd64/frpc.exe "$FRPC_DIR/" 2>/dev/null || mv frp*/frpc.exe "$FRPC_DIR/" 2>/dev/null
            rm -rf frp_0.52.3_windows_amd64 frp.zip
        else
            echo "错误: 未找到 unzip，请手动解压或安装 unzip"
            exit 1
        fi
    fi
    
    # 运行 frpc
    if [ -f "$FRPC_EXE" ]; then
        nohup "$FRPC_EXE" -c frpc.ini > /dev/null 2>&1 &
        sleep 2
    else
        echo "错误: frpc.exe 不存在"
        exit 1
    fi
else
    echo "错误: 不支持的操作系统: $OS"
    exit 1
fi

if [ $? -eq 0 ]; then
    echo "内网穿透服务已启动"
    echo "请通过 remote_port (10001) 配置的端口进行访问"
    echo "访问地址: frp.freefrp.net:10001"
else
    echo "启动失败，请检查配置"
    exit 1
fi
