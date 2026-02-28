/**
 * 监控相关 API 路由
 */
import { Router } from 'express';
import monitorService from '../services/monitorService.js';
import { getEastMoneySecId } from '../tools/searchStock.js';

const router = Router();

/**
 * GET /api/monitor - 获取监控列表
 */
router.get('/', (req, res) => {
  const monitors = monitorService.getAllMonitors();
  res.json({ success: true, data: monitors });
});

/**
 * GET /api/monitor/quote/:code - 获取股票实时行情
 */
router.get('/quote/:code', async (req, res) => {
  const { code } = req.params;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }

  try {
    const secId = getEastMoneySecId(code);
    const quoteUrl = `https://push2.eastmoney.com/api/qt/stock/get?secid=${secId}&fields=f43,f44,f45,f46,f47,f48,f50,f57,f58,f60,f169,f170`;
    const quoteResponse = await fetch(quoteUrl);
    const quoteData = await quoteResponse.json();

    if (!quoteData.data) {
      return res.status(404).json({ error: '未找到股票' });
    }

    const d = quoteData.data;
    res.json({
      success: true,
      data: {
        code: d.f57,
        name: d.f58,
        currentPrice: d.f43 / 100,
        changePercent: d.f170 / 100,
        changeAmount: d.f169 / 100,
        high: d.f44 / 100,
        low: d.f45 / 100,
        open: d.f46 / 100,
        volume: d.f47,
        amount: d.f48,
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/monitor/add - 添加监控
 * Body: { code: "600000", name: "浦发银行" }
 */
router.post('/add', (req, res) => {
  const { code, name } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  const result = monitorService.addMonitor(code, name);
  res.json(result);
});

/**
 * POST /api/monitor/remove - 删除监控
 * Body: { code: "600000" }
 */
router.post('/remove', (req, res) => {
  const { code } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  const result = monitorService.removeMonitor(code);
  res.json(result);
});

/**
 * POST /api/monitor/start - 启动监控
 * Body: { code: "600000" }
 */
router.post('/start', (req, res) => {
  const { code } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  const result = monitorService.startMonitor(code);
  res.json(result);
});

/**
 * POST /api/monitor/stop - 停止监控
 * Body: { code: "600000" }
 */
router.post('/stop', (req, res) => {
  const { code } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }
  const result = monitorService.stopMonitor(code);
  res.json(result);
});

export default router;
