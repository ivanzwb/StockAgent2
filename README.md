# 炒股助理 (Stock Agent)

AI驱动的A股投资分析助手，支持股票分析、自动监控、板块推荐、股票量化交易。

## 主要功能
1. **输入股票，给出操作指令**：买入、观望、卖出
2. **输入股票，监控股票**：自动定时分析，给出买卖建议
3. **输入板块，推荐股票**：获取热门板块及成分股分析
4. **输入股票，监控股票，启动量化策略**：自动定时分析，根据量化策略发出买卖指令

## 逻辑
分析用户输入，识别1、2、3， 4哪个功能，选择对应的功能继续下一步

### 功能 1. 输入股票，给出操作股票指令
1. 如果用户输入的是股票名字获取对应的股票代码
2. 根据financial skills获取所需信息，交给LLM分析，循环此步骤，最终给出操作指令
3. 记录结果

### 功能 2. 输入股票，监控股票，自动买入卖出
1. 如果用户输入的是股票名字获取对应的股票代码
2. 启动定时器，固定时间分析（使用功能 1），给出操作指令
3. 可以添加/删除，开始/停止监控

### 功能 3. 输入板块，推荐股票
1. 使用工具获取板块列表（行业/概念）
2. 用板块代码获取股票列表
3. 循环分析（使用功能 1）推荐股票及操作指令
4. 记录结果

### 功能 4. 输入股票，监控股票，启动量化策略
1. 如果用户输入的是股票名字获取对应的股票代码
2. 选择量化策略，启动量化操作
3. 可以添加/删除策略，开始/停止监控
4. 记录结果

## 系统功能
- **LLM 配置**：支持 DeepSeek / OpenAI / 自定义 API (如 Ollama)
- **工具管理**：可对 financial agent skills 进行启用/禁用配置
- **内网穿透**：支持 FRP 内网穿透，支持远程访问

## 架构
**前端APP + 后端服务器** 分离架构
- **前端**: Flutter (Android / iOS / Web / Desktop)
- **后端**: Node.js + LangChain.js + LanceDB

## 工具 (Financial Agent Skills)

| 技能ID | 工具名 | 说明 |
|--------|--------|------|
| `search_stock` | 股票搜索 | 按名称搜索股票 |
| `get_stock_kline` | K线数据 | 日K线 + 技术指标 (MA/MACD/RSI) |
| `get_stock_fundamental` | 基本面数据 | PE/PB/ROE/市值/财务数据 |
| `get_all_sectors` | 行业板块 | A股行业板块列表 |
| `get_concept_sectors` | 概念板块 | A股概念板块列表 |
| `get_sector_stocks` | 板块成分股 | 板块内股票列表 |
| `get_stock_news` | 股票新闻 | 最新新闻标题 |

**数据源**：新浪财经 + 东方财富 (免费API)

## 量化策略

| 策略ID | 名称 | 说明 |
|--------|------|------|
| `macd_cross` | MACD金叉死叉 | DIF上穿/下穿DEA |
| `ma_trend` | 均线多头排列 | MA5>MA10>MA20 |
| `rsi_oversold` | RSI超买超卖 | RSI<30买入, RSI>70卖出 |
| `volume_price` | 量价配合 | 放量上涨/下跌 |
| `value_invest` | 价值投资 | 低PE+高ROE+增长 |

