/**
 * 量化策略服务
 * 功能4: 量化策略监控与交易信号
 */
import cron from 'node-cron';
import { getStockKline, calculateIndicators } from '../tools/kline.js';
import { getStockFundamental } from '../tools/fundamental.js';
import config from '../config/index.js';

// 内置量化策略定义
const STRATEGIES = {
  macd_cross: {
    id: 'macd_cross',
    name: 'MACD金叉死叉',
    description: 'MACD DIF上穿DEA为买入信号，下穿为卖出信号',
    weight: 1.2,
    evaluate: (indicators, prevIndicators) => {
      if (!indicators.macd || !prevIndicators?.macd) return null;
      const { dif, dea } = indicators.macd;
      const prevDif = prevIndicators.macd.dif;
      const prevDea = prevIndicators.macd.dea;

      if (prevDif <= prevDea && dif > dea) {
        return { signal: 'buy', reason: 'MACD金叉：DIF上穿DEA', confidence: 7 };
      }
      if (prevDif >= prevDea && dif < dea) {
        return { signal: 'sell', reason: 'MACD死叉：DIF下穿DEA', confidence: 7 };
      }
      return { signal: 'hold', reason: 'MACD无明显信号', confidence: 5 };
    },
  },

  macd_divergence: {
    id: 'macd_divergence',
    name: 'MACD底背离/顶背离',
    description: '价格创新低/高但MACD未创新低/高',
    weight: 1.5,
    evaluate: (indicators, prevIndicators, code, klineHistory) => {
      if (!klineHistory || klineHistory.length < 20 || !indicators.macd) return null;
      
      const prices = klineHistory.map(k => k.close);
      const recentLow = Math.min(...prices.slice(-10));
      const earlierLow = Math.min(...prices.slice(-20, -10));
      const macdHistogram = indicators.macd.histogram;
      
      if (recentLow < earlierLow && macdHistogram > -0.5) {
        return { signal: 'buy', reason: 'MACD底背离：价格新低但MACD未新低', confidence: 8 };
      }
      
      const recentHigh = Math.max(...prices.slice(-10));
      const earlierHigh = Math.max(...prices.slice(-20, -10));
      if (recentHigh > earlierHigh && macdHistogram < 0.5) {
        return { signal: 'sell', reason: 'MACD顶背离：价格新高但MACD未新高', confidence: 8 };
      }
      return { signal: 'hold', reason: '无背离信号', confidence: 5 };
    },
  },

  ma_trend: {
    id: 'ma_trend',
    name: '均线多头排列',
    description: 'MA5>MA10>MA20为多头排列买入，反之卖出',
    weight: 1.0,
    evaluate: (indicators) => {
      const { ma5, ma10, ma20 } = indicators;
      if (!ma5 || !ma10 || !ma20) return null;

      if (ma5 > ma10 && ma10 > ma20) {
        return { signal: 'buy', reason: '均线多头排列：MA5>MA10>MA20', confidence: 7 };
      }
      if (ma5 < ma10 && ma10 < ma20) {
        return { signal: 'sell', reason: '均线空头排列：MA5<MA10<MA20', confidence: 7 };
      }
      return { signal: 'hold', reason: '均线交织，趋势不明', confidence: 4 };
    },
  },

  ma_golden_cross: {
    id: 'ma_golden_cross',
    name: '均线金叉死叉',
    description: 'MA5上穿MA20为金叉买入，下穿为死叉卖出',
    weight: 1.1,
    evaluate: (indicators, prevIndicators) => {
      const { ma5, ma20 } = indicators;
      const prevMa5 = prevIndicators?.ma5;
      const prevMa20 = prevIndicators?.ma20;
      
      if (!ma5 || !ma20 || !prevMa5 || !prevMa20) return null;

      if (prevMa5 <= prevMa20 && ma5 > ma20) {
        return { signal: 'buy', reason: '均线金叉：MA5上穿MA20', confidence: 7 };
      }
      if (prevMa5 >= prevMa20 && ma5 < ma20) {
        return { signal: 'sell', reason: '均线死叉：MA5下穿MA20', confidence: 7 };
      }
      return { signal: 'hold', reason: '均线无交叉', confidence: 4 };
    },
  },

  rsi_oversold: {
    id: 'rsi_oversold',
    name: 'RSI超买超卖',
    description: 'RSI<30超卖买入，RSI>70超买卖出',
    weight: 1.0,
    evaluate: (indicators) => {
      const { rsi } = indicators;
      if (rsi == null) return null;

      if (rsi < 30) {
        return { signal: 'buy', reason: `RSI超卖(${rsi})，可能反弹`, confidence: 6 };
      }
      if (rsi > 70) {
        return { signal: 'sell', reason: `RSI超买(${rsi})，可能回调`, confidence: 6 };
      }
      if (rsi < 40) {
        return { signal: 'hold', reason: `RSI偏低(${rsi})，观察`, confidence: 4 };
      }
      return { signal: 'hold', reason: `RSI中性(${rsi})`, confidence: 5 };
    },
  },

  rsi_divergence: {
    id: 'rsi_divergence',
    name: 'RSI背离',
    description: 'RSI与价格走势背离',
    weight: 1.4,
    evaluate: (indicators, prevIndicators, code, klineHistory) => {
      if (!klineHistory || klineHistory.length < 20 || indicators.rsi == null) return null;
      
      const prices = klineHistory.map(k => k.close);
      const recentLow = Math.min(...prices.slice(-10));
      const earlierLow = Math.min(...prices.slice(-20, -10));
      const rsi = indicators.rsi;
      
      if (recentLow < earlierLow && rsi > 30) {
        return { signal: 'buy', reason: 'RSI底背离：价格新低但RSI未新低', confidence: 8 };
      }
      
      const recentHigh = Math.max(...prices.slice(-10));
      const earlierHigh = Math.max(...prices.slice(-20, -10));
      if (recentHigh > earlierHigh && rsi < 70) {
        return { signal: 'sell', reason: 'RSI顶背离：价格新高但RSI未新高', confidence: 8 };
      }
      return { signal: 'hold', reason: 'RSI无背离', confidence: 5 };
    },
  },

  kdj: {
    id: 'kdj',
    name: 'KDJ随机指标',
    description: 'K值上穿D值为金叉买入，下穿为死叉卖出，J值>100超买，J值<0超卖',
    weight: 1.1,
    evaluate: (indicators, prevIndicators) => {
      const { kdj } = indicators;
      const prevKdj = prevIndicators?.kdj;
      if (!kdj || !prevKdj) return null;

      const { k, d, j } = kdj;
      const prevK = prevKdj.k;
      const prevD = prevKdj.d;

      if (prevK <= prevD && k > d) {
        return { signal: 'buy', reason: `KDJ金叉：K(${k})上穿D(${d})`, confidence: 7 };
      }
      if (prevK >= prevD && k < d) {
        return { signal: 'sell', reason: `KDJ死叉：K(${k})下穿D(${d})`, confidence: 7 };
      }
      if (j < 0) {
        return { signal: 'buy', reason: `KDJ超卖：J(${j})<0`, confidence: 6 };
      }
      if (j > 100) {
        return { signal: 'sell', reason: `KDJ超买：J(${j})>100`, confidence: 6 };
      }
      return { signal: 'hold', reason: `KDJ无信号：K(${k}), D(${d}), J(${j})`, confidence: 4 };
    },
  },

  boll: {
    id: 'boll',
    name: '布林带策略',
    description: '价格下穿下轨买入，上穿上轨卖出',
    weight: 1.2,
    evaluate: (indicators, prevIndicators) => {
      const { boll, currentPrice } = indicators;
      if (!boll || !currentPrice) return null;

      const { upper, middle, lower } = boll;
      
      if (currentPrice < lower) {
        return { signal: 'buy', reason: `布林带下轨支撑：价格(${currentPrice})<下轨(${lower})`, confidence: 7 };
      }
      if (currentPrice > upper) {
        return { signal: 'sell', reason: `布林带上轨压力：价格(${currentPrice})>上轨(${upper})`, confidence: 7 };
      }
      if (currentPrice < middle && currentPrice > lower) {
        return { signal: 'hold', reason: '布林带中轨附近，观察', confidence: 5 };
      }
      return { signal: 'hold', reason: '布林带内正常运行', confidence: 5 };
    },
  },

  cci: {
    id: 'cci',
    name: 'CCI顺势指标',
    description: 'CCI<-100超卖买入，CCI>100超买卖出',
    weight: 1.0,
    evaluate: (indicators) => {
      const { cci } = indicators;
      if (cci == null) return null;

      if (cci < -100) {
        return { signal: 'buy', reason: `CCI超卖(${cci})，强烈买入信号`, confidence: 8 };
      }
      if (cci > 100) {
        return { signal: 'sell', reason: `CCI超买(${cci})，强烈卖出信号`, confidence: 8 };
      }
      if (cci < -50) {
        return { signal: 'hold', reason: `CCI偏弱(${cci})，观察`, confidence: 4 };
      }
      if (cci > 50) {
        return { signal: 'hold', reason: `CCI偏强(${cci})，观察`, confidence: 4 };
      }
      return { signal: 'hold', reason: `CCI中性(${cci})`, confidence: 5 };
    },
  },

  wr: {
    id: 'wr',
    name: '威廉指标',
    description: 'WR<-80超卖买入，WR>-20超买卖出',
    weight: 0.9,
    evaluate: (indicators) => {
      const { wr } = indicators;
      if (wr == null) return null;

      if (wr < -80) {
        return { signal: 'buy', reason: `威廉超卖(${wr})，可能反弹`, confidence: 6 };
      }
      if (wr > -20) {
        return { signal: 'sell', reason: `威廉超买(${wr})，可能回调`, confidence: 6 };
      }
      return { signal: 'hold', reason: `威廉正常(${wr})`, confidence: 5 };
    },
  },

  obv: {
    id: 'obv',
    name: 'OBV能量潮',
    description: 'OBV上穿均线买入，下穿卖出',
    weight: 0.9,
    evaluate: (indicators, prevIndicators) => {
      const { obv, obvMa5, currentPrice, ma5 } = indicators;
      const prevObv = prevIndicators?.obv;
      const prevObvMa5 = prevIndicators?.obvMa5;
      
      if (obv == null || obvMa5 == null || !prevObv || !prevObvMa5) return null;

      if (prevObv <= prevObvMa5 && obv > obvMa5) {
        return { signal: 'buy', reason: 'OBV上穿均线，能量增强', confidence: 6 };
      }
      if (prevObv >= prevObvMa5 && obv < obvMa5) {
        return { signal: 'sell', reason: 'OBV下穿均线，能量减弱', confidence: 6 };
      }
      
      const obvTrend = obv > prevObv ? '上升' : '下降';
      const priceTrend = currentPrice > (prevIndicators?.currentPrice || 0) ? '上涨' : '下跌';
      
      if (obvTrend === '上升' && priceTrend === '下跌') {
        return { signal: 'buy', reason: 'OBV与价格背离，可能反转', confidence: 7 };
      }
      if (obvTrend === '下降' && priceTrend === '上涨') {
        return { signal: 'sell', reason: 'OBV与价格背离，可能反转', confidence: 7 };
      }
      
      return { signal: 'hold', reason: `OBV${obvTrend}，价格${priceTrend}，观望`, confidence: 5 };
    },
  },

  volume_price: {
    id: 'volume_price',
    name: '量价配合',
    description: '放量上涨买入，放量下跌卖出',
    weight: 1.0,
    evaluate: (indicators) => {
      const { latestVolume, volumeAvg5, currentPrice, ma5 } = indicators;
      if (!latestVolume || !volumeAvg5) return null;

      const volumeRatio = latestVolume / volumeAvg5;
      const priceAboveMa5 = currentPrice > (ma5 || 0);

      if (volumeRatio > 1.5 && priceAboveMa5) {
        return { signal: 'buy', reason: `放量上涨（量比${volumeRatio.toFixed(2)}），多头强势`, confidence: 7 };
      }
      if (volumeRatio > 1.5 && !priceAboveMa5) {
        return { signal: 'sell', reason: `放量下跌（量比${volumeRatio.toFixed(2)}），空头强势`, confidence: 7 };
      }
      return { signal: 'hold', reason: `量价平稳（量比${volumeRatio.toFixed(2)}）`, confidence: 5 };
    },
  },

  volume_surge: {
    id: 'volume_surge',
    name: '成交量突增',
    description: '成交量较历史放大2倍以上',
    weight: 0.8,
    evaluate: (indicators) => {
      const { latestVolume, volumeAvg5 } = indicators;
      if (!latestVolume || !volumeAvg5) return null;

      const volumeRatio = latestVolume / volumeAvg5;
      
      if (volumeRatio > 2.5) {
        return { signal: 'buy', reason: `成交量突增（量比${volumeRatio.toFixed(2)}倍），关注异动`, confidence: 6 };
      }
      if (volumeRatio < 0.3) {
        return { signal: 'hold', reason: `成交量萎缩（量比${volumeRatio.toFixed(2)}倍），观望`, confidence: 4 };
      }
      return { signal: 'hold', reason: `成交量正常（量比${volumeRatio.toFixed(2)}）`, confidence: 5 };
    },
  },

  value_invest: {
    id: 'value_invest',
    name: '价值投资',
    description: '低PE+高ROE+净利润增长 = 价值股',
    weight: 1.3,
    evaluate: async (indicators, prevIndicators, code) => {
      const fundamental = await getStockFundamental(code);
      if (!fundamental) return null;

      const { pe, pb, roe, netProfitGrowth } = fundamental;
      let score = 0;
      const reasons = [];

      if (pe > 0 && pe < 20) { score += 2; reasons.push(`低PE(${pe})`); }
      else if (pe > 0 && pe < 40) { score += 1; reasons.push(`中PE(${pe})`); }
      else if (pe > 40) { score -= 1; reasons.push(`高PE(${pe})`); }

      if (pb > 0 && pb < 2) { score += 2; reasons.push(`低PB(${pb})`); }
      else if (pb > 5) { score -= 1; reasons.push(`高PB(${pb})`); }

      if (roe > 15) { score += 2; reasons.push(`高ROE(${roe}%)`); }
      else if (roe > 8) { score += 1; reasons.push(`中ROE(${roe}%)`); }

      if (netProfitGrowth > 20) { score += 2; reasons.push(`高增长(${netProfitGrowth}%)`); }
      else if (netProfitGrowth > 0) { score += 1; reasons.push(`正增长(${netProfitGrowth}%)`); }
      else { score -= 1; reasons.push(`负增长(${netProfitGrowth}%)`); }

      if (score >= 5) return { signal: 'buy', reason: `价值股：${reasons.join('，')}`, confidence: 8 };
      if (score <= 0) return { signal: 'sell', reason: `估值偏高：${reasons.join('，')}`, confidence: 6 };
      return { signal: 'hold', reason: `估值一般：${reasons.join('，')}`, confidence: 5 };
    },
  },

  break_through: {
    id: 'break_through',
    name: '突破新高/新低',
    description: '价格突破20日新高/新低',
    weight: 1.2,
    evaluate: (indicators, prevIndicators, code, klineHistory) => {
      if (!klineHistory || klineHistory.length < 20) return null;
      
      const prices = klineHistory.map(k => k.close);
      const currentPrice = prices[prices.length - 1];
      const high20 = Math.max(...prices.slice(-20, -1));
      const low20 = Math.min(...prices.slice(-20, -1));
      
      if (currentPrice > high20) {
        return { signal: 'buy', reason: `突破20日新高(${high20.toFixed(2)})，强势上涨`, confidence: 8 };
      }
      if (currentPrice < low20) {
        return { signal: 'sell', reason: `跌破20日新低(${low20.toFixed(2)})，弱势下跌`, confidence: 8 };
      }
      return { signal: 'hold', reason: '未突破20日区间', confidence: 5 };
    },
  },

  dma_cross: {
    id: 'dma_cross',
    name: 'DMA金叉死叉',
    description: 'DMA上穿AMA为金叉买入，下穿为死叉卖出',
    weight: 1.1,
    evaluate: (indicators, prevIndicators) => {
      const { dma } = indicators;
      if (!dma || !dma.dma || !dma.ama) return null;
      
      const prevDma = prevIndicators?.dma;
      if (!prevDma || !prevDma.dma || !prevDma.ama) return null;

      const { dma: dmaValue, ama: amaValue } = dma;
      const { dma: prevDmaValue, ama: prevAmaValue } = prevDma;

      if (prevDmaValue <= prevAmaValue && dmaValue > amaValue) {
        return { signal: 'buy', reason: `DMA金叉：DMA(${dmaValue})上穿AMA(${amaValue})`, confidence: 7 };
      }
      if (prevDmaValue >= prevAmaValue && dmaValue < amaValue) {
        return { signal: 'sell', reason: `DMA死叉：DMA(${dmaValue})下穿AMA(${amaValue})`, confidence: 7 };
      }
      return { signal: 'hold', reason: 'DMA无交叉信号', confidence: 5 };
    },
  },

  expma_trend: {
    id: 'expma_trend',
    name: 'EXPMA趋势策略',
    description: 'EXPMA多头排列/空头排列',
    weight: 1.2,
    evaluate: (indicators) => {
      const { expma } = indicators;
      if (!expma || !expma.ema5 || !expma.ema10 || !expma.ema20) return null;

      const { ema5, ema10, ema20 } = expma;

      if (ema5 > ema10 && ema10 > ema20) {
        return { signal: 'buy', reason: 'EXPMA多头排列：EMA5>EMA10>EMA20', confidence: 7 };
      }
      if (ema5 < ema10 && ema10 < ema20) {
        return { signal: 'sell', reason: 'EXPMA空头排列：EMA5<EMA10<EMA20', confidence: 7 };
      }
      return { signal: 'hold', reason: 'EXPMA趋势不明', confidence: 4 };
    },
  },

  trix_cross: {
    id: 'trix_cross',
    name: 'TRIX零轴交叉',
    description: 'TRIX上穿零轴为买入，下穿为卖出',
    weight: 1.1,
    evaluate: (indicators, prevIndicators) => {
      const { trix } = indicators;
      if (!trix || trix.trix == null || trix.signalLine == null) return null;

      const prevTrix = prevIndicators?.trix;
      if (!prevTrix || prevTrix.trix == null) return null;

      const { trix: trixValue, signalLine } = trix;
      const prevTrixValue = prevTrix.trix;

      if (prevTrixValue <= 0 && trixValue > 0) {
        return { signal: 'buy', reason: `TRIX上穿零轴(${trixValue.toFixed(2)})，多头趋势`, confidence: 7 };
      }
      if (prevTrixValue >= 0 && trixValue < 0) {
        return { signal: 'sell', reason: `TRIX下穿零轴(${trixValue.toFixed(2)})，空头趋势`, confidence: 7 };
      }
      if (trixValue > signalLine && prevTrix.trix <= prevTrix.signalLine) {
        return { signal: 'buy', reason: `TRIX上穿信号线，金叉`, confidence: 6 };
      }
      if (trixValue < signalLine && prevTrix.trix >= prevTrix.signalLine) {
        return { signal: 'sell', reason: `TRIX下穿信号线，死叉`, confidence: 6 };
      }
      return { signal: 'hold', reason: `TRIX运行中(${trixValue.toFixed(2)})`, confidence: 5 };
    },
  },

  vr: {
    id: 'vr',
    name: 'VR能量分析',
    description: 'VR>150为超买区域，VR<70为超卖区域',
    weight: 0.9,
    evaluate: (indicators) => {
      const { vr } = indicators;
      if (vr == null) return null;

      if (vr > 150) {
        return { signal: 'sell', reason: `VR超买(${vr})，风险积聚`, confidence: 6 };
      }
      if (vr < 70) {
        return { signal: 'buy', reason: `VR超卖(${vr})，能量不足可能反弹`, confidence: 6 };
      }
      if (vr > 100) {
        return { signal: 'hold', reason: `VR偏强(${vr})，多头市场`, confidence: 5 };
      }
      return { signal: 'hold', reason: `VR正常(${vr})`, confidence: 5 };
    },
  },

  aroon: {
    id: 'aroon',
    name: 'AROON趋势判断',
    description: 'AROON UP>AROON DOWN为多头，AROON DOWN>AROON UP为空头',
    weight: 1.0,
    evaluate: (indicators) => {
      const { aroon } = indicators;
      if (!aroon || aroon.aroonUp == null || aroon.aroonDown == null) return null;

      const { aroonUp, aroonDown } = aroon;

      if (aroonUp > 70 && aroonDown < 30) {
        return { signal: 'buy', reason: `AROON强势多头：Up(${aroonUp})>70, Down(${aroonDown})<30`, confidence: 7 };
      }
      if (aroonDown > 70 && aroonUp < 30) {
        return { signal: 'sell', reason: `AROON强势空头：Down(${aroonDown})>70, Up(${aroonUp})<30`, confidence: 7 };
      }
      if (aroonUp > aroonDown && aroonUp > 50) {
        return { signal: 'buy', reason: `AROON偏多：Up(${aroonUp})>Down(${aroonDown})`, confidence: 6 };
      }
      if (aroonDown > aroonUp && aroonDown > 50) {
        return { signal: 'sell', reason: `AROON偏空：Down(${aroonDown})>Up(${aroonUp})`, confidence: 6 };
      }
      return { signal: 'hold', reason: `AROON盘整：Up(${aroonUp}), Down(${aroonDown})`, confidence: 4 };
    },
  },

  sar_reversal: {
    id: 'sar_reversal',
    name: 'SAR停损反转',
    description: 'SAR反转作为买卖信号',
    weight: 1.0,
    evaluate: (indicators, prevIndicators, code, klineHistory) => {
      if (!klineHistory || klineHistory.length < 2 || !indicators.sar || !prevIndicators?.sar) return null;

      const currentPrice = indicators.currentPrice;
      const sarValue = indicators.sar;
      const prevSarValue = prevIndicators.sar;

      if (prevSarValue > prevIndicators.currentPrice && sarValue < currentPrice) {
        return { signal: 'buy', reason: `SAR反转：价格上穿SAR(${sarValue})，买入信号`, confidence: 7 };
      }
      if (prevSarValue < prevIndicators.currentPrice && sarValue > currentPrice) {
        return { signal: 'sell', reason: `SAR反转：价格下穿SAR(${sarValue})，卖出信号`, confidence: 7 };
      }

      if (currentPrice > sarValue) {
        return { signal: 'hold', reason: `SAR多头：价格(${currentPrice})>SAR(${sarValue})`, confidence: 5 };
      }
      return { signal: 'hold', reason: `SAR空头：价格(${currentPrice})<SAR(${sarValue})`, confidence: 5 };
    },
  },

  multi_cycle_resonance: {
    id: 'multi_cycle_resonance',
    name: '多周期共振',
    description: '日周月线同时出现买入/卖出信号',
    weight: 1.5,
    evaluate: async (indicators, prevIndicators, code, klineHistory) => {
      const { getStockKline, calculateIndicators } = await import('../tools/kline.js');
      
      try {
        const weeklyKlines = await getStockKline(code, 'weekly', 20);
        const monthlyKlines = await getStockKline(code, 'monthly', 10);
        
        if (!weeklyKlines.length || !monthlyKlines.length) return null;

        const weeklyIndicators = calculateIndicators(weeklyKlines);
        const monthlyIndicators = calculateIndicators(monthlyKlines);

        const dailyMACD = indicators.macd;
        const weeklyMACD = weeklyIndicators.macd;
        const monthlyMACD = monthlyIndicators.macd;

        let buyCount = 0;
        let sellCount = 0;

        if (dailyMACD?.dif > dailyMACD?.dea) buyCount++;
        else if (dailyMACD?.dif < dailyMACD?.dea) sellCount++;

        if (weeklyMACD?.dif > weeklyMACD?.dea) buyCount++;
        else if (weeklyMACD?.dif < weeklyMACD?.dea) sellCount++;

        if (monthlyMACD?.dif > monthlyMACD?.dea) buyCount++;
        else if (monthlyMACD?.dif < monthlyMACD?.dea) sellCount++;

        if (buyCount >= 3) {
          return { signal: 'buy', reason: '多周期共振：日周月线同时金叉，强烈买入', confidence: 9 };
        }
        if (sellCount >= 3) {
          return { signal: 'sell', reason: '多周期共振：日周月线同时死叉，强烈卖出', confidence: 9 };
        }
        if (buyCount >= 2 && sellCount === 0) {
          return { signal: 'buy', reason: `多周期共振：${buyCount}周期看多`, confidence: 7 };
        }
        if (sellCount >= 2 && buyCount === 0) {
          return { signal: 'sell', reason: `多周期共振：${sellCount}周期看空`, confidence: 7 };
        }
        return { signal: 'hold', reason: `多周期信号分散（买${buyCount}卖${sellCount}）`, confidence: 4 };
      } catch (e) {
        return null;
      }
    },
  },

  limit_up_gene: {
    id: 'limit_up_gene',
    name: '涨停板基因',
    description: '历史涨停次数越多，股性越活�',
    weight: 0.7,
    evaluate: (indicators, prevIndicators, code, klineHistory) => {
      if (!klineHistory || klineHistory.length < 60) return null;

      const limitUpCount = klineHistory.filter(k => k.changePercent >= 9.9).length;
      const recentLimitUp = klineHistory.slice(-20).filter(k => k.changePercent >= 9.9).length;

      if (recentLimitUp >= 2) {
        return { signal: 'buy', reason: `强势股性：20日内${recentLimitUp}次涨停，股性活跃`, confidence: 7 };
      }
      if (limitUpCount >= 5) {
        return { signal: 'buy', reason: `历史涨停基因：历史共${limitUpCount}次涨停`, confidence: 6 };
      }
      return { signal: 'hold', reason: `股性一般：历史${limitUpCount}次涨停`, confidence: 4 };
    },
  },

  gap_analysis: {
    id: 'gap_analysis',
    name: '缺口分析',
    description: '分析向上/向下跳空缺口的支撑/压力',
    weight: 0.8,
    evaluate: (indicators, prevIndicators, code, klineHistory) => {
      if (!klineHistory || klineHistory.length < 5) return null;

      const currentPrice = indicators.currentPrice;
      const prevPrice = klineHistory[klineHistory.length - 2]?.close;
      if (!prevPrice) return null;

      const gap = ((currentPrice - prevPrice) / prevPrice) * 100;

      if (gap > 3) {
        return { signal: 'buy', reason: `向上跳空缺口(+${gap.toFixed(2)}%)，强势信号`, confidence: 6 };
      }
      if (gap < -3) {
        return { signal: 'sell', reason: `向下跳空缺口(${gap.toFixed(2)}%)，弱势信号`, confidence: 6 };
      }
      return { signal: 'hold', reason: '无明显跳空缺口', confidence: 5 };
    },
  },

  double_bottom: {
    id: 'double_bottom',
    name: '双底/双顶形态',
    description: 'W底形态买入，M头形态卖出',
    weight: 1.2,
    evaluate: (indicators, prevIndicators, code, klineHistory) => {
      if (!klineHistory || klineHistory.length < 40) return null;

      const closes = klineHistory.map(k => k.close);
      const recentPrices = closes.slice(-20);
      
      const min1 = Math.min(...recentPrices.slice(0, 7));
      const min2 = Math.min(...recentPrices.slice(7, 14));
      const min3 = Math.min(...recentPrices.slice(14));
      
      const max1 = Math.max(...recentPrices.slice(0, 7));
      const max2 = Math.max(...recentPrices.slice(7, 14));
      const max3 = Math.max(...recentPrices.slice(14));

      const currentPrice = closes[closes.length - 1];

      if (min1 < min2 && min3 < min2 && Math.abs(min1 - min3) < min1 * 0.03) {
        return { signal: 'buy', reason: '双底形态形成：W底反弹信号', confidence: 8 };
      }
      if (max1 > max2 && max3 > max2 && Math.abs(max1 - max3) < max1 * 0.03) {
        return { signal: 'sell', reason: '双顶形态形成：M头反转信号', confidence: 8 };
      }
      return { signal: 'hold', reason: '无明显形态', confidence: 5 };
    },
  },
};

