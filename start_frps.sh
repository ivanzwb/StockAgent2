#!/bin/bash

echo "========================================"
echo "  FRPS Startup Script (Docker/Native)"
echo "========================================"

if command -v docker &> /dev/null; then
    echo "[Docker detected]"
    
    if docker ps -a --format '{{.Names}}' | grep -q "^frps$"; then
        echo "[Found existing frps container]"
        docker start frps
        echo "FRPS (Docker) started!"
    else
        echo "[Starting new frps container...]"
        docker-compose -f docker-compose.frps.yml up -d
        echo "FRPS (Docker) started!"
    fi
    
    echo ""
    echo "Dashboard: http://localhost:7500"
    echo "FRP Client port: 7000"
    echo "HTTP: 8080, HTTPS: 8443"
elif [ -f "./frps" ]; then
    echo "[No Docker, using local binary]"
    ./frps -c frps.toml &
    echo "FRPS (local) started!"
    echo ""
    echo "Dashboard: http://localhost:7500"
    echo "FRP Client port: 7000"
    echo "HTTP: 8080, HTTPS: 8443"
else
    echo "Error: Neither Docker nor frps binary found!"
    echo "Please download frps from https://github.com/fatedier/frp/releases"
    exit 1
fi
