/**
 * 股票分析 Agent - 核心分析逻辑
 * 功能1: 输入股票 → 分析 → 操作指令
 */
import { HumanMessage, SystemMessage } from '@langchain/core/messages';
import { getLLM } from './llmService.js';
import toolRegistry, { getFullStockCode, getEastMoneySecId } from '../tools/index.js';
import { saveAnalysisResult } from './dbService.js';

const SYSTEM_PROMPT = `你是一个专业的A股投资分析助手。你需要根据提供的数据进行深入分析，给出明确的操作建议。

分析框架：
1. **技术面分析**：K线形态、均线系统(MA5/MA10/MA20/MA60)、MACD、RSI、成交量
2. **基本面分析**：PE/PB估值、ROE盈利能力、营收增长、净利润增长、毛利率
3. **历史验证**：对比历史分析，验证之前判断的准确性，反思分析逻辑
4. **综合评估**：结合技术面、基本面和历史验证给出评分

输出格式：
- **操作建议**：买入 / 观望 / 卖出
- **信心指数**：1-10分
- **目标价位**：预期价格区间
- **止损价位**：建议止损价格
- **分析理由**：详细的分析说明（包含技术面和基本面）
- **风险提示**：潜在风险因素
- **历史验证**：对比历史分析结果，评估之前判断的准确性，并总结改进方向

请用中文回答，分析要客观、专业、有据可依。`;

/**
 * 获取股票实时报价
 */
async function getStockQuote(code) {
  try {
    const secId = getEastMoneySecId(code);
    const quoteUrl = `https://push2.eastmoney.com/api/qt/stock/get?secid=${secId}&fields=f43,f44,f45,f46,f47,f48,f57,f58,f60`;
    const response = await fetch(quoteUrl);
    const data = await response.json();

    if (!data.data) return null;

    return {
      currentPrice: data.data.f43 / 100,
      high: data.data.f44 / 100,
      low: data.data.f45 / 100,
      open: data.data.f46 / 100,
      volume: data.data.f47,
    };
  } catch (error) {
    console.error('获取报价失败:', error.message);
    return null;
  }
}

/**
 * 从分析文本中提取操作建议
 */
function extractSignal(analysis) {
  const text = analysis.toLowerCase();
  if (text.includes('买入') || text.includes('买') || text.includes('增持')) return '买入';
  if (text.includes('卖出') || text.includes('卖') || text.includes('减持')) return '卖出';
  return '观望';
}

/**
 * 分析单只股票
 * @param {string} input - 股票代码或名称
 * @returns {Promise<Object>} 分析结果
 */
export async function analyzeStock(input) {
  const llm = await getLLM();
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
  const [klineResult, fundamentalResult, newsResult, quote] = await Promise.all([
    toolRegistry.executeTool('get_stock_kline', { code: stockCode, period: 'daily', limit: 60 }),
    toolRegistry.executeTool('get_stock_fundamental', { code: stockCode }),
    toolRegistry.executeTool('get_stock_news', { code: stockCode, limit: 10 }),
    getStockQuote(stockCode),
  ]);

  if (!stockName && fundamentalResult.fundamental) {
    stockName = fundamentalResult.fundamental.name;
  }

  // 获取历史分析结果（从数据库）
  let historyText = '';
  try {
    const { getAnalysisHistory } = await import('./dbService.js');
    const historyResults = await getAnalysisHistory(stockCode, 5);

    if (historyResults.length > 0) {
      const currentPrice = quote?.currentPrice || 0;

      historyText = '\n**历史分析记录**:\n';
      for (const hist of historyResults.slice(-3)) {
        const signal = extractSignal(hist.analysis);
        const priceInfo = hist.data?.kline?.klines?.[-1];
        const oldPrice = priceInfo?.close || 0;
        const priceChange = oldPrice > 0 ? ((currentPrice - oldPrice) / oldPrice * 100).toFixed(2) : 'N/A';

        historyText += `
---
【${hist.timestamp.split('T')[0]}】建议: ${signal}
当时价格: ${oldPrice || 'N/A'}，当前价格: ${currentPrice || 'N/A'}，涨跌: ${priceChange}%
分析摘要: ${hist.analysis.substring(0, 300)}...
`;
      }

      historyText += '\n请结合以上历史分析，验证之前的判断是否准确，反思分析逻辑的优劣，并给出改进方向。';
    }
  } catch (error) {
    console.error('获取历史分析失败:', error.message);
  }

  // 构建分析提示
  const newsText = newsResult.length > 0
    ? `**近期新闻**：\n${newsResult.map((n, i) => `${i + 1}. ${n.title}`).join('\n')}\n\n`
    : '';

  const quoteText = quote
    ? `**当前行情**：\n- 当前价格: ${quote.currentPrice}\n- 开盘价: ${quote.open}\n- 最高价: ${quote.high}\n- 最低价: ${quote.low}\n- 成交量: ${(quote.volume / 10000).toFixed(0)}万\n\n`
    : '';

  const dataPrompt = `
请分析以下股票数据并给出操作建议：

**股票**: ${stockName}(${stockCode})

${quoteText}${newsText}**技术面数据**：
- 最近20日K线: ${JSON.stringify(klineResult.klines?.slice(-10) || [])}
- 技术指标: ${JSON.stringify(klineResult.indicators || {})}

**基本面数据**：
- 核心指标: ${JSON.stringify(fundamentalResult.fundamental || {})}
- 财务数据: ${JSON.stringify(fundamentalResult.financial || [])}

${historyText}

请按照分析框架进行全面分析，结合新闻资讯和历史验证，给出明确的操作建议。`;

  const messages = [
    new SystemMessage(SYSTEM_PROMPT),
    new HumanMessage(dataPrompt),
  ];

  let response;
  try {
    response = await llm.invoke(messages);
  } catch (error) {
    throw new Error(`大模型分析失败: ${error.message}`);
  }

  const result = {
    code: stockCode,
    name: stockName,
    fullCode: getFullStockCode(stockCode),
    analysis: response.content,
    data: {
      kline: klineResult,
      fundamental: fundamentalResult,
      quote: quote,
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