export function getStrategies() {
  return STRATEGIES;
}

class QuantService {
  constructor() {
    /** @type {Map<string, {code, name, strategies: string[], status, cronJob, signals: Array, riskControl: Object, positions: Object}>} */
    this.tasks = new Map();
    this.listeners = new Set();
    this.prevIndicators = new Map();
    this.klineHistory = new Map();
  }

  /**
   * 获取可用策略列表
   */
  getAvailableStrategies() {
    return Object.values(STRATEGIES).map(({ evaluate, ...rest }) => rest);
  }

  /**
   * 添加量化任务
   */
  addTask(code, name, strategyIds = ['macd_cross', 'ma_trend', 'rsi_oversold'], riskControl = {}) {
    const taskKey = code;
    if (this.tasks.has(taskKey)) {
      return { success: false, message: '该股票已有量化任务' };
    }

    const validStrategies = strategyIds.filter(id => STRATEGIES[id]);
    if (validStrategies.length === 0) {
      return { success: false, message: '没有有效的策略' };
    }

    const defaultRiskControl = {
      stopLossPercent: -5,
      takeProfitPercent: 10,
      maxPositionPercent: 30,
      enableStopLoss: true,
      enableTakeProfit: true,
      signalConfirmCount: 1,
    };

    this.tasks.set(taskKey, {
      code,
      name: name || code,
      strategies: validStrategies,
      status: 'stopped',
      cronJob: null,
      signals: [],
      riskControl: { ...defaultRiskControl, ...riskControl },
      positions: {
        entryPrice: null,
        quantity: 0,
        positionType: null,
        entryDate: null,
      },
      signalHistory: {
        buy: [],
        sell: [],
      },
      createdAt: new Date().toISOString(),
    });

    this._notify('task_added', { code, name, strategies: validStrategies });
    return { success: true, message: `已添加量化任务: ${name || code}` };
  }

