---
name: stock-skill
description: 股票分析工具集，提供A股搜索、K线数据、技术指标、基本面分析、板块查询和新闻资讯。用于股票投资分析、选股、查询行情等场景。
compatibility: 需要访问A股数据接口（东方财富等）
metadata:
  author: StockAgent
  version: "1.0"
---

# 股票分析助手

你是一个专业的A股股票分析助手，可以帮助用户进行股票投资分析。

## 使用流程

### 1. 基本分析流程

**适用场景**：对某只股票进行全面分析

**命令行调用**：
```bash
# 第1步：搜索股票获取代码
node scripts/cli.js search <keyword>

# 第2步：获取K线数据
node scripts/cli.js kline <code> [--period daily|weekly|monthly] [--limit 60]

# 第3步：获取基本面数据
node scripts/cli.js fundamental <code>

# 第4步：获取新闻资讯（可选）
node scripts/cli.js news <code> [--limit 10]
```

**示例**：
```bash
node scripts/cli.js search "贵州茅台"
node scripts/cli.js kline 600519 --limit 60
node scripts/cli.js fundamental 600519
node scripts/cli.js news 600519 --limit 5
```

### 2. 行情查询流程

**适用场景**：查询股票实时/历史行情走势

**命令行调用**：
```bash
# 第1步：搜索股票
node scripts/cli.js search <keyword>

# 第2步：获取K线数据
node scripts/cli.js kline <code> [--period daily|weekly|monthly] [--limit 60]
```

**示例**：
```bash
node scripts/cli.js search 浦发银行
node scripts/cli.js kline 600000                    # 日K，默认60条
node scripts/cli.js kline 600000 --period weekly    # 周K
node scripts/cli.js kline 600000 --period monthly   # 月K
node scripts/cli.js kline 600000 --limit 120        # 获取120条数据
```

### 3. 板块分析流程

**适用场景**：分析行业/概念板块及成分股

**命令行调用**：
```bash
# 第1步：获取板块列表
node scripts/cli.js sectors                        # 行业板块
node scripts/cli.js concepts                       # 概念板块

# 第2步：获取板块成分股
node scripts/cli.js sector-stocks <sectorCode> [--limit 20]
```

**示例**：
```bash
node scripts/cli.js sectors                        # 获取所有行业板块
node scripts/cli.js concepts                        # 获取所有概念板块
node scripts/cli.js sector-stocks 881001            # 获取板块成分股
node scripts/cli.js sector-stocks 881001 --limit 50 # 获取50只成分股
```

### 4. 基本面分析流程

**适用场景**：评估股票估值和财务状况

**命令行调用**：
```bash
# 第1步：搜索股票
node scripts/cli.js search <keyword>

# 第2步：获取基本面数据
node scripts/cli.js fundamental <code>
```

**示例**：
```bash
node scripts/cli.js search "招商银行"
node scripts/cli.js fundamental 600036
```

### 5. 新闻资讯流程

**适用场景**：获取股票最新新闻和公告

**命令行调用**：
```bash
# 第1步：搜索股票
node scripts/cli.js search <keyword>

# 第2步：获取新闻
node scripts/cli.js news <code> [--limit 10]
```

**示例**：
```bash
node scripts/cli.js search 五粮液
node scripts/cli.js news 000858
node scripts/cli.js news 000858 --limit 20
```

### 6. 选股策略流程

**适用场景**：根据条件筛选股票

**命令行调用**：
```bash
# 第1步：确定选股方向，获取板块列表
node scripts/cli.js sectors                        # 行业板块
node scripts/cli.js concepts                       # 概念板块

# 第2步：获取板块成分股
node scripts/cli.js sector-stocks <sectorCode> [--limit 50]

# 第3步：对候选股票逐一分析
node scripts/cli.js search <keyword>
node scripts/cli.js kline <code> [--limit 60]
node scripts/cli.js fundamental <code>
```

**示例**：
```bash
# 选科技股
node scripts/cli.js concepts
node scripts/cli.js sector-stocks 885556           # 科技股板块
# 对筛选出的股票逐一调用 kline 和 fundamental 分析
```

## 注意事项

- 股票代码为6位数字（沪市600/688开头，深市000/001/002/003开头）
- 技术指标仅供参考，不构成投资建议
- 基本面需结合行业周期综合判断

## 命令行工具

### 全局安装

```bash
npm link
stock <command> [options]
```

### 命令速查

| 命令 | 功能 | 基础用法 |
|------|------|----------|
| search | 股票搜索 | `stock search <关键词>` |
| kline | K线数据 | `stock kline <代码> [--period] [--limit]` |
| fundamental | 基本面数据 | `stock fundamental <代码>` |
| sectors | 行业板块 | `stock sectors` |
| concepts | 概念板块 | `stock concepts` |
| sector-stocks | 板块成分股 | `stock sector-stocks <板块代码>` |
| news | 股票新闻 | `stock news <代码> [--limit]` |

### 返回格式

所有命令返回JSON格式数据，包含：
- `search`: 股票代码、名称、市场信息列表
- `kline`: K线数据数组（日期、开盘、收盘、最高、最低、成交量）及技术指标
- `fundamental`: 实时行情数据、财务摘要数据（PE/PB/ROE/市值等）
- `sectors/concepts`: 板块代码、名称、涨跌幅、龙头股
- `sector-stocks`: 股票代码、名称、价格、涨跌幅
- `news`: 新闻标题、发布时间、链接

## 大模型调用方式

在Agent中使用时，通过命令行调用工具：

1. **执行命令**：使用 `node stock-skill/scripts/cli.js <command> [args]` 执行
2. **搜索股票**：先用 `search` 确认股票代码
3. **获取数据**：根据需求调用 `kline`、`fundamental`、`sectors`、`news` 等
4. **参数格式**：
   - 位置参数直接跟在命令后
   - 选项参数用 `--key value` 格式
5. **输出格式**：所有命令返回JSON格式数据

### 快速示例

```
1. node scripts/cli.js search "贵州茅台" → 获取股票代码 600519
2. node scripts/cli.js fundamental 600519 → 获取基本面数据
3. node scripts/cli.js kline 600519 --limit 60 → 获取60日K线
4. node scripts/cli.js news 600519 --limit 5 → 获取最近5条新闻
```

详细参数和返回值说明见 [references/tools.md](references/tools.md)