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
    throw new Error(`获取K线数据失败: ${error.message}`);
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

  // KDJ
  const kdj = calculateKDJ(klines);

  // 布林带
  const boll = calculateBOLL(closes);

  // CCI
  const cci = calculateCCI(klines);

  // 威廉指标
  const wr = calculateWR(klines);

  // OBV
  const obv = calculateOBV(closes, volumes);

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
    kdj: {
      k: kdj.k[kdj.k.length - 1],
      d: kdj.d[kdj.d.length - 1],
      j: kdj.j[kdj.j.length - 1],
    },
    boll: {
      upper: boll.upper[boll.upper.length - 1],
      middle: boll.middle[boll.middle.length - 1],
      lower: boll.lower[boll.lower.length - 1],
    },
    cci: cci[cci.length - 1],
    wr: wr[wr.length - 1],
    obv: obv[obv.length - 1],
    obvMa5: calculateMA(obv, 5)[calculateMA(obv, 5).length - 1],
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

function calculateKDJ(klines, period = 9) {
  const k = [], d = [], j = [];
  const rsv = [];

  for (let i = period - 1; i < klines.length; i++) {
    const high = Math.max(...klines.slice(i - period + 1, i + 1).map(k => k.high));
    const low = Math.min(...klines.slice(i - period + 1, i + 1).map(k => k.low));
    const close = klines[i].close;

    if (high === low) rsv.push(50);
    else rsv.push(parseFloat(((close - low) / (high - low) * 100).toFixed(2)));
  }

  if (rsv.length > 0) {
    k.push(50);
    d.push(50);
    for (let i = 1; i < rsv.length; i++) {
      const newK = (2 / 3) * k[i - 1] + (1 / 3) * rsv[i];
      const newD = (2 / 3) * d[i - 1] + (1 / 3) * newK;
      k.push(parseFloat(newK.toFixed(2)));
      d.push(parseFloat(newD.toFixed(2)));
      j.push(parseFloat((3 * newK - 2 * newD).toFixed(2)));
    }
  }

  return { k, d, j };
}

function calculateBOLL(closes, period = 20) {
  const upper = [], middle = [], lower = [];
  const ma = calculateMA(closes, period);

  for (let i = period - 1; i < closes.length; i++) {
    const slice = closes.slice(i - period + 1, i + 1);
    const avg = ma[i - period + 1];
    const std = Math.sqrt(slice.reduce((sum, val) => sum + Math.pow(val - avg, 2), 0) / period);
    
    middle.push(parseFloat(avg.toFixed(2)));
    upper.push(parseFloat((avg + 2 * std).toFixed(2)));
    lower.push(parseFloat((avg - 2 * std).toFixed(2)));
  }

  return { upper, middle, lower };
}

function calculateCCI(klines, period = 14) {
  const cci = [];

  for (let i = period - 1; i < klines.length; i++) {
    const slice = klines.slice(i - period + 1, i + 1);
    const typicalPrices = slice.map(k => (k.high + k.low + k.close) / 3);
    const sma = typicalPrices.reduce((a, b) => a + b, 0) / period;
    const meanDeviation = typicalPrices.reduce((sum, tp) => sum + Math.abs(tp - sma), 0) / period;

    const tp = (klines[i].high + klines[i].low + klines[i].close) / 3;
    if (meanDeviation === 0) cci.push(0);
    else cci.push(parseFloat(((tp - sma) / (0.015 * meanDeviation)).toFixed(2)));
  }

  return cci;
}

function calculateWR(klines, period = 14) {
  const wr = [];

  for (let i = period - 1; i < klines.length; i++) {
    const high = Math.max(...klines.slice(i - period + 1, i + 1).map(k => k.high));
    const low = Math.min(...klines.slice(i - period + 1, i + 1).map(k => k.low));
    const close = klines[i].close;

    if (high === low) wr.push(-50);
    else wr.push(parseFloat((-100 * (high - close) / (high - low)).toFixed(2)));
  }

  return wr;
}

function calculateOBV(closes, volumes) {
  const obv = [0];

  for (let i = 1; i < closes.length; i++) {
    if (closes[i] > closes[i - 1]) {
      obv.push(obv[i - 1] + volumes[i]);
    } else if (closes[i] < closes[i - 1]) {
      obv.push(obv[i - 1] - volumes[i]);
    } else {
      obv.push(obv[i - 1]);
    }
  }

  return obv.map(v => Math.round(v));
}

