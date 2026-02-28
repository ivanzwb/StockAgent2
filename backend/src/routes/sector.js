/**
 * 板块相关 API 路由
 */
import { Router } from 'express';
import { getSectorList, analyzeSectorStocks } from '../services/sectorService.js';

const router = Router();

/**
 * GET /api/sector/list - 获取板块列表
 * Query: type=industry|concept
 */
router.get('/list', async (req, res) => {
  try {
    const type = req.query.type || 'industry';
    const sectors = await getSectorList(type);
    res.json({ success: true, data: sectors });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/sector/analyze - 分析板块，推荐股票（支持 SSE 进度）
 * Body: { sectorCode: "BK0001", topN: 5 }
 */
router.post('/analyze', async (req, res) => {
  const { sectorCode, topN = 5 } = req.body;
  
  if (!sectorCode) {
    return res.status(400).json({ error: '请提供板块代码' });
  }

  const accept = req.headers.accept || '';
  if (accept.includes('text/event-stream') || req.query.sse === 'true') {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    try {
      const result = await analyzeSectorStocks(sectorCode, topN, (progress) => {
        res.write(`data: ${JSON.stringify({ type: 'progress', ...progress })}\n\n`);
      });
      res.write(`data: ${JSON.stringify({ type: 'done', result })}\n\n`);
    } catch (error) {
      res.write(`data: ${JSON.stringify({ type: 'error', message: error.message })}\n\n`);
    }
    res.end();
  } else {
    try {
      const result = await analyzeSectorStocks(sectorCode, topN);
      res.json({ success: true, data: result });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
});

export default router;
