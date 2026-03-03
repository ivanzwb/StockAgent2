/// 股票分析结果模型
class AnalysisResult {
  final String code;
  final String name;
  final String fullCode;
  final String analysis;
  final String timestamp;
  final Map<String, dynamic>? data;
  final String? error;

  AnalysisResult({
    required this.code,
    required this.name,
    this.fullCode = '',
    required this.analysis,
    required this.timestamp,
    this.data,
    this.error,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      fullCode: json['fullCode'] ?? '',
      analysis: json['analysis'] ?? '',
      timestamp: json['timestamp'] ?? '',
      data: json['data'],
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'fullCode': fullCode,
        'analysis': analysis,
        'timestamp': timestamp,
        'data': data,
        'error': error,
      };
}

/// 股票搜索结果
class StockSearchResult {
  final String code;
  final String name;
  final String market;

  StockSearchResult({
    required this.code,
    required this.name,
    required this.market,
  });

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      market: json['market'] ?? '',
    );
  }
}

/// 监控项
class MonitorItem {
  final String code;
  final String name;
  final String status;
  final String createdAt;
  final List<AnalysisResult> results;

  MonitorItem({
    required this.code,
    required this.name,
    required this.status,
    required this.createdAt,
    this.results = const [],
  });

  factory MonitorItem.fromJson(Map<String, dynamic> json) {
    return MonitorItem(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'stopped',
      createdAt: json['createdAt'] ?? '',
      results: (json['results'] as List<dynamic>?)
              ?.map((r) => AnalysisResult.fromJson(r))
              .toList() ??
          [],
    );
  }
}

/// 板块信息
class SectorInfo {
  final String code;
  final String name;
  final double changePercent;
  final String leaderStock;

  SectorInfo({
    required this.code,
    required this.name,
    required this.changePercent,
    this.leaderStock = '',
  });

  factory SectorInfo.fromJson(Map<String, dynamic> json) {
    return SectorInfo(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      changePercent: (json['changePercent'] ?? 0).toDouble(),
      leaderStock: json['leaderStock'] ?? '',
    );
  }
}

/// 量化任务
class QuantTask {
  final String code;
  final String name;
  final List<String> strategies;
  final String status;
  final String createdAt;
  final List<QuantSignal> signals;
  final RiskControl? riskControl;
  final Position? position;

  QuantTask({
    required this.code,
    required this.name,
    required this.strategies,
    required this.status,
    required this.createdAt,
    this.signals = const [],
    this.riskControl,
    this.position,
  });

  factory QuantTask.fromJson(Map<String, dynamic> json) {
    return QuantTask(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      strategies: List<String>.from(json['strategies'] ?? []),
      status: json['status'] ?? 'stopped',
      createdAt: json['createdAt'] ?? '',
      signals: (json['signals'] as List<dynamic>?)
              ?.map((s) => QuantSignal.fromJson(s))
              .toList() ??
          [],
      riskControl: json['riskControl'] != null
          ? RiskControl.fromJson(json['riskControl'])
          : null,
      position:
          json['position'] != null ? Position.fromJson(json['position']) : null,
    );
  }
}

/// 风控配置
class RiskControl {
  final double stopLossPercent;
  final double takeProfitPercent;
  final double maxPositionPercent;
  final bool enableStopLoss;
  final bool enableTakeProfit;
  final int signalConfirmCount;

  RiskControl({
    this.stopLossPercent = -5,
    this.takeProfitPercent = 10,
    this.maxPositionPercent = 30,
    this.enableStopLoss = true,
    this.enableTakeProfit = true,
    this.signalConfirmCount = 1,
  });

  factory RiskControl.fromJson(Map<String, dynamic> json) {
    return RiskControl(
      stopLossPercent: (json['stopLossPercent'] ?? -5).toDouble(),
      takeProfitPercent: (json['takeProfitPercent'] ?? 10).toDouble(),
      maxPositionPercent: (json['maxPositionPercent'] ?? 30).toDouble(),
      enableStopLoss: json['enableStopLoss'] ?? true,
      enableTakeProfit: json['enableTakeProfit'] ?? true,
      signalConfirmCount: json['signalConfirmCount'] ?? 1,
    );
  }
}

/// 持仓信息
class Position {
  final double? entryPrice;
  final int quantity;
  final String? positionType;
  final String? entryDate;

  Position({
    this.entryPrice,
    this.quantity = 0,
    this.positionType,
    this.entryDate,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      entryPrice: json['entryPrice']?.toDouble(),
      quantity: json['quantity'] ?? 0,
      positionType: json['positionType'],
      entryDate: json['entryDate'],
    );
  }
}

