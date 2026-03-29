/**
 * 股票搜索工具 - 按名称搜索股票代码
 * 数据源：东方财富
 */

/**
 * 搜索股票
 * @param {string} keyword - 股票名称或关键词
 * @returns {Promise<Array<{code: string, name: string, market: string}>>}
 */
export async function searchStock({ keyword }) {
  try {
    const url = `https://searchapi.eastmoney.com/api/suggest/get?input=${encodeURIComponent(keyword)}&type=14&token=D43BF722C8E33BDC906FB84D85E326E8&count=10`;
    const response = await fetch(url);
    const data = await response.json();

    if (!data.QuotationCodeTable || !data.QuotationCodeTable.Data) {
      throw new Error('搜索股票失败: 未找到结果');
    }

    const results = data.QuotationCodeTable.Data
      .filter(item => item.SecurityTypeName === '沪A' || item.SecurityTypeName === '深A')
      .map(item => ({
        code: item.Code,
        name: item.Name,
        market: item.SecurityTypeName,
        fullCode: item.QuoteID,
      }));
    
    if (results.length === 0) {
      throw new Error('搜索股票失败: 未找到A股');
    }
    
    return results;
  } catch (error) {
    console.error('搜索股票失败:', error.message);
    throw new Error(`搜索股票失败: ${error.message}`);
  }
}

/**
 * 获取股票代码的完整格式 (sh/sz前缀)
 * @param {string} code - 股票代码
 * @returns {string} 完整代码，如 sh600000
 */
export function getFullStockCode(code) {
  const codeStr = code.replace(/^(sh|sz|SH|SZ)/, '');
  if (codeStr.startsWith('6') || codeStr.startsWith('9')) {
    return `sh${codeStr}`;
  }
  return `sz${codeStr}`;
}

/**
 * 获取东方财富的 secid 格式
 * @param {string} code - 股票代码
 * @returns {string}
 */
export function getEastMoneySecId(code) {
  const codeStr = code.replace(/^(sh|sz|SH|SZ)/, '');
  if (codeStr.startsWith('6') || codeStr.startsWith('9')) {
    return `1.${codeStr}`;
  }
  return `0.${codeStr}`;
}

export default { searchStock, getFullStockCode, getEastMoneySecId };
