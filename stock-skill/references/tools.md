# 股票分析工具详细说明

## search_stock

根据关键词搜索A股股票，返回匹配的股票代码和名称列表。

**参数:**
- `keyword`: string - 股票名称或代码关键词

**返回:**
```json
[
  { "code": "601318", "name": "中国平安" },
  { "code": "000001", "name": "平安银行" }
]
```

---

## get_stock_kline

获取股票的K线数据，并计算技术指标。

**参数:**
- `code`: string - 股票代码，如 "600000"
- `period`: string - K线周期，可选 "daily" | "weekly" | "monthly"，默认 "daily"
- `limit`: number - 数据条数，默认 60

**返回:**
```json
{
  "klines": [...],
  "indicators": {
    "ma5": 12.5,
    "ma10": 12.3,
    "ma20": 12.0,
    "macd": { "dif": 0.1, "dea": 0.05, "macd": 0.1 },
    "rsi": 65.5
  }
}
```

---

## get_stock_fundamental

获取股票基本面数据，包括估值、盈利能力、成长性等指标。

**参数:**
- `code`: string - 股票代码

**返回:**
```json
{
  "fundamental": {
    "pe": 12.5,
    "pb": 1.2,
    "marketCap": 500000000000,
    "roe": 15.2
  },
  "financial": {
    "grossMargin": 30.5,
    "netMargin": 12.3,
    "revenueGrowth": 10.5,
    "profitGrowth": 8.2
  }
}
```

---

## get_all_sectors

获取A股所有行业板块列表。

**返回:**
```json
[
  { "code": "bk0001", "name": "银行", "change": 1.2 },
  { "code": "bk0002", "name": "房地产", "change": -0.5 }
]
```

---

## get_concept_sectors

获取A股所有概念板块列表。

**返回:**
```json
[
  { "code": "bk0511", "name": "人工智能", "change": 3.5 },
  { "code": "bk0527", "name": "新能源车", "change": 2.1 }
]
```

---

## get_sector_stocks

获取指定板块的成分股列表。

**参数:**
- `sectorCode`: string - 板块代码
- `limit`: number - 返回数量，默认 20

**返回:**
```json
[
  { "code": "600000", "name": "浦发银行", "price": 10.5, "change": 1.2 }
]
```

---

## get_stock_news

获取指定股票的最新新闻。

**参数:**
- `code`: string - 股票代码
- `limit`: number - 返回数量，默认 10

**返回:**
```json
[
  { "title": "某公司发布2024年报", "time": "2024-03-15" }
]
```