/// 量化信号
class QuantSignal {
  final String code;
  final String name;
  final List<StrategySignal> signals;
  final Map<String, dynamic> composite;
  final double? price;
  final String timestamp;
  final RiskCheck? riskCheck;
  final SignalConfirm? signalConfirm;

  QuantSignal({
    required this.code,
    required this.name,
    required this.signals,
    required this.composite,
    this.price,
    required this.timestamp,
    this.riskCheck,
    this.signalConfirm,
  });

  factory QuantSignal.fromJson(Map<String, dynamic> json) {
    return QuantSignal(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      signals: (json['signals'] as List<dynamic>?)
              ?.map((s) => StrategySignal.fromJson(s))
              .toList() ??
          [],
      composite: json['composite'] ?? {},
      price: json['price']?.toDouble(),
      timestamp: json['timestamp'] ?? '',
      riskCheck: json['riskCheck'] != null
          ? RiskCheck.fromJson(json['riskCheck'])
          : null,
      signalConfirm: json['signalConfirm'] != null
          ? SignalConfirm.fromJson(json['signalConfirm'])
          : null,
    );
  }
}

/// 风控检查结果
class RiskCheck {
  final bool triggered;
  final String? action;
  final String? reason;
  final double? profitPercent;

  RiskCheck({
    this.triggered = false,
    this.action,
    this.reason,
    this.profitPercent,
  });

  factory RiskCheck.fromJson(Map<String, dynamic> json) {
    return RiskCheck(
      triggered: json['triggered'] ?? false,
      action: json['action'],
      reason: json['reason'],
      profitPercent: json['profitPercent']?.toDouble(),
    );
  }
}

/// 信号确认结果
class SignalConfirm {
  final bool confirmed;
  final String? reason;

  SignalConfirm({
    this.confirmed = false,
    this.reason,
  });

  factory SignalConfirm.fromJson(Map<String, dynamic> json) {
    return SignalConfirm(
      confirmed: json['confirmed'] ?? false,
      reason: json['reason'],
    );
  }
}

/// 策略信号
class StrategySignal {
  final String strategy;
  final String strategyName;
  final String signal;
  final String reason;
  final int confidence;

  StrategySignal({
    required this.strategy,
    required this.strategyName,
    required this.signal,
    required this.reason,
    required this.confidence,
  });

  factory StrategySignal.fromJson(Map<String, dynamic> json) {
    return StrategySignal(
      strategy: json['strategy'] ?? '',
      strategyName: json['strategyName'] ?? '',
      signal: json['signal'] ?? 'hold',
      reason: json['reason'] ?? '',
      confidence: json['confidence'] ?? 5,
    );
  }
}

/// 量化策略定义
class StrategyDef {
  final String id;
  final String name;
  final String description;

  StrategyDef({
    required this.id,
    required this.name,
    required this.description,
  });