  /**
   * 删除量化任务
   */
  removeTask(code) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };

    if (task.cronJob) task.cronJob.stop();
    this.tasks.delete(code);
    this._notify('task_removed', { code });
    return { success: true, message: `已删除量化任务: ${task.name}` };
  }

  /**
   * 启动量化任务
   */
  startTask(code) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };
    if (task.status === 'running') return { success: false, message: '任务已在运行' };

    const interval = config.monitor.quantIntervalMinutes;
    const cronExpression = `*/${interval} * * * 1-5`;

    task.cronJob = cron.schedule(cronExpression, async () => {
      await this._runStrategies(code);
    }, { timezone: 'Asia/Shanghai' });

    task.status = 'running';
    this._notify('task_started', { code });

    // 立即执行一次
    this._runStrategies(code);

    return { success: true, message: `已启动量化监控，每 ${interval} 分钟执行策略` };
  }

  /**
   * 停止量化任务
   */
  stopTask(code) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };

    if (task.cronJob) {
      task.cronJob.stop();
      task.cronJob = null;
    }

    task.status = 'stopped';
    this._notify('task_stopped', { code });
    return { success: true, message: `已停止量化任务: ${task.name}` };
  }

  /**
   * 获取所有任务
   */
  getAllTasks() {
    return Array.from(this.tasks.values()).map(({ cronJob, positions, signalHistory, ...rest }) => ({
      ...rest,
      signals: rest.signals.slice(-10),
      riskControl: {
        stopLossPercent: rest.riskControl?.stopLossPercent || -5,
        takeProfitPercent: rest.riskControl?.takeProfitPercent || 10,
        maxPositionPercent: rest.riskControl?.maxPositionPercent || 30,
        enableStopLoss: rest.riskControl?.enableStopLoss ?? true,
        enableTakeProfit: rest.riskControl?.enableTakeProfit ?? true,
        signalConfirmCount: rest.riskControl?.signalConfirmCount || 1,
      },
    }));
  }

  /**
   * 更新任务策略
   */
  updateTaskStrategies(code, strategyIds) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };

    task.strategies = strategyIds.filter(id => STRATEGIES[id]);
    return { success: true, message: '策略已更新' };
  }

  /**
   * 更新风控参数
   */
  updateRiskControl(code, riskControl) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };

    task.riskControl = { ...task.riskControl, ...riskControl };
    return { success: true, message: '风控参数已更新' };
  }

  /**
   * 更新持仓状态
   */
  updatePosition(code, positionData) {
    const task = this.tasks.get(code);
    if (!task) return { success: false, message: '未找到该任务' };

    task.positions = { ...task.positions, ...positionData };
    return { success: true };
  }

  /**
   * 获取持仓状态
   */
  getPosition(code) {
    const task = this.tasks.get(code);
    if (!task) return null;
    return task.positions;
  }

  /**
   * 综合信号判断（优化版）
   */
  _calculateCompositeSignal(signals, riskControl, currentPrice) {
    const buySignals = signals.filter(s => s.signal === 'buy');
    const sellSignals = signals.filter(s => s.signal === 'sell');
    const holdSignals = signals.filter(s => s.signal === 'hold');

    let buyScore = 0;
    let sellScore = 0;

    for (const signal of buySignals) {
      const strategy = STRATEGIES[signal.strategy];
      const weight = strategy?.weight || 1.0;
      buyScore += signal.confidence * weight;
    }

    for (const signal of sellSignals) {
      const strategy = STRATEGIES[signal.strategy];
      const weight = strategy?.weight || 1.0;
      sellScore += signal.confidence * weight;
    }

    const totalSignals = signals.length;
    const signalConfirmCount = riskControl.signalConfirmCount || 1;
    const threshold = 3 + signalConfirmCount * 2;

    let compositeSignal = 'hold';
    let compositeReason = '';
    let signalStrength = 0;

    if (buySignals.length >= signalConfirmCount && buyScore > sellScore + threshold) {
      compositeSignal = 'buy';
      compositeReason = `${buySignals.length}个策略发出买入信号（加权得分：${buyScore.toFixed(1)}）`;
      signalStrength = Math.min(buyScore / 20, 1);
    } else if (sellSignals.length >= signalConfirmCount && sellScore > buyScore + threshold) {
      compositeSignal = 'sell';
      compositeReason = `${sellSignals.length}个策略发出卖出信号（加权得分：${sellScore.toFixed(1)}）`;
      signalStrength = Math.min(sellScore / 20, 1);
    } else if (buySignals.length > sellSignals.length) {
      compositeSignal = 'hold';
      compositeReason = `买入信号较多但未达阈值，建议观察`;
      signalStrength = 0.3;
    } else if (sellSignals.length > buySignals.length) {
      compositeSignal = 'hold';
      compositeReason = `卖出信号较多但未达阈值，建议观察`;
      signalStrength = 0.3;
    } else {
      compositeReason = '信号不一致，建议观望';
      signalStrength = 0;
    }

    return {
      signal: compositeSignal,
      reason: compositeReason,
      strength: signalStrength,
      scores: { buy: buyScore, sell: sellScore },
      counts: { buy: buySignals.length, sell: sellSignals.length, hold: holdSignals.length },
    };
  }

  /**
   * 风控检查
   */
  _checkRiskControl(task, currentPrice) {
    const { riskControl, positions } = task;
    const { enableStopLoss, enableTakeProfit, stopLossPercent, takeProfitPercent } = riskControl;
    
    if (!positions.entryPrice || positions.quantity === 0) {
      return { triggered: false };
    }

    const profitPercent = ((currentPrice - positions.entryPrice) / positions.entryPrice) * 100;
    const result = { triggered: false, action: null, reason: '', profitPercent };

    if (enableStopLoss && profitPercent <= stopLossPercent) {
      result.triggered = true;
      result.action = 'sell';
      result.reason = `触发止损（${profitPercent.toFixed(2)}%）`;
    } else if (enableTakeProfit && profitPercent >= takeProfitPercent) {
      result.triggered = true;
      result.action = 'sell';
      result.reason = `触发止盈（${profitPercent.toFixed(2)}%）`;
    }

    return result;
  }

  /**
   * 信号确认检查
   */
  _checkSignalConfirmation(task, compositeSignal) {
    const { signalHistory, riskControl } = task;
    const signalConfirmCount = riskControl.signalConfirmCount || 1;
    const signalType = compositeSignal.signal;

    if (signalType === 'hold') {
      signalHistory.buy = [];
      signalHistory.sell = [];
      return { confirmed: false, reason: '信号为持有' };
    }

    const historyArray = signalType === 'buy' ? signalHistory.buy : signalHistory.sell;
    const oppositeArray = signalType === 'buy' ? signalHistory.sell : signalHistory.buy;

    oppositeArray.length = 0;
    historyArray.push(Date.now());

    if (historyArray.length > 10) {
      historyArray.shift();
    }

    const recentSignals = historyArray.slice(-signalConfirmCount);
    const timeSpan = recentSignals[recentSignals.length - 1] - recentSignals[0];

    if (recentSignals.length >= signalConfirmCount && timeSpan < 24 * 60 * 60 * 1000) {
      return { confirmed: true, reason: `连续${signalConfirmCount}次信号确认` };
    }

    return { confirmed: false, reason: `需要${signalConfirmCount}次确认（当前${recentSignals.length}次）` };
  }

  /**
   * 运行策略分析
   */
  async _runStrategies(code) {
    const task = this.tasks.get(code);
    if (!task) return;

    try {
      this._notify('strategies_running', { code, name: task.name });

      const klines = await getStockKline(code, 'daily', 60);
      const indicators = calculateIndicators(klines);
      const prevIndicators = this.prevIndicators.get(code) || null;

      this.klineHistory.set(code, klines);

      const signals = [];
      for (const strategyId of task.strategies) {
        const strategy = STRATEGIES[strategyId];
        if (!strategy) continue;

        try {
          const klineHistory = this.klineHistory.get(code);
          const result = await strategy.evaluate(indicators, prevIndicators, code, klineHistory);
          if (result) {
            signals.push({
              strategy: strategyId,
              strategyName: strategy.name,
              ...result,
              timestamp: new Date().toISOString(),
            });
          }
        } catch (e) {
          console.error(`策略 ${strategyId} 执行失败:`, e.message);
        }
      }

      const composite = this._calculateCompositeSignal(signals, task.riskControl, indicators.currentPrice);
      const riskCheck = this._checkRiskControl(task, indicators.currentPrice);
      const signalConfirm = this._checkSignalConfirmation(task, composite);

      let finalSignal = composite.signal;
      let finalReason = composite.reason;

      if (riskCheck.triggered) {
        finalSignal = riskCheck.action;
        finalReason = riskCheck.reason;
      } else if (!signalConfirm.confirmed && composite.signal !== 'hold') {
        finalSignal = 'hold';
        finalReason += `；${signalConfirm.reason}`;
      }

      const signalResult = {
        code,
        name: task.name,
        signals,
        composite: { ...composite, finalSignal, finalReason },
        riskCheck: {
          triggered: riskCheck.triggered,
          action: riskCheck.action,
          reason: riskCheck.reason,
          profitPercent: riskCheck.profitPercent,
        },
        signalConfirm: {
          confirmed: signalConfirm.confirmed,
          reason: signalConfirm.reason,
        },
        price: indicators.currentPrice,
        position: task.positions,
        timestamp: new Date().toISOString(),
      };

      task.signals.push(signalResult);
      if (task.signals.length > 50) {
        task.signals = task.signals.slice(-50);
      }

      this.prevIndicators.set(code, indicators);

      this._notify('strategies_completed', signalResult);
    } catch (error) {
      this._notify('strategies_error', { code, error: error.message });
    }
  }

  addListener(callback) {
    this.listeners.add(callback);
    return () => this.listeners.delete(callback);
  }

  _notify(event, data) {
    this.listeners.forEach(cb => {
      try { cb(event, data); } catch (e) { console.error('Quant listener error:', e); }
    });
  }
}

const quantService = new QuantService();
export default quantService;
