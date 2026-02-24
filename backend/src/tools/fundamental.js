/**
 * 基本面数据工具 - 获取PE/PB/ROE/市值等
 * 数据源：东方财富
 */
import { getEastMoneySecId } from './searchStock.js';

/**
 * 获取股票基本面数据
 * @param {string} code - 股票代码
 * @returns {Promise<Object>}
 */
export async function getStockFundamental(code) {
  try {
    const secId = getEastMoneySecId(code);

    // 获取实时行情数据（包含部分基本面）
    const quoteUrl = `https://push2.eastmoney.com/api/qt/stock/get?secid=${secId}&fields=f43,f44,f45,f46,f47,f48,f50,f51,f52,f55,f57,f58,f60,f116,f117,f162,f163,f167,f170,f171,f173,f183,f184,f185,f186,f187,f188,f190,f192`;
    const quoteResponse = await fetch(quoteUrl);
    const quoteData = await quoteResponse.json();

    if (!quoteData.data) {
      return null;
    }

    const d = quoteData.data;

    return {
      code: d.f57,
      name: d.f58,
      currentPrice: d.f43 / 100,      // 当前价
      high: d.f44 / 100,               // 最高价
      low: d.f45 / 100,                // 最低价
      open: d.f46 / 100,               // 开盘价
      volume: d.f47,                    // 成交量（手）
      amount: d.f48,                    // 成交额
      high52w: d.f51 / 100,            // 52周最高
      low52w: d.f52 / 100,             // 52周最低
      pe: d.f162 / 100,                // 市盈率(动态)
      peTTM: d.f163 / 100,             // 市盈率(TTM)
      pb: d.f167 / 100,                // 市净率
      totalMarketValue: d.f116,         // 总市值
      circulatingMarketValue: d.f117,   // 流通市值
      changePercent: d.f170 / 100,      // 涨跌幅
      changeAmount: d.f171 / 100,       // 涨跌额
      turnoverRate: d.f168 / 100,       // 换手率
      roe: d.f173 / 100,               // ROE
      grossMargin: d.f186 / 100,        // 毛利率
      netMargin: d.f187 / 100,          // 净利率
      revenueGrowth: d.f185 / 100,      // 营收增长率
      netProfitGrowth: d.f188 / 100,    // 净利润增长率
    };
  } catch (error) {
    console.error('获取基本面数据失败:', error.message);
    return null;
  }
}

/**
 * 获取财务摘要数据
 * @param {string} code - 股票代码
 * @returns {Promise<Object>}
 */
export async function getFinancialSummary(code) {
  try {
    const secId = getEastMoneySecId(code);
    const url = `https://emweb.securities.eastmoney.com/PC_HSF10/NewFinanceAnalysis/ZYZBAjaxNew?type=0&code=${secId}`;
    const response = await fetch(url);
    const data = await response.json();

    if (!data.data || data.data.length === 0) {
      return null;
    }

    // 返回最近4期的财务数据
    return data.data.slice(0, 4).map(item => ({
      reportDate: item.REPORT_DATE,
      eps: item.EPSJB,           // 每股收益
      bvps: item.BPS,            // 每股净资产
      roe: item.ROEJQ,           // ROE
      revenue: item.TOTALOPERATEREVE,      // 营业总收入
      netProfit: item.PARENTNETPROFIT,     // 归属净利润
      grossMargin: item.XSMLL,             // 毛利率
      netMargin: item.PARENTNETPROFITRATE, // 净利率
    }));
  } catch (error) {
    console.error('获取财务摘要失败:', error.message);
    return null;
  }
}

export default { getStockFundamental, getFinancialSummary };