function calculateDMA(closes, shortPeriod = 10, longPeriod = 50) {
  const maShort = calculateMA(closes, shortPeriod);
  const maLong = calculateMA(closes, longPeriod);
  const dma = [];
  const ama = [];

  const startIdx = longPeriod - 1;
  for (let i = startIdx; i < closes.length; i++) {
    const shortIdx = i - shortPeriod + 1;
    const longIdx = i - longPeriod + 1;
    if (maShort[shortIdx] && maLong[longIdx]) {
      dma.push(parseFloat((maShort[shortIdx] - maLong[longIdx]).toFixed(4)));
      const amaPeriod = 10;
      if (dma.length >= amaPeriod) {
        const amaSlice = dma.slice(-amaPeriod);
        ama.push(parseFloat((amaSlice.reduce((a, b) => a + b, 0) / amaPeriod).toFixed(4)));
      }
    }
  }

  return { dma, ama };
}

function calculateEXPMA(closes, periods = [5, 10, 20, 60]) {
  const result = {};
  for (const period of periods) {
    result[`ema${period}`] = calculateEMA(closes, period);
  }
  return result;
}

function calculateTRIX(closes, period = 12, signal = 9) {
  const ema1 = calculateEMA(closes, period);
  const ema2 = calculateEMA(ema1, period);
  const ema3 = calculateEMA(ema2, period);

  const trix = [];
  for (let i = 1; i < ema3.length; i++) {
    if (ema3[i - 1] !== 0) {
      trix.push(parseFloat(((ema3[i] - ema3[i - 1]) / ema3[i - 1] * 100).toFixed(4)));
    } else {
      trix.push(0);
    }
  }

  const signalLine = calculateEMA(trix, signal);
  return { trix, signalLine };
}

function calculateVR(volumes, closes, period = 26) {
  const vr = [];

  for (let i = period; i < closes.length; i++) {
    let upVol = 0, downVol = 0, equalVol = 0;

    for (let j = i - period + 1; j <= i; j++) {
      if (closes[j] > closes[j - 1]) {
        upVol += volumes[j];
      } else if (closes[j] < closes[j - 1]) {
        downVol += volumes[j];
      } else {
        equalVol += volumes[j];
      }
    }

    const vrValue = downVol === 0 ? 100 : parseFloat(((upVol + equalVol / 2) / downVol * 100).toFixed(2));
    vr.push(vrValue);
  }

  return vr;
}

function calculateAROON(klines, period = 25) {
  const aroonUp = [];
  const aroonDown = [];

  for (let i = period; i < klines.length; i++) {
    const slice = klines.slice(i - period, i + 1);
    
    let maxIdx = 0, minIdx = 0;
    for (let j = 1; j< slice.length; j ++) {
      if (slice[j].high > slice[maxIdx].high) maxIdx = j;
      if (slice[j].low < slice[minIdx].low) minIdx = j;
    }

    aroonUp.push(parseFloat(((period - maxIdx) / period * 100).toFixed(2)));
    aroonDown.push(parseFloat(((period - minIdx) / period * 100).toFixed(2)));
  }

  return { aroonUp, aroonDown };
}

function calculateSAR(klines, af = 0.02, maxAf = 0.2) {
  const sar = [];
  let trend = klines[1].close > klines[0].close ? 1 : -1;
  let ep = trend === 1 ? klines[0].high : klines[0].low;
  let acceleration = af;
  let sarValue = trend === 1 ? klines[0].low : klines[0].high;

  for (let i = 1; i < klines.length; i++) {
    sarValue = sarValue + acceleration * (ep - sarValue);

    if (trend === 1) {
      if (klines[i].low < sarValue) {
        trend = -1;
        sarValue = ep;
        ep = klines[i].low;
        acceleration = af;
      } else {
        if (klines[i].high > ep) {
          ep = klines[i].high;
          acceleration = Math.min(acceleration + af, maxAf);
        }
      }
    } else {
      if (klines[i].high > sarValue) {
        trend = 1;
        sarValue = ep;
        ep = klines[i].high;
        acceleration = af;
      } else {
        if (klines[i].low < ep) {
          ep = klines[i].low;
          acceleration = Math.min(acceleration + af, maxAf);
        }
      }
    }

    sar.push(parseFloat(sarValue.toFixed(2)));
  }

  return sar;
}