## 项目结构
```
stockagent2/
├── backend/                    # Node.js 后端
│   ├── src/
│   │   ├── config/             # 配置管理
│   │   │   └── index.js
│   │   ├── tools/             # 数据工具
│   │   │   ├── index.js       # 工具注册中心
│   │   │   ├── searchStock.js # 股票搜索
│   │   │   ├── kline.js       # K线数据+技术指标
│   │   │   ├── fundamental.js # 基本面数据
│   │   │   ├── sectors.js     # 板块数据
│   │   │   └── news.js        # 股票新闻
│   │   ├── services/          # 业务逻辑
│   │   │   ├── llmService.js   # LLM 连接管理
│   │   │   ├── analysisAgent.js # 股票分析Agent
│   │   │   ├── intentService.js # 意图识别
│   │   │   ├── monitorService.js # 监控服务
│   │   │   ├── quantService.js  # 量化策略
│   │   │   ├── sectorService.js # 板块服务
│   │   │   └── dbService.js     # LanceDB 存储
│   │   ├── routes/            # API 路由
│   │   │   ├── analysis.js
│   │   │   ├── monitor.js
│   │   │   ├── sector.js
│   │   │   ├── quant.js
│   │   │   └── config.js
│   │   └── index.js           # 服务入口
│   ├── package.json
│   ├── .env
│   └── .env.example
├── frontend/                   # Flutter 前端
│   ├── lib/
│   │   ├── models/             # 数据模型
│   │   ├── services/           # API 通信
│   │   ├── providers/          # 状态管理
│   │   ├── pages/              # UI 页面
│   │   │   ├── chat/           # 聊天交互
│   │   │   ├── monitor/        # 股票监控
│   │   │   ├── sector/         # 板块推荐
│   │   │   ├── quant/          # 量化策略
│   │   │   └── settings/       # 系统设置
│   │   ├── theme/              # 主题样式
│   │   └── main.dart           # APP 入口
│   └── pubspec.yaml
├── data/                       # 数据存储 (LanceDB)
├── frpc.toml                   # FRP 客户端配置
├── frpc.ini                    # FRP 客户端配置 (INI格式)
├── frps.toml                   # FRP 服务端配置
├── frps.exe                    # FRP 服务端 (Windows)
├── frpc.exe                    # FRP 客户端 (Windows)
├── start_frps.bat              # FRP 服务端启动 (Windows)
├── start_frps.sh               # FRP 服务端启动 (Linux/Mac)
├── stop_frps.bat               # FRP 服务端停止 (Windows)
├── start-tunnel.bat            # FRP 客户端启动 (Windows)
├── start-tunnel.sh             # FRP 客户端启动 (Linux/Mac)
├── docker-compose.yml          # Docker 部署 (后端)
├── docker-compose.frps.yml     # Docker 部署 (FRP服务端)
├── docker-compose.with-tunnel.yml # Docker 部署 (后端+FRP客户端)
├── Dockerfile.backend          # 后端 Docker 镜像
└── README.md
```

## 快速开始

### 1. 环境要求
- Node.js 18+
- Flutter 3.10+ (仅前端开发)
- Docker + Docker Compose (可选)

### 2. 后端启动
```bash
cd backend
cp .env.example .env
# 编辑 .env 配置 LLM API Key

npm install
npm run dev
```

### 3. 前端启动
```bash
cd frontend
flutter pub get
flutter run           # 或指定平台：
# flutter run -d chrome       # Web
# flutter run -d windows      # Windows
# flutter run -d macos        # macOS
# flutter run -d android      # Android
```

#### Release 构建
```bash
cd frontend
# flutter build apk --release     # Android APK
# flutter build web --release     # Web
# flutter build windows --release  # Windows
# flutter build macos --release    # macOS
# flutter build ios --release      # iOS
```

### 4. Docker 启动（仅后端）
```bash
docker-compose up -d
```

## 环境变量配置

### LLM 配置
```bash
# LLM 提供商: deepseek | openai | custom
LLM_PROVIDER=deepseek

# DeepSeek
DEEPSEEK_API_KEY=your_api_key
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-chat

# OpenAI
OPENAI_API_KEY=your_api_key
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o

# 自定义 (Ollama 等)
CUSTOM_API_KEY=your_api_key
CUSTOM_BASE_URL=http://localhost:11434/v1
CUSTOM_MODEL=qwen2.5
```

### 服务器配置
```bash
PORT=3000
HOST=0.0.0.0

# 监控间隔（分钟）
MONITOR_INTERVAL_MINUTES=30
QUANT_INTERVAL_MINUTES=5
```

## 内网穿透

项目内置 FRP 配置，支持通过内网穿透实现远程访问。支持 Docker 或非 Docker 方式启动 FRP 服务端。

### 架构说明

```
[浏览器/App] ---> [公网服务器:frps] ---> [内网机器:frpc] ---> [后端:3000]
    客户端        服务端(你有公网IP)      客户端(内网)         你的服务
```

| 角色 | 是否需要 Docker | 说明 |
|------|----------------|------|
| 客户端 (浏览器/App) | ❌ 不需要 | 直接访问域名/IP，无需任何配置 |
| FRP 服务端 (frps) | ✅ 可选 | 部署在有公网IP的服务器上 |
| FRP 客户端 (frpc) | ✅ 可选 | 部署在运行后端的内网机器上 |
| 后端服务 | ✅ 可选 | 和 frpc 部署在一起 |

