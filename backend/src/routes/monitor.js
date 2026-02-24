/**
 * 监控相关 API 路由
 */
import { Router } from 'express';
import monitorService from '../services/monitorService.js';

const router = Router();

/**
 * GET /api/monitor - 获取监控列表
 */
router.get('/', (req, res) => {
  const monitors = monitorService.getAllMonitors();
  res.json({ success: true, data: monitors });
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
