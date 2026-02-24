/**
 * 股票分析助理 - 后端服务入口
 */
import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import config from './config/index.js';
import { initDB } from './services/dbService.js';
import monitorService from './services/monitorService.js';
import quantService from './services/quantService.js';

// Routes
import analysisRoutes from './routes/analysis.js';
import monitorRoutes from './routes/monitor.js';
import sectorRoutes from './routes/sector.js';
import quantRoutes from './routes/quant.js';
import configRoutes from './routes/config.js';

const app = express();
const server = createServer(app);

// Middleware
app.use(cors());
app.use(express.json());

// API Routes
app.use('/api', analysisRoutes);
app.use('/api/monitor', monitorRoutes);
app.use('/api/sector', sectorRoutes);
app.use('/api/quant', quantRoutes);
app.use('/api/config', configRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// WebSocket for real-time updates
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws) => {
  console.log('WebSocket 客户端已连接');

  // 注册监控事件
  const removeMonitorListener = monitorService.addListener((event, data) => {
    if (ws.readyState === ws.OPEN) {
      ws.send(JSON.stringify({ type: 'monitor', event, data }));
    }
  });

  // 注册量化事件
  const removeQuantListener = quantService.addListener((event, data) => {
    if (ws.readyState === ws.OPEN) {
      ws.send(JSON.stringify({ type: 'quant', event, data }));
    }
  });

  ws.on('message', (message) => {
    try {
      const msg = JSON.parse(message);
      console.log('收到WebSocket消息:', msg);
      // 可扩展的消息处理
    } catch (e) {
      console.error('WebSocket消息解析错误:', e.message);
    }
  });

  ws.on('close', () => {
    console.log('WebSocket 客户端已断开');
    removeMonitorListener();
    removeQuantListener();
  });
});

// 初始化并启动
async function start() {
  try {
    // 初始化数据库
    await initDB().catch(err => {
      console.warn('数据库初始化失败（非关键错误）:', err.message);
    });

    const { port, host } = config.server;
    server.listen(port, host, () => {
      console.log(`
╔══════════════════════════════════════════╗
║         炒股助理 - Stock Agent           ║
║──────────────────────────────────────────║
║  HTTP:  http://${host}:${port}              ║
║  WS:    ws://${host}:${port}/ws              ║
╚══════════════════════════════════════════╝
      `);
    });
  } catch (error) {
    console.error('服务启动失败:', error);
    process.exit(1);
  }
}

start();

export default app;
