/// 数据模型定义

enum StockAction {
  buy('买入'),
  sell('卖出'),
  hold('观望');

  final String label;
  const StockAction(this.label);

  static StockAction fromString(String s) {
    if (s.contains('买入')) return StockAction.buy;
    if (s.contains('卖出')) return StockAction.sell;
    return StockAction.hold;
  }
}

enum MonitorStatus { active, paused }

/// 股票实时行情
class StockQuote {
  final String code;
  final String name;
  final double currentPrice;
  final double openPrice;
  final double closePrice;
  final double highPrice;
  final double lowPrice;
  final double volume;
  final double amount;
  final double changePercent;
  final String timestamp;

  StockQuote({
    required this.code,
    required this.name,
    required this.currentPrice,
    required this.openPrice,
    required this.closePrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.amount,
    required this.changePercent,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'current_price': currentPrice,
        'open_price': openPrice,
        'close_price': closePrice,
        'high_price': highPrice,
        'low_price': lowPrice,
        'volume': volume,
        'amount': amount,
        'change_percent': changePercent,
        'timestamp': timestamp,
      };

  @override
  String toString() =>
      '$name($code) 现价:$currentPrice 涨跌:$changePercent% '
      '开:$openPrice 高:$highPrice 低:$lowPrice 量:${volume}手';
}

/// K线数据
class KlineData {
  final String date;
  final double open;
  final double close;
  final double high;
  final double low;
  final double volume;
  final double amount;
  final double changePercent;

  KlineData({
    required this.date,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
    this.amount = 0,
    this.changePercent = 0,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'open': open,
        'close': close,
        'high': high,
        'low': low,
        'volume': volume,
        'amount': amount,
        'change_percent': changePercent,
      };
}

/// 技术指标
class TechnicalIndicators {
  final String code;
  final double? ma5, ma10, ma20, ma60;
  final double? macd, macdSignal, macdHist;
  final double? rsi6, rsi12, rsi24;
  final double? kdjK, kdjD, kdjJ;
  final double? bollUpper, bollMiddle, bollLower;

  TechnicalIndicators({
    required this.code,
    this.ma5,
    this.ma10,
    this.ma20,
    this.ma60,
    this.macd,
    this.macdSignal,
    this.macdHist,
    this.rsi6,
    this.rsi12,
    this.rsi24,
    this.kdjK,
    this.kdjD,
    this.kdjJ,
    this.bollUpper,
    this.bollMiddle,
    this.bollLower,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'MA5': ma5,
        'MA10': ma10,
        'MA20': ma20,
        'MA60': ma60,
        'MACD_DIF': macd,
        'MACD_DEA': macdSignal,
        'MACD_HIST': macdHist,
        'RSI_6': rsi6,
        'RSI_12': rsi12,
        'RSI_24': rsi24,
        'KDJ_K': kdjK,
        'KDJ_D': kdjD,
        'KDJ_J': kdjJ,
        'BOLL_UPPER': bollUpper,
        'BOLL_MIDDLE': bollMiddle,
        'BOLL_LOWER': bollLower,
      };

  @override
  String toString() {
    final parts = <String>[];
    if (ma5 != null) parts.add('MA5=$ma5');
    if (ma10 != null) parts.add('MA10=$ma10');
    if (ma20 != null) parts.add('MA20=$ma20');
    if (ma60 != null) parts.add('MA60=$ma60');
    if (macd != null) parts.add('MACD DIF=$macd DEA=$macdSignal HIST=$macdHist');
    if (rsi6 != null) parts.add('RSI6=$rsi6 RSI12=$rsi12 RSI24=$rsi24');
    if (kdjK != null) parts.add('KDJ K=$kdjK D=$kdjD J=$kdjJ');
    if (bollUpper != null) {
      parts.add('BOLL UP=$bollUpper MID=$bollMiddle LOW=$bollLower');
    }
    return parts.join(', ');
  }
}

/// 基本面数据
class FundamentalData {
  final String code;
  final String name;
  final double? peRatio;
  final double? pbRatio;
  final double? totalMarketCap;
  final double? circulatingMarketCap;
  final double? revenue;
  final double? netProfit;
  final double? roe;
  final double? eps;
  final double? bvps;
  final double? debtRatio;

