# Tools Documentation - 工具使用文档

## 概述

本工具集提供A股市场数据查询能力，包括股票搜索、K线数据、基本面分析、板块查询和新闻资讯。

详细使用流程请参考 [SKILL.md](../SKILL.md)

---

## 调用方式

### 命令行调用

```bash
node scripts/cli.js <command> [options]
```

### 全局安装

```bash
npm link
stock <command> [options]
```

---

## 命令清单

| 命令 | 描述 | 快速调用 |
|------|------|----------|
| search | 按名称搜索A股股票代码 | `stock search <关键词>` |
| kline | 获取股票K线数据和技术指标 | `stock kline <代码> [--period] [--limit]` |
| fundamental | 获取PE/PB/ROE/市值等数据 | `stock fundamental <代码>` |
| sectors | 获取A股所有行业板块列表 | `stock sectors` |
| concepts | 获取A股所有概念板块列表 | `stock concepts` |
| sector-stocks | 获取板块内的股票列表 | `stock sector-stocks <板块代码>` |
| news | 获取股票的最新新闻 | `stock news <代码> [--limit]` |

---

## 命令详细说明

### search

**功能**：根据关键词搜索A股股票代码

**使用流程关联**：基本分析、行情查询、基本面分析、新闻资讯、选股策略

**用法**：
```bash
node scripts/cli.js search <keyword>
node scripts/cli.js search 浦发银行
node scripts/cli.js search 600000
```

**返回字段**：code, name, market, fullCode

**返回示例**：
```json
[
  { "code": "600519", "name": "贵州茅台", "market": "沪A", "fullCode": "1.600519" }
]
```

---

### kline

**功能**：获取股票K线数据和技术指标（MA/MACD/RSI等）

**使用流程关联**：基本分析、行情查询、选股策略

**用法**：
```bash
node scripts/cli.js kline <code> [--period daily|weekly|monthly] [--limit 60]
node scripts/cli.js kline 600000                    # 日K，默认60条
node scripts/cli.js kline 600000 --period weekly    # 周K
node scripts/cli.js kline 600000 --period monthly   # 月K
node scripts/cli.js kline 600000 --limit 120        # 获取120条数据
```

**参数说明**：
- `code`: 股票代码（6位数字）
- `--period`: K线周期 (daily/weekly/monthly)，默认 daily
- `--limit`: 返回数据条数，默认60

**返回字段说明**：
- K线数据：date, open, close, high, low, volume, amount, amplitude, changePercent, turnoverRate
- 技术指标：ma5, ma10, ma20, ma60, macd, rsi, kdj, boll, cci, wr, obv

**返回示例**：
```json
{
  "klines": [
    { "date": "2024-01-02", "open": 10.0, "close": 10.2, "high": 10.5, "low": 9.9, "volume": 1234567 }
  ],
  "indicators": {
    "currentPrice": 10.50,
    "ma5": 10.30,
    "ma10": 10.20,
    "ma20": 10.15,
    "macd": { "dif": 0.05, "dea": 0.03, "histogram": 0.04 },
    "rsi": 65.5,
    "kdj": { "k": 65.2, "d": 62.1, "j": 71.4 },
    "boll": { "upper": 11.0, "middle": 10.2, "lower": 9.4 }
  }
}
```

---

### fundamental

**功能**：获取股票基本面数据

**使用流程关联**：基本分析、基本面分析、选股策略

**用法**：
```bash
node scripts/cli.js fundamental <code>
node scripts/cli.js fundamental 600000
```

**返回字段说明**：
- fundamental: 实时行情数据
  - currentPrice, high, low, open, volume, amount
  - pe, peTTM, pb (估值指标)
  - roe, grossMargin, netMargin (盈利能力)
  - totalMarketValue, circulatingMarketValue (市值)
  - changePercent, changeAmount (涨跌幅)
  - revenueGrowth, netProfitGrowth (成长性)
- financial: 财务摘要数据（最近4期）
  - reportDate, eps, bvps, roe
  - revenue, netProfit, grossMargin, netMargin

**返回示例**：
```json
{
  "fundamental": {
    "code": "600000",
    "name": "浦发银行",
    "currentPrice": 8.50,
    "pe": 5.2,
    "pb": 0.65,
    "roe": 11.5,
    "totalMarketValue": 250000000000,
    "changePercent": 1.2
  },
  "financial": [
    { "reportDate": "2024-03-31", "eps": 0.85, "roe": 11.5, "revenue": 50000000000, "netProfit": 15000000000 }
  ]
}
```

---

### sectors

**功能**：获取A股所有行业板块列表

**使用流程关联**：板块分析、选股策略

**用法**：
```bash
node scripts/cli.js sectors
```

**返回字段**：code, name, changePercent, leaderStock, price

**返回示例**：
```json
[
  { "code": "881001", "name": "银行", "changePercent": 1.2, "leaderStock": "工商银行", "price": 3250 }
]
```

---

### concepts

**功能**：获取A股所有概念板块列表

**使用流程关联**：板块分析、选股策略

**用法**：
```bash
node scripts/cli.js concepts
```

**返回字段**：同 sectors

---

### sector-stocks

**功能**：获取指定板块的成分股列表

**使用流程关联**：板块分析、选股策略

**用法**：
```bash
node scripts/cli.js sector-stocks <sectorCode> [--limit 20]
node scripts/cli.js sector-stocks 881001
node scripts/cli.js sector-stocks 881001 --limit 50
```

**参数说明**：
- `sectorCode`: 板块代码
- `--limit`: 返回股票数量，默认20

**返回字段**：code, name, price, changePercent, high, low, open, preClose

**返回示例**：
```json
[
  { "code": "600000", "name": "浦发银行", "price": 8.50, "changePercent": 1.2, "high": 8.60, "low": 8.40 }
]
```

---

### news

**功能**：获取指定股票的最新新闻标题列表

**使用流程关联**：基本分析、新闻资讯

**用法**：
```bash
node scripts/cli.js news <code> [--limit 10]
node scripts/cli.js news 600000
node scripts/cli.js news 600000 --limit 20
```

**参数说明**：
- `code`: 股票代码（6位数字）
- `--limit`: 返回新闻数量，默认10

**返回字段**：title, publishTime, url

**返回示例**：
```json
[
  { "title": "浦发银行发布2024年半年报", "publishTime": "2024-08-28 10:00:00", "url": "https://..." }
]
```

---

## 股票代码说明

- 沪市：600/688/001开头
- 深市：000/001/002/003/300开头

输入时可直接使用纯数字代码（如 `600000`），工具会自动处理。

---

## 数据来源

东方财富 (EastMoney)
