/**
 * 板块分析服务
 * 功能3: 输入板块 → 推荐股票
 */
import toolRegistry from '../tools/index.js';
import { analyzeStock } from './analysisAgent.js';

/**
 * 获取板块列表
 * @param {string} type - 'industry' | 'concept'
 */
export async function getSectorList(type = 'industry') {
  if (type === 'concept') {
    return await toolRegistry.executeTool('get_concept_sectors', {});
  }
  return await toolRegistry.executeTool('get_all_sectors', {});
}

/**
 * 分析板块并推荐股票
 * @param {string} sectorCode - 板块代码
 * @param {number} topN - 分析前N只股票
 * @param {function} onProgress - 进度回调
 */
export async function analyzeSectorStocks(sectorCode, topN = 5, onProgress = null) {
  // 获取板块内股票
  const stocks = await toolRegistry.executeTool('get_sector_stocks', {
    sectorCode,
    limit: topN * 2, // 获取更多以便筛选
  });

  if (stocks.length === 0) {
    return { error: '未找到板块内股票' };
  }

  // 取涨跌幅排前的股票进行分析
  const topStocks = stocks
    .sort((a, b) => (b.changePercent || 0) - (a.changePercent || 0))
    .slice(0, topN);

  const results = [];
  for (let i = 0; i < topStocks.length; i++) {
    const stock = topStocks[i];
    if (onProgress) {
      onProgress({
        current: i + 1,
        total: topStocks.length,
        stock: stock.name,
      });
    }

    try {
      const analysis = await analyzeStock(stock.code);
      results.push({
        ...stock,
        analysis,
      });
    } catch (error) {
      results.push({
        ...stock,
        analysis: { error: error.message },
      });
    }
  }

  return {
    sectorCode,
    stocks: results,
    timestamp: new Date().toISOString(),
  };
}

export default { getSectorList, analyzeSectorStocks };
