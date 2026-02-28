/**
 * 股票新闻搜索工具
 * 数据源：东方财富
 */

/**
 * 获取股票新闻
 * @param {string} code - 股票代码
 * @param {number} limit - 返回数量，默认10
 * @returns {Promise<Array>}
 */
export async function getStockNews({ code, limit = 10 }) {
  try {
    const secId = code.startsWith('6') || code.startsWith('9') 
      ? `1.${code}` 
      : `0.${code}`;
    
    const url = `https://np-anotice-stock.eastmoney.com/api-manager/notice-api/query?page=1&pageSize=${limit}&secids=${secId}&fields=title,publish_time,url`;
    
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    
    const response = await fetch(url, { signal: controller.signal });
    clearTimeout(timeout);
    
    if (!response.ok) {
      console.error('获取股票新闻失败: HTTP', response.status);
      return [];
    }
    
    const text = await response.text();
    if (!text || text.trim() === '') {
      return [];
    }
    
    const data = JSON.parse(text);

    if (!data.data || !data.data.list) {
      return [];
    }

    return data.data.list.map(item => ({
      title: item.title || '',
      publishTime: item.publish_time || '',
      url: item.url || '',
    }));
  } catch (error) {
    console.error('获取股票新闻失败:', error.message);
    return [];
  }
}

export default { getStockNews };
