/**
 * 量化策略 API 路由
 */
import { Router } from 'express';
import quantService from '../services/quantService.js';
import backtestService from '../services/backtestService.js';

const STRATEGIES = quantService.getStrategies?.() || {};

const router = Router();

/**
 * GET /api/quant/strategies - 获取可用策略列表
 */
router.get('/strategies', (req, res) => {
  const strategies = quantService.getAvailableStrategies();
  res.json({ success: true, data: strategies });
});

/**
 * GET /api/quant/tasks - 获取量化任务列表
 */
router.get('/tasks', (req, res) => {
  const tasks = quantService.getAllTasks();
  res.json({ success: true, data: tasks });
});

/**
 * POST /api/quant/add - 添加量化任务
 * Body: { code: "600000", name: "浦发银行", strategies: ["macd_cross", "rsi_oversold"], riskControl: {...} }
 */
router.post('/add', (req, res) => {
  const { code, name, strategies, riskControl } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  const result = quantService.addTask(code, name, strategies, riskControl);
  res.json(result);
});

/**
 * POST /api/quant/remove - 删除量化任务
 * Body: { code: "600000" }
 */
router.post('/remove', (req, res) => {
  const { code } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  const result = quantService.removeTask(code);
  res.json(result);
});

/**
 * POST /api/quant/start - 启动量化任务
 * Body: { code: "600000" }
 */
router.post('/start', (req, res) => {
  const { code } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  const result = quantService.startTask(code);
  res.json(result);
});

/**
 * POST /api/quant/stop - 停止量化任务
 * Body: { code: "600000" }
 */
router.post('/stop', (req, res) => {
  const { code } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  const result = quantService.stopTask(code);
  res.json(result);
});

/**
 * PUT /api/quant/strategies/:code - 更新任务策略
 * Body: { strategies: ["macd_cross", "ma_trend"] }
 */
router.put('/strategies/:code', (req, res) => {
  const { code } = req.params;
  const { strategies } = req.body;
  const result = quantService.updateTaskStrategies(code, strategies);
  res.json(result);
});

/**
 * PUT /api/quant/riskcontrol/:code - 更新风控参数
 * Body: { stopLossPercent: -5, takeProfitPercent: 10, maxPositionPercent: 30, enableStopLoss: true, enableTakeProfit: true, signalConfirmCount: 1 }
 */
router.put('/riskcontrol/:code', (req, res) => {
  const { code } = req.params;
  const riskControl = req.body;
  const result = quantService.updateRiskControl(code, riskControl);
  res.json(result);
});

/**
 * GET /api/quant/position/:code - 获取持仓状态
 */
router.get('/position/:code', (req, res) => {
  const { code } = req.params;
  const position = quantService.getPosition(code);
  res.json({ success: true, data: position });
});

/**
 * PUT /api/quant/position/:code - 更新持仓状态
 * Body: { entryPrice: 10.5, quantity: 1000, positionType: "long", entryDate: "2024-01-01" }
 */
router.put('/position/:code', (req, res) => {
  const { code } = req.params;
  const positionData = req.body;
  const result = quantService.updatePosition(code, positionData);
  res.json(result);
});

/**
 * POST /api/quant/backtest - 回测分析
 * Body: { code: "600000", strategies: ["macd_cross", "ma_trend"], days: 60 }
 */
router.post('/backtest', async (req, res) => {
  const { code, strategies, days } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  
  const { setStrategies } = await import('../services/backtestService.js');
  setStrategies(STRATEGIES);
  
  try {
    const result = await backtestService.backtest(code, strategies, days || 60);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/quant/signalstats/:code - 信号统计
 * Query: ?strategies=macd_cross,ma_trend&days=30
 */
router.get('/signalstats/:code', async (req, res) => {
  const { code } = req.params;
  const { strategies, days } = req.query;
  
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }

  const { setStrategies } = await import('../services/backtestService.js');
  setStrategies(STRATEGIES);
  
  try {
    const strategyList = strategies ? strategies.split(',') : ['macd_cross', 'ma_trend', 'rsi_oversold'];
    const result = await backtestService.getSignalStats(code, strategyList, parseInt(days) || 30);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/quant/multiperiod/:code - 多周期分析
 */
router.get('/multiperiod/:code', async (req, res) => {
  const { code } = req.params;
  
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }

  try {
    const { getStockKline, calculateIndicators } = await import('../tools/kline.js');
    
    const dailyKlines = await getStockKline(code, 'daily', 30);
    const weeklyKlines = await getStockKline(code, 'weekly', 20);
    const monthlyKlines = await getStockKline(code, 'monthly', 10);

    const daily = calculateIndicators(dailyKlines);
    const weekly = calculateIndicators(weeklyKlines);
    const monthly = calculateIndicators(monthlyKlines);

    const getMACDSignal = (macd) => {
      if (!macd) return '无信号';
      if (macd.dif > macd.dea) return '多头';
      if (macd.dif < macd.dea) return '空头';
      return '无信号';
    };

    const getTrendSignal = (ma5, ma10, ma20) => {
      if (!ma5 || !ma10 || !ma20) return '无信号';
      if (ma5 > ma10 && ma10 > ma20) return '多头';
      if (ma5 < ma10 && ma10 < ma20) return '空头';
      return '震荡';
    };

    res.json({
      success: true,
      data: {
        daily: {
          price: daily.currentPrice,
          macd: getMACDSignal(daily.macd),
          trend: getTrendSignal(daily.ma5, daily.ma10, daily.ma20),
          rsi: daily.rsi?.toFixed(2),
        },
        weekly: {
          price: weekly.currentPrice,
          macd: getMACDSignal(weekly.macd),
          trend: getTrendSignal(weekly.ma5, weekly.ma10, weekly.ma20),
          rsi: weekly.rsi?.toFixed(2),
        },
        monthly: {
          price: monthly.currentPrice,
          macd: getMACDSignal(monthly.macd),
          trend: getTrendSignal(monthly.ma5, monthly.ma10, monthly.ma20),
          rsi: monthly.rsi?.toFixed(2),
        },
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
