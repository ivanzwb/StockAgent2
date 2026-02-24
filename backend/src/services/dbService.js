/**
 * 数据库服务 - LanceDB 存储分析结果
 */
import { connect } from '@lancedb/lancedb';
import config from '../config/index.js';
import { mkdirSync, existsSync } from 'fs';

let db = null;

/**
 * 初始化数据库
 */
export async function initDB() {
  const dbPath = config.db.path;
  if (!existsSync(dbPath)) {
    mkdirSync(dbPath, { recursive: true });
  }
  db = await connect(dbPath);

  // 确保表存在
  const tables = await db.tableNames();

  if (!tables.includes('analysis_results')) {
    await db.createEmptyTable('analysis_results', [
      { name: 'id', type: 'string' },
      { name: 'code', type: 'string' },
      { name: 'name', type: 'string' },
      { name: 'analysis', type: 'string' },
      { name: 'timestamp', type: 'string' },
      { name: 'data_json', type: 'string' },
    ]).catch(() => {
      // 如果 createEmptyTable 不支持，使用 createTable
      return db.createTable('analysis_results', [{
        id: 'init',
        code: '',
        name: '',
        analysis: '',
        timestamp: new Date().toISOString(),
        data_json: '{}',
      }]);
    });
  }

  return db;
}

/**
 * 保存分析结果
 */
export async function saveAnalysisResult(result) {
  try {
    if (!db) await initDB();

    const table = await db.openTable('analysis_results');
    await table.add([{
      id: `${result.code}_${Date.now()}`,
      code: result.code || '',
      name: result.name || '',
      analysis: result.analysis || '',
      timestamp: result.timestamp || new Date().toISOString(),
      data_json: JSON.stringify(result.data || {}),
    }]);
  } catch (error) {
    console.error('保存分析结果失败:', error.message);
    // Non-critical, don't throw
  }
}

/**
 * 查询分析历史
 */
export async function getAnalysisHistory(code, limit = 10) {
  try {
    if (!db) await initDB();

    const table = await db.openTable('analysis_results');
    const results = await table
      .filter(`code = '${code}'`)
      .limit(limit)
      .toArray();

    return results.map(r => ({
      ...r,
      data: JSON.parse(r.data_json || '{}'),
    }));
  } catch (error) {
    console.error('查询分析历史失败:', error.message);
    return [];
  }
}

/**
 * 获取所有分析历史
 */
export async function getAllAnalysisHistory(limit = 50) {
  try {
    if (!db) await initDB();

    const table = await db.openTable('analysis_results');
    const results = await table.limit(limit).toArray();

    return results.map(r => ({
      ...r,
      data: JSON.parse(r.data_json || '{}'),
    }));
  } catch (error) {
    console.error('查询所有分析历史失败:', error.message);
    return [];
  }
}

export default { initDB, saveAnalysisResult, getAnalysisHistory, getAllAnalysisHistory };