function calculateAllIndicators(klines, period = 'daily') {
  if (!klines || klines.length === 0) return {};

  const closes = klines.map(k => k.close);
  const volumes = klines.map(k => k.volume);

  const ma5 = calculateMA(closes, 5);
  const ma10 = calculateMA(closes, 10);
  const ma20 = calculateMA(closes, 20);
  const ma60 = calculateMA(closes, 60);

  const macd = calculateMACD(closes);
  const rsi = calculateRSI(closes, 14);

  const volMa5 = calculateMA(volumes, 5);
  const volMa10 = calculateMA(volumes, 10);

  const kdj = calculateKDJ(klines);
  const boll = calculateBOLL(closes);
  const cci = calculateCCI(klines);
  const wr = calculateWR(klines);
  const obv = calculateOBV(closes, volumes);
  const dma = calculateDMA(closes);
  const expma = calculateEXPMA(closes);
  const trix = calculateTRIX(closes);
  const vr = calculateVR(volumes, closes);
  const aroon = calculateAROON(klines);
  const sar = calculateSAR(klines);

  const latestClose = closes[closes.length - 1];
  const lastIdx = closes.length - 1;

  return {
    klines,
    closes,
    volumes,
    currentPrice: latestClose,
    ma5: ma5[ma5.length - 1],
    ma10: ma10[ma10.length - 1],
    ma20: ma20[ma20.length - 1],
    ma60: ma60.length > 0 ? ma60[ma60.length - 1] : null,
    prevMa5: ma5.length > 1 ? ma5[ma5.length - 2] : null,
    prevMa10: ma10.length > 1 ? ma10[ma10.length - 2] : null,
    prevMa20: ma20.length > 1 ? ma20[ma20.length - 2] : null,
    macd: {
      dif: macd.dif[macd.dif.length - 1],
      dea: macd.dea[macd.dea.length - 1],
      histogram: macd.histogram[macd.histogram.length - 1],
    },
    prevMacd: macd.dif.length > 1 ? {
      dif: macd.dif[macd.dif.length - 2],
      dea: macd.dea[macd.dea.length - 2],
      histogram: macd.histogram[macd.histogram.length - 2],
    } : null,
    rsi: rsi[rsi.length - 1],
    volumeAvg5: volMa5[volMa5.length - 1],
    volumeAvg10: volMa10[volMa10.length - 1],
    latestVolume: volumes[volumes.length - 1],
    kdj: {
      k: kdj.k[kdj.k.length - 1],
      d: kdj.d[kdj.d.length - 1],
      j: kdj.j[kdj.j.length - 1],
    },
    prevKdj: kdj.k.length > 1 ? {
      k: kdj.k[kdj.k.length - 2],
      d: kdj.d[kdj.d.length - 2],
      j: kdj.j[kdj.j.length - 2],
    } : null,
    boll: {
      upper: boll.upper[boll.upper.length - 1],
      middle: boll.middle[boll.middle.length - 1],
      lower: boll.lower[boll.lower.length - 1],
    },
    cci: cci[cci.length - 1],
    wr: wr[wr.length - 1],
    obv: obv[obv.length - 1],
    obvMa5: calculateMA(obv, 5)[calculateMA(obv, 5).length - 1],
    dma: {
      dma: dma.dma[dma.dma.length - 1],
      ama: dma.ama.length > 0 ? dma.ama[dma.ama.length - 1] : null,
    },
    expma: {
      ema5: expma['ema5'] ? expma['ema5'][expma['ema5'].length - 1] : null,
      ema10: expma['ema10'] ? expma['ema10'][expma['ema10'].length - 1] : null,
      ema20: expma['ema20'] ? expma['ema20'][expma['ema20'].length - 1] : null,
      ema60: expma['ema60'] ? expma['ema60'][expma['ema60'].length - 1] : null,
    },
    trix: {
      trix: trix.trix[trix.trix.length - 1],
      signalLine: trix.signalLine[trix.signalLine.length - 1],
    },
    vr: vr[vr.length - 1],
    aroon: {
      aroonUp: aroon.aroonUp[aroon.aroonUp.length - 1],
      aroonDown: aroon.aroonDown[aroon.aroonDown.length - 1],
    },
    sar: sar[sar.length - 1],
    pricePosition: {
      aboveMa5: latestClose > (ma5[ma5.length - 1] || 0),
      aboveMa10: latestClose > (ma10[ma10.length - 1] || 0),
      aboveMa20: latestClose > (ma20[ma20.length - 1] || 0),
    },
  };
}

export default { getStockKline, calculateIndicators, calculateAllIndicators };