  factory StrategyDef.fromJson(Map<String, dynamic> json) {
    return StrategyDef(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

/// LLM 配置
class LLMConfig {
  String provider;
  Map<String, dynamic> deepseek;
  Map<String, dynamic> openai;
  Map<String, dynamic> custom;

  LLMConfig({
    required this.provider,
    required this.deepseek,
    required this.openai,
    required this.custom,
  });

  factory LLMConfig.fromJson(Map<String, dynamic> json) {
    return LLMConfig(
      provider: json['provider'] ?? 'deepseek',
      deepseek: Map<String, dynamic>.from(json['deepseek'] ?? {}),
      openai: Map<String, dynamic>.from(json['openai'] ?? {}),
      custom: Map<String, dynamic>.from(json['custom'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'deepseek': deepseek,
        'openai': openai,
        'custom': custom,
      };
}

/// 工具技能
class ToolSkill {
  final String id;
  final String name;
  final String description;
  final String category;
  bool enabled;

  ToolSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.enabled,
  });

  factory ToolSkill.fromJson(Map<String, dynamic> json) {
    return ToolSkill(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      enabled: json['enabled'] ?? true,
    );
  }
}

/// 回测结果
class BacktestResult {
  final bool success;
  final BacktestSummary? summary;
  final List<TradeLogItem> tradeLog;
  final String? message;

  BacktestResult({
    required this.success,
    this.summary,
    this.tradeLog = const [],
    this.message,
  });

  factory BacktestResult.fromJson(Map<String, dynamic> json) {
    return BacktestResult(
      success: json['success'] ?? false,
      summary: json['summary'] != null
          ? BacktestSummary.fromJson(json['summary'])
          : null,
      tradeLog: (json['tradeLog'] as List<dynamic>?)
              ?.map((t) => TradeLogItem.fromJson(t))
              .toList() ??
          [],
      message: json['message'],
    );
  }
}

/// 回测统计摘要
class BacktestSummary {
  final int totalTrades;
  final int winTrades;
  final int loseTrades;
  final double winRate;
  final double totalProfit;
  final double avgProfit;
  final double maxProfit;
  final double maxLoss;
  final double maxDrawdown;
  final double sharpeRatio;
  final double benchmarkReturn;
  final double excessReturn;

  BacktestSummary({
    this.totalTrades = 0,
    this.winTrades = 0,
    this.loseTrades = 0,
    this.winRate = 0,
    this.totalProfit = 0,
    this.avgProfit = 0,
    this.maxProfit = 0,
    this.maxLoss = 0,
    this.maxDrawdown = 0,
    this.sharpeRatio = 0,
    this.benchmarkReturn = 0,
    this.excessReturn = 0,
  });

  factory BacktestSummary.fromJson(Map<String, dynamic> json) {
    return BacktestSummary(
      totalTrades: json['totalTrades'] ?? 0,
      winTrades: json['winTrades'] ?? 0,
      loseTrades: json['loseTrades'] ?? 0,
      winRate: (json['winRate'] ?? 0).toDouble(),
      totalProfit: (json['totalProfit'] ?? 0).toDouble(),
      avgProfit: (json['avgProfit'] ?? 0).toDouble(),
      maxProfit: (json['maxProfit'] ?? 0).toDouble(),
      maxLoss: (json['maxLoss'] ?? 0).toDouble(),
      maxDrawdown: (json['maxDrawdown'] ?? 0).toDouble(),
      sharpeRatio: (json['sharpeRatio'] ?? 0).toDouble(),
      benchmarkReturn: (json['benchmarkReturn'] ?? 0).toDouble(),
      excessReturn: (json['excessReturn'] ?? 0).toDouble(),
    );
  }
}

/// 交易记录
class TradeLogItem {
  final String date;
  final String action;
  final double price;
  final double? profitPercent;
  final String? reason;

  TradeLogItem({
    required this.date,
    required this.action,
    required this.price,
    this.profitPercent,
    this.reason,
  });

  factory TradeLogItem.fromJson(Map<String, dynamic> json) {
    return TradeLogItem(
      date: json['date'] ?? '',
      action: json['action'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      profitPercent: json['profitPercent']?.toDouble(),
      reason: json['reason'],
    );
  }
}

/// 信号统计
class SignalStats {
  final bool success;
  final SignalStatsData? stats;
  final List<RecentSignal> recentSignals;
  final String? message;

  SignalStats({
    required this.success,
    this.stats,
    this.recentSignals = const [],
    this.message,
  });

  factory SignalStats.fromJson(Map<String, dynamic> json) {
    return SignalStats(
      success: json['success'] ?? false,
      stats: json['stats'] != null
          ? SignalStatsData.fromJson(json['stats'])
          : null,
      recentSignals: (json['recentSignals'] as List<dynamic>?)
              ?.map((s) => RecentSignal.fromJson(s))
              .toList() ??
          [],
      message: json['message'],
    );
  }
}

class SignalStatsData {
  final int totalDays;
  final int buyDays;
  final int sellDays;
  final int holdDays;
  final double buyRatio;
  final double sellRatio;

  SignalStatsData({
    this.totalDays = 0,
    this.buyDays = 0,
    this.sellDays = 0,
    this.holdDays = 0,
    this.buyRatio = 0,
    this.sellRatio = 0,
  });

  factory SignalStatsData.fromJson(Map<String, dynamic> json) {
    return SignalStatsData(
      totalDays: json['totalDays'] ?? 0,
      buyDays: json['buyDays'] ?? 0,
      sellDays: json['sellDays'] ?? 0,
      holdDays: json['holdDays'] ?? 0,
      buyRatio: (json['buyRatio'] ?? 0).toDouble(),
      sellRatio: (json['sellRatio'] ?? 0).toDouble(),
    );
  }
}

class RecentSignal {
  final String date;
  final String strategy;
  final String signal;
  final String? reason;

  RecentSignal({
    required this.date,
    required this.strategy,
    required this.signal,
    this.reason,
  });

  factory RecentSignal.fromJson(Map<String, dynamic> json) {
    return RecentSignal(
      date: json['date'] ?? '',
      strategy: json['strategy'] ?? '',
      signal: json['signal'] ?? '',
      reason: json['reason'],
    );
  }
}
