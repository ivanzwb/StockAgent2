/**
 * 分析相关 API 路由
 */
import { Router } from 'express';
import { analyzeStock, analyzeMultipleStocks } from '../services/analysisAgent.js';
import { recognizeIntent } from '../services/intentService.js';
import { getAnalysisHistory, getAllAnalysisHistory } from '../services/dbService.js';

const router = Router();

/**
 * POST /api/analyze - 分析股票
 * Body: { stock: "600000" | "贵州茅台" }
 */
router.post('/analyze', async (req, res) => {
  try {
    const { stock } = req.body;
    if (!stock) {
      return res.status(400).json({ error: '请提供股票代码或名称' });
    }
    const result = await analyzeStock(stock);
    res.json({ success: true, data: result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/analyze/batch - 批量分析
 * Body: { stocks: ["600000", "000001"] }
 */
router.post('/analyze/batch', async (req, res) => {
  try {
    const { stocks } = req.body;
    if (!stocks || !Array.isArray(stocks)) {
      return res.status(400).json({ error: '请提供股票列表' });
    }
    const results = await analyzeMultipleStocks(stocks);
    res.json({ success: true, data: results });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/chat - 聊天式交互（自动意图识别）
 * Body: { message: "分析贵州茅台" }
 */
router.post('/chat', async (req, res) => {
  try {
    const { message } = req.body;
    if (!message) {
      return res.status(400).json({ error: '请提供消息内容' });
    }
    const intent = await recognizeIntent(message);
    res.json({ success: true, data: { intent } });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/history/:code - 获取分析历史
 */
router.get('/history/:code', async (req, res) => {
  try {
    const { code } = req.params;
    const limit = parseInt(req.query.limit) || 10;
    const history = await getAnalysisHistory(code, limit);
    res.json({ success: true, data: history });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/history - 获取所有分析历史
 */
router.get('/history', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const history = await getAllAnalysisHistory(limit);
    res.json({ success: true, data: history });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
