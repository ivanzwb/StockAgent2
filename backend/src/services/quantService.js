/**
 * 量化策略服务
 * 功能4: 量化策略监控与交易信号
 */
import cron from 'node-cron';
import { getStockKline, calculateIndicators } from '../tools/kline.js';
import { getStockFundamental } from '../tools/fundamental.js';
import config from '../config/index.js';

// 内置量化策略定义
const STRATEGIES = {
  macd_cross: {
    id: 'macd_cross',
    name: 'MACD金叉死叉',
    description: 'MACD DIF上穿DEA为买入信号，下穿为卖出信号',
    evaluate: (indicators, prevIndicators) => {
      if (!indicators.macd || !prevIndicators?.macd) return null;
      const { dif, dea } = indicators.macd;
      const prevDif = prevIndicators.macd.dif;
      const prevDea = prevIndicators.macd.dea;

      if (prevDif <= prevDea && dif > dea) {
        return { signal: 'buy', reason: 'MACD金叉：DIF上穿DEA', confidence: 7 };
      }
      if (prevDif >= prevDea && dif < dea) {
        return { signal: 'sell', reason: 'MACD死叉：DIF下穿DEA', confidence: 7 };
      }
      return { signal: 'hold', reason: 'MACD无明显信号', confidence: 5 };
    },
  },

  ma_trend: {
    id: 'ma_trend',
    name: '均线多头排列',
    description: 'MA5>MA10>MA20为多头排列买入，反之卖出',
    evaluate: (indicators) => {
      const { ma5, ma10, ma20 } = indicators;
      if (!ma5 || !ma10 || !ma20) return null;

      if (ma5 > ma10 && ma10 > ma20) {
        return { signal: 'buy', reason: '均线多头排列：MA5>MA10>MA20', confidence: 7 };
      }
      if (ma5 < ma10 && ma10 < ma20) {
        return { signal: 'sell', reason: '均线空头排列：MA5<MA10<MA20', confidence: 7 };
      }
      return { signal: 'hold', reason: '均线交织，趋势不明', confidence: 4 };
    },
  },

  rsi_oversold: {
    id: 'rsi_oversold',
    name: 'RSI超买超卖',
    description: 'RSI<30超卖买入，RSI>70超买卖出',
    evaluate: (indicators) => {
      const { rsi } = indicators;
      if (rsi == null) return null;

      if (rsi < 30) {
        return { signal: 'buy', reason: `RSI超卖(${rsi})，可能反弹`, confidence: 6 };
      }
      if (rsi > 70) {
        return { signal: 'sell', reason: `RSI超买(${rsi})，可能回调`, confidence: 6 };
      }
      if (rsi < 40) {
        return { signal: 'hold', reason: `RSI偏低(${rsi})，观察`, confidence: 4 };
      }
      return { signal: 'hold', reason: `RSI中性(${rsi})`, confidence: 5 };
    },
  },

  volume_price: {
    id: 'volume_price',
    name: '量价配合',
    description: '放量上涨买入，放量下跌卖出',
    evaluate: (indicators) => {
      const { latestVolume, volumeAvg5, currentPrice, ma5 } = indicators;
      if (!latestVolume || !volumeAvg5) return null;

      const volumeRatio = latestVolume / volumeAvg5;
      const priceAboveMa5 = currentPrice > (ma5 || 0);

      if (volumeRatio > 1.5 && priceAboveMa5) {
        return { signal: 'buy', reason: `放量上涨（量比${volumeRatio.toFixed(2)}），多头强势`, confidence: 7 };
      }
      if (volumeRatio > 1.5 && !priceAboveMa5) {
        return { signal: 'sell', reason: `放量下跌（量比${volumeRatio.toFixed(2)}），空头强势`, confidence: 7 };
      }
      return { signal: 'hold', reason: `量价平稳（量比${volumeRatio.toFixed(2)}）`, confidence: 5 };
    },
  },

  value_invest: {
    id: 'value_invest',
    name: '价值投资',
    description: '低PE+高ROE+净利润增长 = 价值股',
    evaluate: async (indicators, prevIndicators, code) => {
      const fundamental = await getStockFundamental(code);
      if (!fundamental) return null;

      const { pe, pb, roe, netProfitGrowth } = fundamental;
      let score = 0;
      const reasons = [];

      if (pe > 0 && pe < 20) { score += 2; reasons.push(`低PE(${pe})`); }
      else if (pe > 0 && pe < 40) { score += 1; reasons.push(`中PE(${pe})`); }
      else if (pe > 40) { score -= 1; reasons.push(`高PE(${pe})`); }

      if (pb > 0 && pb < 2) { score += 2; reasons.push(`低PB(${pb})`); }
      else if (pb > 5) { score -= 1; reasons.push(`高PB(${pb})`); }

      if (roe > 15) { score += 2; reasons.push(`高ROE(${roe}%)`); }
      else if (roe > 8) { score += 1; reasons.push(`中ROE(${roe}%)`); }

      if (netProfitGrowth > 20) { score += 2; reasons.push(`高增长(${netProfitGrowth}%)`); }
      else if (netProfitGrowth > 0) { score += 1; reasons.push(`正增长(${netProfitGrowth}%)`); }
      else { score -= 1; reasons.push(`负增长(${netProfitGrowth}%)`); }

      if (score >= 5) return { signal: 'buy', reason: `价值股：${reasons.join('，')}`, confidence: 8 };
      if (score <= 0) return { signal: 'sell', reason: `估值偏高：${reasons.join('，')}`, confidence: 6 };
      return { signal: 'hold', reason: `估值一般：${reasons.join('，')}`, confidence: 5 };
    },
  },
};

