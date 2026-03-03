/**
 * 板块工具 - 获取行业/概念板块及其成分股
 * 数据源：东方财富
 */

/**
 * 获取所有行业板块
 * @returns {Promise<Array<{code: string, name: string, changePercent: number, leaderStock: string}>>}
 */
export async function getAllSectors() {
  try {
    const url = `https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=100&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:2&fields=f2,f3,f4,f12,f14,f128,f136,f140`;
    const response = await fetch(url);
    const data = await response.json();

    if (!data.data || !data.data.diff) {
      throw new Error('获取行业板块失败: 无数据');
    }

    return data.data.diff.map(item => ({
      code: item.f12,
      name: item.f14,
      changePercent: item.f3,
      leaderStock: item.f128 || item.f140 || '',
      price: item.f2,
    }));
  } catch (error) {
    console.error('获取行业板块失败:', error.message);
    throw new Error(`获取行业板块失败: ${error.message}`);
  }
}

/**
 * 获取所有概念板块
 * @returns {Promise<Array<{code: string, name: string, changePercent: number, leaderStock: string}>>}
 */
export async function getConceptSectors() {
  try {
    const url = `https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=200&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:3&fields=f2,f3,f4,f12,f14,f128,f136,f140`;
    const response = await fetch(url);
    const data = await response.json();

    if (!data.data || !data.data.diff) {
      throw new Error('获取概念板块失败: 无数据');
    }

    return data.data.diff.map(item => ({
      code: item.f12,
      name: item.f14,
      changePercent: item.f3,
      leaderStock: item.f128 || item.f140 || '',
      price: item.f2,
    }));
  } catch (error) {
    console.error('获取概念板块失败:', error.message);
    throw new Error(`获取概念板块失败: ${error.message}`);
  }
}

/**
 * 获取板块内股票列表
 * @param {string} sectorCode - 板块代码
 * @param {number} limit - 返回数量，默认20
 * @returns {Promise<Array<{code: string, name: string, price: number, changePercent: number}>>}
 */
export async function getSectorStocks(sectorCode, limit = 20) {
  try {
    const url = `https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=${limit}&po=1&np=1&fltt=2&invt=2&fid=f3&fs=b:${sectorCode}&fields=f2,f3,f4,f12,f14,f15,f16,f17,f18`;
    const response = await fetch(url);
    const data = await response.json();

    if (!data.data || !data.data.diff) {
      throw new Error('获取板块股票失败: 无数据');
    }

    return data.data.diff.map(item => ({
      code: item.f12,
      name: item.f14,
      price: item.f2,
      changePercent: item.f3,
      high: item.f15,
      low: item.f16,
      open: item.f17,
      preClose: item.f18,
    }));
  } catch (error) {
    console.error('获取板块股票失败:', error.message);
    throw new Error(`获取板块股票失败: ${error.message}`);
  }
}

export default { getAllSectors, getConceptSectors, getSectorStocks };
