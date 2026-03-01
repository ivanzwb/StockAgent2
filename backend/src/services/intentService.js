/**
 * 意图识别服务 - 分析用户输入，路由到对应功能
 */
import { HumanMessage, SystemMessage } from '@langchain/core/messages';
import { getLLM } from './llmService.js';

const INTENT_PROMPT = `你是一个意图识别助手。分析用户的输入，判断属于以下哪个功能：

1. analyze - 输入股票，分析并给出操作指令（买入/观望/卖出）
2. monitor - 输入股票，要求监控，定时分析给出建议
3. sector - 输入板块，要求推荐该板块的股票
4. quant - 输入股票，要求启动量化策略

回复格式（纯JSON，不要有其他内容）：
{
  "intent": "analyze|monitor|sector|quant",
  "stocks": ["股票名称或代码"],
  "sector": "板块名称（如果有）",
  "sectorType": "industry|concept",
  "action": "add|remove|start|stop|list|null",
  "strategies": ["strategy_id"],
  "rawInput": "用户原始输入"
}

示例：
- "分析贵州茅台" → {"intent":"analyze","stocks":["贵州茅台"],"sector":"","sectorType":"","action":null,"strategies":[],"rawInput":"分析贵州茅台"}
- "监控600000和000001" → {"intent":"monitor","stocks":["600000","000001"],"sector":"","sectorType":"","action":"add","strategies":[],"rawInput":"..."}
- "推荐半导体板块的股票" → {"intent":"sector","stocks":[],"sector":"半导体","sectorType":"concept","action":null,"strategies":[],"rawInput":"..."}
- "用MACD策略监控平安银行" → {"intent":"quant","stocks":["平安银行"],"sector":"","sectorType":"","action":"add","strategies":["macd_cross"],"rawInput":"..."}
- "停止监控茅台" → {"intent":"monitor","stocks":["茅台"],"sector":"","sectorType":"","action":"stop","strategies":[],"rawInput":"..."}`;

/**
 * 识别用户意图
 * @param {string} input - 用户输入
 * @returns {Promise<Object>} 解析后的意图
 */
export async function recognizeIntent(input) {
  try {
    const llm = getLLM();
    const messages = [
      new SystemMessage(INTENT_PROMPT),
      new HumanMessage(input),
    ];

    const response = await llm.invoke(messages);
    const content = response.content.trim();

    // 提取 JSON
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }

    // 简单的规则兜底
    return fallbackIntentRecognition(input);
  } catch (error) {
    console.error('意图识别失败:', error.message);
    throw new Error(`意图识别失败: ${error.message}`);
  }
}

/**
 * 规则兜底的意图识别
 */
function fallbackIntentRecognition(input) {
  const result = {
    intent: 'analyze',
    stocks: [],
    sector: '',
    sectorType: '',
    action: null,
    strategies: [],
    rawInput: input,
  };

  // 检测意图
  if (/监控|跟踪|盯/.test(input) && /量化|策略|macd|rsi|均线/.test(input)) {
    result.intent = 'quant';
    result.action = 'add';
  } else if (/监控|跟踪|盯/.test(input)) {
    result.intent = 'monitor';
    result.action = 'add';
  } else if (/板块|行业|概念|推荐/.test(input)) {
    result.intent = 'sector';
    if (/概念/.test(input)) result.sectorType = 'concept';
    else result.sectorType = 'industry';
  }

  // action
  if (/停止|暂停|关闭/.test(input)) result.action = 'stop';
  if (/启动|开始|继续/.test(input)) result.action = 'start';
  if (/删除|移除|取消/.test(input)) result.action = 'remove';
  if (/列表|查看|显示/.test(input)) result.action = 'list';

  // 提取股票（简单的6位数字匹配）
  const codeMatches = input.match(/\d{6}/g);
  if (codeMatches) {
    result.stocks = codeMatches;
  } else {
    // 去除关键词后剩余的可能是股票名称
    const cleaned = input.replace(/(分析|监控|推荐|板块|行业|概念|跟踪|盯|量化|策略|停止|启动|删除|的|股票|和|，|,)/g, ' ').trim();
    const parts = cleaned.split(/\s+/).filter(Boolean);
    if (parts.length > 0 && result.intent !== 'sector') {
      result.stocks = parts;
    }
    if (result.intent === 'sector' && parts.length > 0) {
      result.sector = parts[0];
    }
  }

  return result;
}

export default { recognizeIntent };
