/**
 * 量化策略 API 路由
 */
import { Router } from 'express';
import quantService from '../services/quantService.js';

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
 * Body: { code: "600000", name: "浦发银行", strategies: ["macd_cross", "rsi_oversold"] }
 */
router.post('/add', (req, res) => {
  const { code, name, strategies } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  const result = quantService.addTask(code, name, strategies);
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

export default router;
