# 炒股助理 (Stock Agent)

AI驱动的A股投资分析助手，支持股票分析、自动监控、板块推荐。

## 主要功能
1. **输入股票，给出操作指令**：买入、观望、卖出
2. **输入股票，监控股票**：自动定时分析，给出买卖建议
3. **输入板块，推荐股票**：获取热门板块及成分股分析

## 逻辑
分析用户输入，识别1、2、3哪个功能，选择对应的功能继续下一步

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

## 系统功能
1. 可以配置LLM参数（DeepSeek / OpenAI / 自定义）
2. 可以对financial skills进行管理（启用/禁用）

## 架构
**独立APP，没有服务器**，客户端直接通过API获取数据和LLM交互
1. **Flutter** — 跨平台UI (Android / Web / iOS)
2. **LangChain.dart** — Agent框架 (ToolsAgent + Tool.fromFunction)
3. **Hive** — 本地数据存储
4. **数据源** — 新浪财经 + 东方财富 (免费API)

---

## 项目结构

```
stockagent2/
├── README.md
├── pubspec.yaml
├── analysis_options.yaml
├── .gitignore
│
└── lib/
    ├── main.dart                    # 入口
    │
    ├── config/
    │   └── app_config.dart          # LLM/APP配置 (Hive持久化)
    │
    ├── models/
    │   └── schemas.dart             # 数据模型
    │
    ├── data_sources/                # 数据源 (直接HTTP调用)
    │   ├── sina_data_source.dart    # 新浪财经 - 实时行情
    │   ├── eastmoney_data_source.dart # 东方财富 - K线/基本面/板块
    │   └── stock_code_service.dart  # 股票代码查询
    │
    ├── skills/                      # LangChain Tools
    │   ├── stock_info_tool.dart     # 实时行情 + K线工具
    │   ├── technical_tool.dart      # 技术指标工具 (MA/MACD/RSI/KDJ/BOLL)
    │   ├── fundamental_tool.dart    # 基本面工具
    │   ├── sector_tool.dart         # 板块工具
    │   └── skill_manager.dart       # 技能管理器
    │
    ├── agent/                       # Agent逻辑
    │   ├── intent_router.dart       # 意图路由 (识别功能1/2/3)
    │   ├── stock_advisor.dart       # 功能1: 股票分析顾问
    │   ├── stock_monitor.dart       # 功能2: 股票监控
    │   └── sector_recommender.dart  # 功能3: 板块推荐
    │
    ├── storage/
    │   └── local_store.dart         # Hive本地存储
    │
    ├── providers/
    │   └── app_state.dart           # 状态管理 (Provider)
    │
    ├── screens/
    │   ├── home_screen.dart         # 聊天式主界面
    │   └── settings_screen.dart     # 设置页
    │
    └── widgets/
        └── chat_bubble.dart         # 聊天气泡组件
```

## 快速开始

### 1. 初始化Flutter项目

```bash
cd stockagent2

# 生成平台文件 (首次需要)
flutter create --project-name stock_agent --org com.stockagent . --platforms android,ios,web

# 安装依赖
flutter pub get
```

### 2. 运行

```bash
flutter run -d chrome        # Web
# flutter run -d android     # Android
# flutter run -d ios         # iOS
```

### 3. 配置LLM

在 **设置页面** 中配置：
- LLM提供商 (DeepSeek / OpenAI / 自定义)
- API Key
- 模型名称
- Temperature

## Financial Skills

| 技能 | 工具名 | 说明 |
|------|--------|------|
| 实时行情 | `get_stock_quote` | 价格、涨跌幅、成交量 |
| K线数据 | `get_stock_kline` | 日/周/月/分钟K线 |
| 技术指标 | `get_technical_indicators` | MA/MACD/RSI/KDJ/布林带 |
| 基本面 | `get_fundamental_data` | PE/PB/ROE/市值/营收 |
| 板块列表 | `get_sector_list` | 行业/概念板块 |
| 板块股票 | `get_sector_stocks` | 板块内股票列表 |

## 数据源
- **新浪财经**: 实时行情 (免费，GBK编码)
- **东方财富**: K线、基本面、板块数据 (免费API)

## 技术栈
- **Flutter** ≥ 3.2.0
- **langchain** ^0.8.1 (Dart)
- **langchain_openai** ^0.8.1+1
- **hive_flutter** ^1.1.0
- **provider** ^6.1.0
