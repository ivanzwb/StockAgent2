/**
 * 工具注册中心 - 管理所有 financial agent skills
 */
import { searchStock, getFullStockCode, getEastMoneySecId } from './searchStock.js';
import { getStockKline, calculateIndicators } from './kline.js';
import { getStockFundamental, getFinancialSummary } from './fundamental.js';
import { getAllSectors, getConceptSectors, getSectorStocks } from './sectors.js';
import { getStockNews } from './news.js';

// 工具定义列表
const toolDefinitions = [
  {
    id: 'search_stock',
    name: '股票搜索',
    description: '按名称搜索A股股票代码',
    enabled: true,
    category: '基础',
    fn: searchStock,
    schema: {
      name: 'search_stock',
      description: '根据关键词搜索A股股票，返回股票代码和名称列表',
      parameters: {
        type: 'object',
        properties: {
          keyword: { type: 'string', description: '股票名称或代码关键词' },
        },
        required: ['keyword'],
      },
    },
  },
  {
    id: 'get_stock_kline',
    name: 'K线数据',
    description: '获取股票日K线数据，包含开高低收、成交量',
    enabled: true,
    category: '技术分析',
    fn: async (args) => {
      const klines = await getStockKline(args.code, args.period || 'daily', args.limit || 60);
      const indicators = calculateIndicators(klines);
      return { klines: klines.slice(-20), indicators };
    },
    schema: {
      name: 'get_stock_kline',
      description: '获取股票K线数据和技术指标（MA/MACD/RSI等），用于技术分析',
      parameters: {
        type: 'object',
        properties: {
          code: { type: 'string', description: '股票代码，如 600000' },
          period: { type: 'string', description: 'K线周期：daily/weekly/monthly', default: 'daily' },
          limit: { type: 'number', description: '数据条数', default: 60 },
        },
        required: ['code'],
      },
    },
  },
  {
    id: 'get_stock_fundamental',
    name: '基本面数据',
    description: '获取股票PE/PB/ROE/市值等基本面数据',
    enabled: true,
    category: '基本面分析',
    fn: async (args) => {
      const fundamental = await getStockFundamental(args.code);
      const financial = await getFinancialSummary(args.code);
      return { fundamental, financial };
    },
    schema: {
      name: 'get_stock_fundamental',
      description: '获取股票基本面数据，包含PE/PB/ROE/市值/毛利率/净利率/增长率等',
      parameters: {
        type: 'object',
        properties: {
          code: { type: 'string', description: '股票代码，如 600000' },
        },
        required: ['code'],
      },
    },
  },
  {
    id: 'get_all_sectors',
    name: '行业板块列表',
    description: '获取A股所有行业板块列表',
    enabled: true,
    category: '板块',
    fn: getAllSectors,
    schema: {
      name: 'get_all_sectors',
      description: '获取A股所有行业板块列表，包含板块代码、名称、涨跌幅',
      parameters: {
        type: 'object',
        properties: {},
        required: [],
      },
    },
  },
  {
    id: 'get_concept_sectors',
    name: '概念板块列表',
    description: '获取A股所有概念板块列表',
    enabled: true,
    category: '板块',
    fn: getConceptSectors,
    schema: {
      name: 'get_concept_sectors',
      description: '获取A股所有概念板块列表，包含板块代码、名称、涨跌幅',
      parameters: {
        type: 'object',
        properties: {},
        required: [],
      },
    },
  },
  {
    id: 'get_sector_stocks',
    name: '板块成分股',
    description: '获取板块内的股票列表',
    enabled: true,
    category: '板块',
    fn: async (args) => {
      return await getSectorStocks(args.sectorCode, args.limit || 20);
    },
    schema: {
      name: 'get_sector_stocks',
      description: '获取指定板块的成分股列表，包含股票代码、名称、价格、涨跌幅',
      parameters: {
        type: 'object',
        properties: {
          sectorCode: { type: 'string', description: '板块代码' },
          limit: { type: 'number', description: '返回数量', default: 20 },
        },
        required: ['sectorCode'],
      },
    },
  },
  {
    id: 'get_stock_news',
    name: '股票新闻',
    description: '获取股票的最新新闻',
    enabled: true,
    category: '资讯',
    fn: getStockNews,
    schema: {
      name: 'get_stock_news',
      description: '获取指定股票的最新新闻标题列表',
      parameters: {
        type: 'object',
        properties: {
          code: { type: 'string', description: '股票代码，如 600000' },
          limit: { type: 'number', description: '返回数量', default: 10 },
        },
        required: ['code'],
      },
    },
  },
];

class ToolRegistry {
  constructor() {
    this.tools = new Map();
    toolDefinitions.forEach(tool => {
      this.tools.set(tool.id, { ...tool });
    });
  }

  /**
   * 获取所有工具的元数据
   */
  getAllTools() {
    return Array.from(this.tools.values()).map(({ fn, ...rest }) => rest);
  }

  /**
   * 获取已启用的工具
   */
  getEnabledTools() {
    return Array.from(this.tools.values()).filter(t => t.enabled);
  }

  /**
   * 启用/禁用工具
   */
  setToolEnabled(toolId, enabled) {
    const tool = this.tools.get(toolId);
    if (tool) {
      tool.enabled = enabled;
      return true;
    }
    return false;
  }

  /**
   * 执行工具
   */
  async executeTool(toolName, args) {
    const tool = Array.from(this.tools.values()).find(t => t.schema.name === toolName);
    if (!tool) {
      throw new Error(`工具 ${toolName} 不存在`);
    }
    if (!tool.enabled) {
      throw new Error(`工具 ${toolName} 已被禁用`);
    }
    return await tool.fn(args);
  }

  /**
   * 获取 LangChain 工具格式
   */
  getLangChainToolSchemas() {
    return this.getEnabledTools().map(t => t.schema);
  }
}

// 单例
const toolRegistry = new ToolRegistry();
export default toolRegistry;
export { getFullStockCode, getEastMoneySecId };