### 相关文件

| 文件 | 用途 |
|------|------|
| `frps.toml` | FRP 服务端配置 |
| `frpc.toml` / `frpc.ini` | FRP 客户端配置 |
| `docker-compose.frps.yml` | FRP 服务端 Docker 部署 |
| `docker-compose.with-tunnel.yml` | 后端 + frpc 客户端 Docker 部署 |

### 端口说明

| 端口 | 用途 |
|------|------|
| 7000 | FRP 客户端连接端口 |
| 8080 | HTTP 穿透端口 |
| 8443 | HTTPS 穿透端口 |
| 7500 | Dashboard 管理界面 (admin/admin) |

### 服务端模式（自建 FRP 服务器）

#### 方式一：Docker 启动（推荐）
```bash
# 启动
docker-compose -f docker-compose.frps.yml up -d

# 停止
docker-compose -f docker-compose.frps.yml down

# 查看日志
docker logs frps
```

#### 方式二：本地二进制启动
```bash
# Windows
start_frps.bat

# Linux/Mac
chmod +x start_frps.sh
./start_frps.sh


#### 服务端配置 (frps.toml)
```toml
bindPort = 7000
vhostHTTPPort = 8080
vhostHTTPSPort = 8443
dashboardAddr = "0.0.0.0"
dashboardPort = 7500
dashboardUser = "admin"
dashboardPwd = "admin"
auth.token = "your_token_here"
```

#### 端口说明
| 端口 | 用途 |
|------|------|
| 7000 | FRP 客户端连接端口 |
| 8080 | HTTP 穿透端口 |
| 8443 | HTTPS 穿透端口 |
| 7500 | Dashboard (admin/admin) |

---

### 场景二：连接外部 FRP 服务器

适用于：内网部署后端，通过外网 FRP 服务器访问。

#### Docker 部署（后端 + frpc）
```bash
docker-compose -f docker-compose.with-tunnel.yml up -d
```

#### 本地部署（仅 frpc）
编辑 `frpc.toml` 配置 FRP 服务器信息：
```toml
serverAddr = "your-frp-server.com"
serverPort = 7000
token = "your-token"

[[proxies]]
name = "web"
type = "tcp"
localIP = "127.0.0.1"
localPort = 3000
remotePort = 10001
```

启动 frpc：
```bash
# Windows
start-tunnel.bat

# Linux/Mac
chmod +x start-tunnel.sh
./start-tunnel.sh
```

#### 用户访问
浏览器或 App 访问：`http://your-frp-server.com:10001`

## API 接口

### 分析
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/analyze` | 分析股票 `{ stock: "600000" }` |
| POST | `/api/analyze/batch` | 批量分析 `{ stocks: ["600000","000001"] }` |
| POST | `/api/chat` | 聊天交互 `{ message: "分析贵州茅台" }` |
| GET | `/api/history` | 分析历史 |
| GET | `/api/history/:code` | 指定股票历史 |

### 监控
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/monitor` | 监控列表 |
| POST | `/api/monitor/add` | 添加监控 |
| POST | `/api/monitor/start` | 启动监控 |
| POST | `/api/monitor/stop` | 停止监控 |
| POST | `/api/monitor/remove` | 删除监控 |

### 板块
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/sector/list?type=industry\|concept` | 板块列表 |
| POST | `/api/sector/analyze` | 板块分析推荐 |

### 量化
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/quant/strategies` | 策略列表 |
| GET | `/api/quant/tasks` | 任务列表 |
| POST | `/api/quant/add` | 添加任务 |
| POST | `/api/quant/start` | 启动任务 |
| POST | `/api/quant/stop` | 停止任务 |
| POST | `/api/quant/remove` | 删除任务 |

### 配置
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/config/llm` | LLM 配置 |
| PUT | `/api/config/llm` | 更新 LLM 配置 |
| GET | `/api/config/tools` | 工具列表 |
| PUT | `/api/config/tools/:id` | 启用/禁用工具 |

### WebSocket
- `ws://localhost:3000/ws` - 实时事件推送（监控结果、量化信号）