  FundamentalData({
    required this.code,
    this.name = '',
    this.peRatio,
    this.pbRatio,
    this.totalMarketCap,
    this.circulatingMarketCap,
    this.revenue,
    this.netProfit,
    this.roe,
    this.eps,
    this.bvps,
    this.debtRatio,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'PE': peRatio,
        'PB': pbRatio,
        'total_market_cap_yi': totalMarketCap,
        'circulating_market_cap_yi': circulatingMarketCap,
        'revenue_yi': revenue,
        'net_profit_yi': netProfit,
        'ROE_percent': roe,
        'EPS': eps,
        'BVPS': bvps,
        'debt_ratio_percent': debtRatio,
      };

  @override
  String toString() =>
      '$name($code) PE=$peRatio PB=$pbRatio 市值=${totalMarketCap}亿 '
      'ROE=$roe% EPS=$eps 营收=${revenue}亿 净利=${netProfit}亿';
}

/// 分析结果
class AnalysisResult {
  final String code;
  final String stockName;
  final StockAction action;
  final double confidence;
  final String reason;
  final double? targetPrice;
  final double? stopLoss;
  final DateTime timestamp;

  AnalysisResult({
    required this.code,
    this.stockName = '',
    required this.action,
    required this.confidence,
    required this.reason,
    this.targetPrice,
    this.stopLoss,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'code': code,
        'stock_name': stockName,
        'action': action.name,
        'confidence': confidence,
        'reason': reason,
        'target_price': targetPrice,
        'stop_loss': stopLoss,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      code: json['code'] ?? json['stock_code'] ?? '',
      stockName: json['stock_name'] ?? '',
      action: StockAction.values.firstWhere(
        (a) => a.name == json['action'],
        orElse: () => StockAction.fromString(json['action'] ?? 'hold'),
      ),
      confidence: ((json['confidence'] ?? 0.5) as num).toDouble(),
      reason: json['reason'] ?? '',
      targetPrice: (json['target_price'] as num?)?.toDouble(),
      stopLoss: (json['stop_loss'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

/// 监控任务
class MonitorTask {
  final String id;
  final String stockCode;
  String stockName;
  MonitorStatus status;
  final double? buyBelow;
  final double? sellAbove;
  final double? stopLoss;
  final DateTime createdAt;
  DateTime? lastCheckAt;

  MonitorTask({
    required this.id,
    required this.stockCode,
    this.stockName = '',
    this.buyBelow,
    this.sellAbove,
    this.stopLoss,
    this.status = MonitorStatus.paused,
    DateTime? createdAt,
    this.lastCheckAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'stock_code': stockCode,
        'stock_name': stockName,
        'buy_below': buyBelow,
        'sell_above': sellAbove,
        'stop_loss': stopLoss,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'last_check_at': lastCheckAt?.toIso8601String(),
      };

  factory MonitorTask.fromJson(Map<String, dynamic> json) {
    return MonitorTask(
      id: json['id'] ?? '',
      stockCode: json['stock_code'] ?? '',
      stockName: json['stock_name'] ?? '',
      buyBelow: (json['buy_below'] as num?)?.toDouble(),
      sellAbove: (json['sell_above'] as num?)?.toDouble(),
      stopLoss: (json['stop_loss'] as num?)?.toDouble(),
      status: json['status'] == 'active'
          ? MonitorStatus.active
          : MonitorStatus.paused,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      lastCheckAt: json['last_check_at'] != null
          ? DateTime.parse(json['last_check_at'])
          : null,
    );
  }
}
