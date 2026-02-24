/**
 * K线数据工具 - 获取日K线数据
 * 数据源：东方财富
 */
import { getEastMoneySecId } from './searchStock.js';

/**
 * 获取K线数据
 * @param {string} code - 股票代码 (如 600000 / sh600000)
 * @param {string} period - K线周期 daily|weekly|monthly
 * @param {number} limit - 数据条数，默认60
 * @returns {Promise<Array<{date, open, close, high, low, volume, amount, amplitude, changePercent, changeAmount, turnoverRate}>>}
 */
export async function getStockKline(code, period = 'daily', limit = 60) {
  try {
    const secId = getEastMoneySecId(code);
    const kltMap = { daily: '101', weekly: '102', monthly: '103' };
    const klt = kltMap[period] || '101';

    const url = `https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=${secId}&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=${klt}&fqt=1&end=20500101&lmt=${limit}`;

    const response = await fetch(url);
    const data = await response.json();

    if (!data.data || !data.data.klines) {
      return [];
    }

    return data.data.klines.map(line => {
      const parts = line.split(',');
      return {
        date: parts[0],
        open: parseFloat(parts[1]),
        close: parseFloat(parts[2]),
        high: parseFloat(parts[3]),
        low: parseFloat(parts[4]),
        volume: parseInt(parts[5]),
        amount: parseFloat(parts[6]),
        amplitude: parseFloat(parts[7]),
        changePercent: parseFloat(parts[8]),
        changeAmount: parseFloat(parts[9]),
        turnoverRate: parseFloat(parts[10]),
      };
    });
  } catch (error) {
    console.error('获取K线数据失败:', error.message);
    return [];
  }
}

/**
 * 计算技术指标
 * @param {Array} klines - K线数据
 * @returns {Object} 技术指标
 */
export function calculateIndicators(klines) {
  if (!klines || klines.length === 0) return {};

  const closes = klines.map(k => k.close);
  const volumes = klines.map(k => k.volume);

  // MA 均线
  const ma5 = calculateMA(closes, 5);
  const ma10 = calculateMA(closes, 10);
  const ma20 = calculateMA(closes, 20);
  const ma60 = calculateMA(closes, 60);

  // MACD
  const macd = calculateMACD(closes);

  // RSI
  const rsi = calculateRSI(closes, 14);

  // 成交量均线
  const volMa5 = calculateMA(volumes, 5);
  const volMa10 = calculateMA(volumes, 10);

  const latestClose = closes[closes.length - 1];

  return {
    currentPrice: latestClose,
    ma5: ma5[ma5.length - 1],
    ma10: ma10[ma10.length - 1],
    ma20: ma20[ma20.length - 1],
    ma60: ma60.length > 0 ? ma60[ma60.length - 1] : null,
    macd: {
      dif: macd.dif[macd.dif.length - 1],
      dea: macd.dea[macd.dea.length - 1],
      histogram: macd.histogram[macd.histogram.length - 1],
    },
    rsi: rsi[rsi.length - 1],
    volumeAvg5: volMa5[volMa5.length - 1],
    volumeAvg10: volMa10[volMa10.length - 1],
    latestVolume: volumes[volumes.length - 1],
    pricePosition: {
      aboveMa5: latestClose > (ma5[ma5.length - 1] || 0),
      aboveMa10: latestClose > (ma10[ma10.length - 1] || 0),
      aboveMa20: latestClose > (ma20[ma20.length - 1] || 0),
    },
  };
}

function calculateMA(data, period) {
  const result = [];
  for (let i = period - 1; i < data.length; i++) {
    const sum = data.slice(i - period + 1, i + 1).reduce((a, b) => a + b, 0);
    result.push(parseFloat((sum / period).toFixed(4)));
  }
  return result;
}

function calculateMACD(closes, short = 12, long = 26, signal = 9) {
  const emaShort = calculateEMA(closes, short);
  const emaLong = calculateEMA(closes, long);

  const dif = [];
  for (let i = 0; i < emaShort.length; i++) {
    const longIdx = i - (closes.length - emaLong.length);
    if (longIdx >= 0) {
      dif.push(parseFloat((emaShort[i] - emaLong[longIdx]).toFixed(4)));
    }
  }

  const dea = calculateEMA(dif, signal);
  const histogram = [];
  for (let i = 0; i < dea.length; i++) {
    const difIdx = i + (dif.length - dea.length);
    histogram.push(parseFloat(((dif[difIdx] - dea[i]) * 2).toFixed(4)));
  }

  return { dif, dea, histogram };
}

function calculateEMA(data, period) {
  if (data.length === 0) return [];
  const result = [data[0]];
  const multiplier = 2 / (period + 1);
  for (let i = 1; i < data.length; i++) {
    result.push(parseFloat(((data[i] - result[i - 1]) * multiplier + result[i - 1]).toFixed(4)));
  }
  return result;
}

function calculateRSI(closes, period = 14) {
  const changes = [];
  for (let i = 1; i < closes.length; i++) {
    changes.push(closes[i] - closes[i - 1]);
  }

  const rsi = [];
  let avgGain = 0;
  let avgLoss = 0;

  for (let i = 0; i < period; i++) {
    if (changes[i] > 0) avgGain += changes[i];
    else avgLoss += Math.abs(changes[i]);
  }
  avgGain /= period;
  avgLoss /= period;

  if (avgLoss === 0) rsi.push(100);
  else rsi.push(parseFloat((100 - 100 / (1 + avgGain / avgLoss)).toFixed(2)));

  for (let i = period; i < changes.length; i++) {
    const gain = changes[i] > 0 ? changes[i] : 0;
    const loss = changes[i] < 0 ? Math.abs(changes[i]) : 0;
    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;
    if (avgLoss === 0) rsi.push(100);
    else rsi.push(parseFloat((100 - 100 / (1 + avgGain / avgLoss)).toFixed(2)));
  }

  return rsi;
}

export default { getStockKline, calculateIndicators };
