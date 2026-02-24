/**
 * 股票分析 Agent - 核心分析逻辑
 * 功能1: 输入股票 → 分析 → 操作指令
 */
import { HumanMessage, SystemMessage } from '@langchain/core/messages';
import { getLLM } from './llmService.js';
import toolRegistry, { getFullStockCode } from '../tools/index.js';
import { saveAnalysisResult } from './dbService.js';

const SYSTEM_PROMPT = `你是一个专业的A股投资分析助手。你需要根据提供的数据进行深入分析，给出明确的操作建议。

分析框架：
1. **技术面分析**：K线形态、均线系统(MA5/MA10/MA20/MA60)、MACD、RSI、成交量
2. **基本面分析**：PE/PB估值、ROE盈利能力、营收增长、净利润增长、毛利率
3. **综合评估**：结合技术面和基本面给出评分

输出格式：
- **操作建议**：买入 / 观望 / 卖出
- **信心指数**：1-10分
- **目标价位**：预期价格区间
- **止损价位**：建议止损价格
- **分析理由**：详细的分析说明（包含技术面和基本面）
- **风险提示**：潜在风险因素

请用中文回答，分析要客观、专业、有据可依。`;

/**
 * 分析单只股票
 * @param {string} input - 股票代码或名称
 * @returns {Promise<Object>} 分析结果
 */
export async function analyzeStock(input) {
  const llm = getLLM();
  let stockCode = input.replace(/\s/g, '');
  let stockName = '';

  // 如果输入不是纯数字，先搜索股票代码
  if (!/^\d{6}$/.test(stockCode)) {
    const results = await toolRegistry.executeTool('search_stock', { keyword: stockCode });
    if (results.length === 0) {
      return { error: `未找到股票: ${input}` };
    }
    stockCode = results[0].code;
    stockName = results[0].name;
  }

  // 收集数据
  const [klineResult, fundamentalResult] = await Promise.all([
    toolRegistry.executeTool('get_stock_kline', { code: stockCode, period: 'daily', limit: 60 }),
    toolRegistry.executeTool('get_stock_fundamental', { code: stockCode }),
  ]);

  if (!stockName && fundamentalResult.fundamental) {
    stockName = fundamentalResult.fundamental.name;
  }

  // 构建分析提示
  const dataPrompt = `
请分析以下股票数据并给出操作建议：

**股票**: ${stockName}(${stockCode})

**技术面数据**：
- 最近20日K线: ${JSON.stringify(klineResult.klines?.slice(-10) || [])}
- 技术指标: ${JSON.stringify(klineResult.indicators || {})}

**基本面数据**：
- 核心指标: ${JSON.stringify(fundamentalResult.fundamental || {})}
- 财务数据: ${JSON.stringify(fundamentalResult.financial || [])}

请按照分析框架进行全面分析，给出明确的操作建议。`;

  const messages = [
    new SystemMessage(SYSTEM_PROMPT),
    new HumanMessage(dataPrompt),
  ];

  const response = await llm.invoke(messages);

  const result = {
    code: stockCode,
    name: stockName,
    fullCode: getFullStockCode(stockCode),
    analysis: response.content,
    data: {
      kline: klineResult,
      fundamental: fundamentalResult,
    },
    timestamp: new Date().toISOString(),
  };

  // 保存结果
  await saveAnalysisResult(result);

  return result;
}

/**
 * 批量分析股票
 */
export async function analyzeMultipleStocks(inputs) {
  const results = [];
  for (const input of inputs) {
    try {
      const result = await analyzeStock(input);
      results.push(result);
    } catch (error) {
      results.push({ input, error: error.message });
    }
  }
  return results;
}

export default { analyzeStock, analyzeMultipleStocks };