class QuantService {
  constructor() {
    /** @type {Map<string, {code, name, strategies: string[], status, cronJob, signals: Array}>} */
    this.tasks = new Map();
    this.listeners = new Set();
    this.prevIndicators = new Map();
  }

  /**
   * 获取可用策略列表
   */
  getAvailableStrategies() {
    return Object.values(STRATEGIES).map(({ evaluate, ...rest }) => rest);
  }

  /**
   * 添加量化任务
   */
  addTask(code, name, strategyIds = ['macd_cross', 'ma_trend', 'rsi_oversold']) {
    const taskKey = code;
    if (this.tasks.has(taskKey)) {
      return { success: false, message: '该股票已有量化任务' };
    }

    const validStrategies = strategyIds.filter(id => STRATEGIES[id]);
    if (validStrategies.length === 0) {
      return { success: false, message: '没有有效的策略' };
    }

    this.tasks.set(taskKey, {
      code,
      name: name || code,
      strategies: validStrategies,
      status: 'stopped',
      cronJob: null,
      signals: [],
      createdAt: new Date().toISOString(),
    });

    this._notify('task_added', { code, name, strategies: validStrategies });
    return { success: true, message: `已添加量化任务: ${name || code}` };
  }

  /**
   * 删除量化任务
   */
  removeTask(code) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };

    if (task.cronJob) task.cronJob.stop();
    this.tasks.delete(code);
    this._notify('task_removed', { code });
    return { success: true, message: `已删除量化任务: ${task.name}` };
  }

  /**
   * 启动量化任务
   */
  startTask(code) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };
    if (task.status === 'running') return { success: false, message: '任务已在运行' };

    const interval = config.monitor.quantIntervalMinutes;
    const cronExpression = `*/${interval} * * * 1-5`;

    task.cronJob = cron.schedule(cronExpression, async () => {
      await this._runStrategies(code);
    }, { timezone: 'Asia/Shanghai' });

    task.status = 'running';
    this._notify('task_started', { code });

    // 立即执行一次
    this._runStrategies(code);

    return { success: true, message: `已启动量化监控，每 ${interval} 分钟执行策略` };
  }

  /**
   * 停止量化任务
   */
  stopTask(code) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };

    if (task.cronJob) {
      task.cronJob.stop();
      task.cronJob = null;
    }

    task.status = 'stopped';
    this._notify('task_stopped', { code });
    return { success: true, message: `已停止量化任务: ${task.name}` };
  }

  /**
   * 获取所有任务
   */
  getAllTasks() {
    return Array.from(this.tasks.values()).map(({ cronJob, ...rest }) => ({
      ...rest,
      signals: rest.signals.slice(-10),
    }));
  }

  /**
   * 更新任务策略
   */
  updateTaskStrategies(code, strategyIds) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };

    task.strategies = strategyIds.filter(id => STRATEGIES[id]);
    return { success: true, message: '策略已更新' };
  }

  /**
   * 运行策略分析
   */
  async _runStrategies(code) {
    const task = this.tasks.get(code);
    if (!task) return;

    try {
      this._notify('strategies_running', { code, name: task.name });

      const klines = await getStockKline(code, 'daily', 60);
      const indicators = calculateIndicators(klines);
      const prevIndicators = this.prevIndicators.get(code) || null;

      const signals = [];
      for (const strategyId of task.strategies) {
        const strategy = STRATEGIES[strategyId];
        if (!strategy) continue;

        try {
          const result = await strategy.evaluate(indicators, prevIndicators, code);
          if (result) {
            signals.push({
              strategy: strategyId,
              strategyName: strategy.name,
              ...result,
              timestamp: new Date().toISOString(),
            });
          }
        } catch (e) {
          console.error(`策略 ${strategyId} 执行失败:`, e.message);
        }
      }

      // 综合信号判断
      const buySignals = signals.filter(s => s.signal === 'buy');
      const sellSignals = signals.filter(s => s.signal === 'sell');

      let compositeSignal = 'hold';
      let compositeReason = '';

      if (buySignals.length > sellSignals.length && buySignals.length >= 2) {
        compositeSignal = 'buy';
        compositeReason = `${buySignals.length}个策略发出买入信号`;
      } else if (sellSignals.length > buySignals.length && sellSignals.length >= 2) {
        compositeSignal = 'sell';
        compositeReason = `${sellSignals.length}个策略发出卖出信号`;
      } else {
        compositeReason = '信号不一致，建议观望';
      }

      const signalResult = {
        code,
        name: task.name,
        signals,
        composite: { signal: compositeSignal, reason: compositeReason },
        price: indicators.currentPrice,
        timestamp: new Date().toISOString(),
      };

      task.signals.push(signalResult);
      if (task.signals.length > 50) {
        task.signals = task.signals.slice(-50);
      }

      this.prevIndicators.set(code, indicators);

      this._notify('strategies_completed', signalResult);
    } catch (error) {
      this._notify('strategies_error', { code, error: error.message });
    }
  }

  addListener(callback) {
    this.listeners.add(callback);
    return () => this.listeners.delete(callback);
  }

  _notify(event, data) {
    this.listeners.forEach(cb => {
      try { cb(event, data); } catch (e) { console.error('Quant listener error:', e); }
    });
  }
}

const quantService = new QuantService();
export default quantService;
