/**
 * 监控服务
 * 功能2: 股票监控，定时分析
 */
import cron from 'node-cron';
import { analyzeStock } from './analysisAgent.js';
import config from '../config/index.js';
import { saveMonitor, deleteMonitor, getAllMonitors } from './dbService.js';

class MonitorService {
  constructor() {
    /** @type {Map<string, {code: string, name: string, status: 'running'|'stopped', cronJob: any, results: Array}>} */
    this.monitors = new Map();
    this.listeners = new Set();
    this._initialized = false;
  }

  /**
   * 初始化，从数据库加载监控数据
   */
  async init() {
    if (this._initialized) return;
    this._initialized = true;

    try {
      const savedMonitors = await getAllMonitors();
      for (const m of savedMonitors) {
        this.monitors.set(m.code, {
          code: m.code,
          name: m.name,
          status: 'stopped', // 不自动启动
          cronJob: null,
          results: m.results || [],
          createdAt: m.createdAt,
        });
        console.log(`加载监控: ${m.name} (${m.code})`);
      }
    } catch (error) {
      console.error('加载监控数据失败:', error.message);
    }
  }

  /**
   * 添加监控
   */
  async addMonitor(code, name) {
    if (this.monitors.has(code)) {
      return { success: false, message: '该股票已在监控列表中' };
    }

    const createdAt = new Date().toISOString();
    this.monitors.set(code, {
      code,
      name: name || code,
      status: 'stopped',
      cronJob: null,
      results: [],
      createdAt,
    });

    // 保存到数据库
    await saveMonitor({ code, name: name || code, status: 'stopped', createdAt, results: [] });

    this._notify('monitor_added', { code, name });
    return { success: true, message: `已添加 ${name || code} 到监控列表` };
  }

  /**
   * 删除监控
   */
  async removeMonitor(code) {
    const monitor = this.monitors.get(code);
    if (!monitor) {
      return { success: false, message: '未找到该监控' };
    }

    if (monitor.cronJob) {
      monitor.cronJob.stop();
    }

    this.monitors.delete(code);
    
    // 从数据库删除
    await deleteMonitor(code);

    this._notify('monitor_removed', { code });
    return { success: true, message: `已移除 ${monitor.name} 的监控` };
  }

  /**
   * 启动监控
   */
  startMonitor(code) {
    const monitor = this.monitors.get(code);
    if (!monitor) {
      return { success: false, message: '未找到该监控' };
    }

    if (monitor.status === 'running') {
      return { success: false, message: '该监控已在运行中' };
    }

    const intervalMinutes = config.monitor.intervalMinutes;
    const cronExpression = `*/${intervalMinutes} * * * 1-5`; // 工作日每N分钟

    monitor.cronJob = cron.schedule(cronExpression, async () => {
      await this._runAnalysis(code);
    }, {
      timezone: 'Asia/Shanghai',
    });

    monitor.status = 'running';
    
    // 保存到数据库
    saveMonitor(monitor);

    this._notify('monitor_started', { code });

    // 立即执行一次分析
    this._runAnalysis(code);

    return { success: true, message: `已启动 ${monitor.name} 的监控，每 ${intervalMinutes} 分钟分析一次` };
  }

  /**
   * 停止监控
   */
  stopMonitor(code) {
    const monitor = this.monitors.get(code);
    if (!monitor) {
      return { success: false, message: '未找到该监控' };
    }

    if (monitor.cronJob) {
      monitor.cronJob.stop();
      monitor.cronJob = null;
    }

    monitor.status = 'stopped';
    
    // 保存到数据库
    saveMonitor(monitor);

    this._notify('monitor_stopped', { code });
    return { success: true, message: `已停止 ${monitor.name} 的监控` };
  }

  /**
   * 获取所有监控列表
   */
  getAllMonitors() {
    return Array.from(this.monitors.values()).map(({ cronJob, ...rest }) => ({
      ...rest,
      results: (rest.results || []).slice(-5), // 只返回最近5条
    }));
  }

  /**
   * 注册事件监听器
   */
  addListener(callback) {
    this.listeners.add(callback);
    return () => this.listeners.delete(callback);
  }

  /**
   * 执行分析
   */
  async _runAnalysis(code) {
    const monitor = this.monitors.get(code);
    if (!monitor) return;

    try {
      this._notify('analysis_started', { code, name: monitor.name });

      const result = await analyzeStock(code);

      monitor.results.push({
        ...result,
        monitorTimestamp: new Date().toISOString(),
      });

      // 保留最近20条结果
      if (monitor.results.length > 20) {
        monitor.results = monitor.results.slice(-20);
      }

      // 保存到数据库
      saveMonitor(monitor);

      this._notify('analysis_completed', {
        code,
        name: monitor.name,
        result,
      });
    } catch (error) {
      this._notify('analysis_error', {
        code,
        name: monitor.name,
        error: error.message,
      });
    }
  }

  /**
   * 通知监听器
   */
  _notify(event, data) {
    this.listeners.forEach(cb => {
      try {
        cb(event, data);
      } catch (e) {
        console.error('Monitor listener error:', e);
      }
    });
  }
}

// 单例
const monitorService = new MonitorService();
export default monitorService;
