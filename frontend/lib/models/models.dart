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

  QuantTask({
    required this.code,
    required this.name,
    required this.strategies,
    required this.status,
    required this.createdAt,
    this.signals = const [],
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

  QuantSignal({
    required this.code,
    required this.name,
    required this.signals,
    required this.composite,
    this.price,
    required this.timestamp,
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
