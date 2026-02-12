/// 技术分析工具 - LangChain Tool
import 'dart:convert';
import 'dart:math' as math;
import 'package:langchain_core/tools.dart';
import '../data_sources/eastmoney_data_source.dart';
import '../models/schemas.dart';

/// 获取技术分析指标工具
final getTechnicalIndicatorsTool = Tool.fromFunction<String, String>(
  name: 'get_technical_indicators',
  description: '获取股票技术分析指标。包括MA(5/10/20/60日均线)、MACD、RSI、KDJ、布林带等。'
      '用于判断股票的技术面走势、支撑位和压力位。',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {
      'stock_code': {
        'type': 'string',
        'description': '股票代码，如 600000',
      },
    },
    'required': ['stock_code'],
  },
  func: _getTechnicalIndicators,
  getInputFromJson: (json) => json['stock_code'] as String,
);

Future<String> _getTechnicalIndicators(String stockCode) async {
  final eastmoney = EastMoneyDataSource();
  final klines = await eastmoney.getKline(stockCode, period: 'day', count: 120);

  if (klines.length < 5) {
    return '获取K线数据不足，无法计算技术指标: $stockCode';
  }

  final closes = klines.map((k) => k.close).toList();
  final highs = klines.map((k) => k.high).toList();
  final lows = klines.map((k) => k.low).toList();

  final macdResult = _calculateMacd(closes);
  final kdjResult = _calculateKdj(highs, lows, closes);
  final bollResult = _calculateBoll(closes);

  final indicators = TechnicalIndicators(
    code: stockCode,
    ma5: _calculateMa(closes, 5),
    ma10: _calculateMa(closes, 10),
    ma20: _calculateMa(closes, 20),
    ma60: _calculateMa(closes, 60),
    macd: macdResult['macd'],
    macdSignal: macdResult['signal'],
    macdHist: macdResult['hist'],
    rsi6: _calculateRsi(closes, 6),
    rsi12: _calculateRsi(closes, 12),
    rsi24: _calculateRsi(closes, 24),
    kdjK: kdjResult['k'],
    kdjD: kdjResult['d'],
    kdjJ: kdjResult['j'],
    bollUpper: bollResult['upper'],
    bollMiddle: bollResult['middle'],
    bollLower: bollResult['lower'],
  );

  return const JsonEncoder.withIndent('  ').convert(indicators.toJson());
}

double? _calculateMa(List<double> closes, int period) {
  if (closes.length < period) return null;
  final slice = closes.sublist(closes.length - period);
  final avg = slice.reduce((a, b) => a + b) / period;
  return double.parse(avg.toStringAsFixed(4));
}

Map<String, double?> _calculateMacd(List<double> closes) {
  if (closes.length < 26) {
    return {'macd': null, 'signal': null, 'hist': null};
  }

  double ema12 = closes[0];
  double ema26 = closes[0];
  const m12 = 2 / 13;
  const m26 = 2 / 27;

  final difVals = <double>[];
  for (final p in closes) {
    ema12 = p * m12 + ema12 * (1 - m12);
    ema26 = p * m26 + ema26 * (1 - m26);
    difVals.add(ema12 - ema26);
  }

  double dea = difVals[0];
  const m9 = 2 / 10;
  for (final d in difVals) {
    dea = d * m9 + dea * (1 - m9);
  }

  final dif = difVals.last;
  final macdHist = 2 * (dif - dea);

  return {
    'macd': double.parse(dif.toStringAsFixed(4)),
    'signal': double.parse(dea.toStringAsFixed(4)),
    'hist': double.parse(macdHist.toStringAsFixed(4)),
  };
}

double? _calculateRsi(List<double> closes, int period) {
  if (closes.length < period + 1) return null;

  final gains = <double>[];
  final losses = <double>[];
  for (int i = 1; i < closes.length; i++) {
    final diff = closes[i] - closes[i - 1];
    gains.add(diff > 0 ? diff : 0);
    losses.add(diff < 0 ? -diff : 0);
  }

  final avgGain =
      gains.sublist(gains.length - period).reduce((a, b) => a + b) / period;
  final avgLoss =
      losses.sublist(losses.length - period).reduce((a, b) => a + b) / period;

  if (avgLoss == 0) return 100;
  final rs = avgGain / avgLoss;
  return double.parse((100 - 100 / (1 + rs)).toStringAsFixed(4));
}

Map<String, double?> _calculateKdj(
    List<double> highs, List<double> lows, List<double> closes,
    {int period = 9}) {
  if (closes.length < period) {
    return {'k': null, 'd': null, 'j': null};
  }

  double k = 50.0, d = 50.0;
  for (int i = period - 1; i < closes.length; i++) {
    final lowN = lows.sublist(i - period + 1, i + 1).reduce(math.min);
    final highN = highs.sublist(i - period + 1, i + 1).reduce(math.max);
    double rsv;
    if (highN == lowN) {
      rsv = 50;
    } else {
      rsv = (closes[i] - lowN) / (highN - lowN) * 100;
    }
    k = 2 / 3 * k + 1 / 3 * rsv;
    d = 2 / 3 * d + 1 / 3 * k;
  }

  final j = 3 * k - 2 * d;
  return {
    'k': double.parse(k.toStringAsFixed(4)),
    'd': double.parse(d.toStringAsFixed(4)),
    'j': double.parse(j.toStringAsFixed(4)),
  };
}

Map<String, double?> _calculateBoll(List<double> closes, {int period = 20}) {
  if (closes.length < period) {
    return {'upper': null, 'middle': null, 'lower': null};
  }

  final slice = closes.sublist(closes.length - period);
  final middle = slice.reduce((a, b) => a + b) / period;
  final variance =
      slice.map((x) => (x - middle) * (x - middle)).reduce((a, b) => a + b) /
          period;
  final std = math.sqrt(variance);

  return {
    'upper': double.parse((middle + 2 * std).toStringAsFixed(4)),
    'middle': double.parse(middle.toStringAsFixed(4)),
    'lower': double.parse((middle - 2 * std).toStringAsFixed(4)),
  };
}
