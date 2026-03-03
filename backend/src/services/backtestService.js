/**
 * 回测统计服务
 * 提供历史回测、收益率统计、风险指标计算等功能
 */
import { getStockKline, calculateIndicators } from '../tools/kline.js';

let STRATEGIES = {};

export function setStrategies(strategies) {
  STRATEGIES = strategies;
}

class BacktestService {
  constructor() {
    this.cache = new Map();
  }

  /**
   * 获取K线数据（带缓存）
   */
  async getKlinesWithCache(code, period = 'daily', limit = 120) {
    const cacheKey = `${code}_${period}_${limit}`;
    if (this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey);
    }
    const klines = await getStockKline(code, period, limit);
    this.cache.set(cacheKey, klines);
    return klines;
  }

  /**
   * 执行回测
   * @param {string} code - 股票代码
   * @param {string[]} strategyIds - 策略ID列表
   * @param {number} days - 回测天数
   * @returns {Object} 回测结果
   */
  async backtest(code, strategyIds = ['macd_cross', 'ma_trend', 'rsi_oversold'], days = 60) {
    const klines = await this.getKlinesWithCache(code, 'daily', days + 30);
    if (klines.length < days) {
      return { success: false, message: '数据不足' };
    }

    const tradeLog = [];
    let position = null;
    const signals = [];

    for (let i = 30; i < klines.length - 1; i++) {
      const currentKlines = klines.slice(0, i + 1);
      const indicators = calculateIndicators(currentKlines);
      const prevIndicators = i > 30 ? calculateIndicators(klines.slice(0, i)) : null;

      const daySignals = [];
      for (const strategyId of strategyIds) {
        const strategy = STRATEGIES[strategyId];
        if (!strategy) continue;

        try {
          const result = await strategy.evaluate(indicators, prevIndicators, code, currentKlines);
          if (result) {
            daySignals.push({ strategy: strategyId, ...result });
          }
        } catch (e) {
          // 忽略策略执行错误
        }
      }

      const buySignals = daySignals.filter(s => s.signal === 'buy');
      const sellSignals = daySignals.filter(s => s.signal === 'sell');

      const nextPrice = klines[i + 1].close;
      const currentPrice = klines[i].close;

      if (buySignals.length >= 2 && !position) {
        position = {
          entryDate: klines[i].date,
          entryPrice: nextPrice,
          reason: buySignals.map(s => s.reason).join('; ')
        };
        tradeLog.push({
          date: klines[i].date,
          action: 'buy',
          price: nextPrice,
          reason: position.reason
        });
      }

      if (sellSignals.length >= 2 && position) {
        const profitPercent = ((nextPrice - position.entryPrice) / position.entryPrice) * 100;
        tradeLog.push({
          date: klines[i].date,
          action: 'sell',
          price: nextPrice,
          profitPercent,
          reason: sellSignals.map(s => s.reason).join('; ')
        });
        position = null;
      }

      signals.push({
        date: klines[i].date,
        price: currentPrice,
        signals: daySignals
      });
    }

    return this.calculateStats(tradeLog, klines, days);
  }

  /**
   * 计算统计指标
   */
  calculateStats(tradeLog, klines, days) {
    const trades = tradeLog.filter(t => t.action === 'sell');
    const totalTrades = trades.length;
    
    if (totalTrades === 0) {
      return {
        success: true,
        summary: {
          totalTrades: 0,
          winTrades: 0,
          loseTrades: 0,
          winRate: 0,
          totalProfit: 0,
          avgProfit: 0,
          maxProfit: 0,
          maxLoss: 0,
          maxDrawdown: 0,
          sharpeRatio: 0,
        },
        tradeLog,
        message: '无交易记录'
      };
    }

    const profits = trades.map(t => t.profitPercent);
    const winTrades = profits.filter(p => p > 0).length;
    const loseTrades = profits.filter(p => p <= 0).length;
    const totalProfit = profits.reduce((a, b) => a + b, 0);
    const avgProfit = totalProfit / totalTrades;
    const maxProfit = Math.max(...profits);
    const maxLoss = Math.min(...profits);
    const winRate = (winTrades / totalTrades) * 100;

    const startPrice = klines[30]?.close || 1;
    const endPrice = klines[klines.length - 1]?.close || startPrice;
    const benchmarkReturn = ((endPrice - startPrice) / startPrice) * 100;

    const returns = [];
    for (let i = 30; i < klines.length - 1; i++) {
      const dailyReturn = (klines[i + 1].close - klines[i].close) / klines[i].close * 100;
      returns.push(dailyReturn);
    }

    const avgDailyReturn = returns.reduce((a, b) => a + b, 0) / returns.length;
    const stdDev = Math.sqrt(returns.reduce((sum, r) => sum + Math.pow(r - avgDailyReturn, 2), 0) / returns.length);
    const sharpeRatio = stdDev > 0 ? (avgDailyReturn * 252 - 0.03) / (stdDev * Math.sqrt(252)) : 0;

    let maxDrawdown = 0;
    let peak = klines[30].close;
    for (const kline of klines.slice(30)) {
      if (kline.close > peak) peak = kline.close;
      const drawdown = ((peak - kline.close) / peak) * 100;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }

    return {
      success: true,
      summary: {
        totalTrades,
        winTrades,
        loseTrades,
        winRate: parseFloat(winRate.toFixed(2)),
        totalProfit: parseFloat(totalProfit.toFixed(2)),
        avgProfit: parseFloat(avgProfit.toFixed(2)),
        maxProfit: parseFloat(maxProfit.toFixed(2)),
        maxLoss: parseFloat(maxLoss.toFixed(2)),
        maxDrawdown: parseFloat(maxDrawdown.toFixed(2)),
        sharpeRatio: parseFloat(sharpeRatio.toFixed(2)),
        benchmarkReturn: parseFloat(benchmarkReturn.toFixed(2)),
        excessReturn: parseFloat((totalProfit - benchmarkReturn).toFixed(2)),
      },
      tradeLog,
      message: `回测完成：${totalTrades}笔交易，胜率${winRate.toFixed(1)}%`
    };
  }

  /**
   * 获取信号统计
   */
  async getSignalStats(code, strategyIds, days = 30) {
    const klines = await this.getKlinesWithCache(code, 'daily', days + 10);
    if (klines.length < days) {
      return { success: false, message: '数据不足' };
    }

    const stats = {
      buySignals: 0,
      sellSignals: 0,
      holdSignals: 0,
      signalDetails: [],
    };

    for (let i = 10; i < klines.length - 1; i++) {
      const currentKlines = klines.slice(0, i + 1);
      const indicators = calculateIndicators(currentKlines);
      const prevIndicators = i > 10 ? calculateIndicators(klines.slice(0, i)) : null;

      const daySignals = [];
      for (const strategyId of strategyIds) {
        const strategy = STRATEGIES[strategyId];
        if (!strategy) continue;

        try {
          const result = await strategy.evaluate(indicators, prevIndicators, code, currentKlines);
          if (result) {
            daySignals.push(result.signal);
            stats.signalDetails.push({
              date: klines[i].date,
              strategy: strategy.name,
              signal: result.signal,
              reason: result.reason
            });
          }
        } catch (e) {
          // 忽略
        }
      }

      const buyCount = daySignals.filter(s => s === 'buy').length;
      const sellCount = daySignals.filter(s => s === 'sell').length;

      if (buyCount > sellCount) stats.buySignals++;
      else if (sellCount > buyCount) stats.sellSignals++;
      else stats.holdSignals++;
    }

    return {
      success: true,
      stats: {
        totalDays: stats.signalDetails.length > 0 ? klines.length - 11 : 0,
        buyDays: stats.buySignals,
        sellDays: stats.sellSignals,
        holdDays: stats.holdSignals,
        buyRatio: stats.buySignals / (klines.length - 11) * 100,
        sellRatio: stats.sellSignals / (klines.length - 11) * 100,
      },
      recentSignals: stats.signalDetails.slice(-20),
    };
  }

  /**
   * 清除缓存
   */
  clearCache() {
    this.cache.clear();
  }
}

const backtestService = new BacktestService();
export default backtestService;
