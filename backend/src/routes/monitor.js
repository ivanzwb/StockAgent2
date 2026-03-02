/**
 * 监控相关 API 路由
 */
import { Router } from 'express';
import monitorService from '../services/monitorService.js';
import { getEastMoneySecId, searchStock } from '../tools/searchStock.js';
import config from '../config/index.js';

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
 * Body: { code: "600000", name: "浦发银行" } 或 { code: "贵州茅台", name: "" }
 */
router.post('/add', async (req, res) => {
  let { code, name } = req.body;
  if (!code) {
    return res.status(400).json({ error: '请提供股票代码' });
  }

  // 如果code不是纯数字，说明是股票名称，需要搜索获取股票代码
  if (!/^\d{6}$/.test(code)) {
    const results = await searchStock({ keyword: code });
    if (results.length > 0) {
      // 取第一个匹配结果
      code = results[0].code;
      name = results[0].name;
    } else {
      return res.status(404).json({ error: '未找到该股票' });
    }
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

/**
 * GET /api/monitor/config - 获取监控配置
 */
router.get('/config', (req, res) => {
  res.json({
    success: true,
    data: {
      intervalMinutes: config.monitor.intervalMinutes,
    }
  });
});

/**
 * POST /api/monitor/config - 设置监控配置
 * Body: { intervalMinutes: 10 }
 */
router.post('/config', (req, res) => {
  const { intervalMinutes } = req.body;
  if (!intervalMinutes || intervalMinutes < 1 || intervalMinutes > 60) {
    return res.status(400).json({ error: '请提供有效的间隔时间（1-60分钟）' });
  }
  config.monitor.intervalMinutes = parseInt(intervalMinutes);
  res.json({ success: true, message: `监控间隔已设置为 ${intervalMinutes} 分钟` });
});

export default router;
