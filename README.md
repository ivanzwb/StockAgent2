# 炒股助理 (Stock Agent)

AI驱动的A股投资分析助手，支持股票分析、自动监控、板块推荐, 股票量化交易。

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
1. 可以配置LLM参数（DeepSeek / OpenAI / 自定义）
2. 可以对financial agent skills进行管理（启用/禁用）

## 架构
**前端APP + 后端服务器** 分离架构
1. **前端**: Flutter (Android / iOS / Web / Desktop)
2. **后端**: Node.js + LangChain.js + lanceDB

## Tools
1. **工具列表**
| 技能     | 工具名                                    | 说明           |
| -------  | ----------------------------------------- | -------------- |
| K线数据  | `get_stock_kline`                         | 日K线数据       |
| 基本面   | `get_stock_fundamental`                   | PE/PB/ROE/市值 |
| 股票搜索 | `search_stock`                            | 按名称搜索股票  |
| 板块列表 | `get_all_sectors` / `get_concept_sectors` | 行业/概念板块   |
| 板块股票 | `get_sector_stocks`                       | 板块内股票列表  |

2. **数据源**
  - 工具数据源：新浪财经 + 东方财富 (免费API)

## 量化策略
| 策略ID         | 名称         | 说明                              |
| -------------- | ------------ | --------------------------------- |
| `macd_cross`   | MACD金叉死叉 | DIF上穿/下穿DEA                   |
| `ma_trend`     | 均线多头排列 | MA5>MA10>MA20                     |
| `rsi_oversold` | RSI超买超卖  | RSI<30买入, RSI>70卖出            |
| `volume_price` | 量价配合     | 放量上涨/下跌                     |
| `value_invest` | 价值投资     | 低PE+高ROE+增长                   |

## 项目结构
```
stockagent2/
├── backend/                    # Node.js 后端
│   ├── src/
│   │   ├── config/             # 配置管理
│   │   │   └── index.js
│   │   ├── tools/              # 数据工具
│   │   │   ├── index.js        # 工具注册中心
│   │   │   ├── searchStock.js  # 股票搜索
│   │   │   ├── kline.js        # K线数据+技术指标
│   │   │   ├── fundamental.js  # 基本面数据
│   │   │   └── sectors.js      # 板块数据
│   │   ├── services/           # 业务逻辑
│   │   │   ├── llmService.js   # LLM 连接管理
│   │   │   ├── analysisAgent.js # 股票分析Agent
│   │   │   ├── intentService.js # 意图识别
│   │   │   ├── monitorService.js # 监控服务
│   │   │   ├── quantService.js  # 量化策略
│   │   │   ├── sectorService.js # 板块服务
│   │   │   └── dbService.js     # LanceDB 存储
│   │   ├── routes/             # API 路由
│   │   │   ├── analysis.js
│   │   │   ├── monitor.js
│   │   │   ├── sector.js
│   │   │   ├── quant.js
│   │   │   └── config.js
│   │   └── index.js            # 服务入口
│   ├── package.json
│   ├── .env
│   └── .env.example
├── frontend/                   # Flutter 前端
│   ├── lib/
│   │   ├── models/             # 数据模型
│   │   │   └── models.dart
│   │   ├── services/           # API 通信
│   │   │   ├── api_service.dart
│   │   │   └── websocket_service.dart
│   │   ├── providers/          # 状态管理
│   │   │   └── app_state.dart
│   │   ├── pages/              # UI 页面
│   │   │   ├── chat/           # 聊天交互
│   │   │   ├── monitor/        # 股票监控
│   │   │   ├── sector/         # 板块推荐
│   │   │   ├── quant/          # 量化策略
│   │   │   └── settings/       # 系统设置
│   │   ├── theme/              # 主题样式
│   │   │   └── app_theme.dart
│   │   └── main.dart           # APP 入口
│   └── pubspec.yaml
├── docker-compose.yml
├── Dockerfile.backend
└── README.md
```

## 快速开始

### 1. 后端启动
```bash
cd backend
cp .env.example .env
# 编辑 .env 配置 LLM API Key
npm install
npm run dev
```

### 2. 前端启动
```bash
cd frontend
flutter pub get
flutter run           # 或指定平台：
# flutter run -d chrome       # Web
# flutter run -d windows      # Windows
# flutter run -d macos        # macOS
# flutter run -d android      # Android
```

### 3. Docker 启动（仅后端）
```bash
docker-compose up -d
```

## API 接口

### 分析
- `POST /api/analyze` - 分析股票 `{ stock: "600000" }`
- `POST /api/analyze/batch` - 批量分析 `{ stocks: ["600000","000001"] }`
- `POST /api/chat` - 聊天交互 `{ message: "分析贵州茅台" }`
- `GET /api/history` - 分析历史
- `GET /api/history/:code` - 指定股票历史

### 监控
- `GET /api/monitor` - 监控列表
- `POST /api/monitor/add` - 添加监控
- `POST /api/monitor/start` - 启动监控
- `POST /api/monitor/stop` - 停止监控
- `POST /api/monitor/remove` - 删除监控

### 板块
- `GET /api/sector/list?type=industry|concept` - 板块列表
- `POST /api/sector/analyze` - 板块分析推荐

### 量化
- `GET /api/quant/strategies` - 策略列表
- `GET /api/quant/tasks` - 任务列表
- `POST /api/quant/add` - 添加任务
- `POST /api/quant/start` - 启动任务
- `POST /api/quant/stop` - 停止任务
- `POST /api/quant/remove` - 删除任务

### 配置
- `GET /api/config/llm` - LLM 配置
- `PUT /api/config/llm` - 更新 LLM 配置
- `GET /api/config/tools` - 工具列表
- `PUT /api/config/tools/:id` - 启用/禁用工具

### WebSocket
- `ws://localhost:3000/ws` - 实时事件推送（监控结果、量化信号）
