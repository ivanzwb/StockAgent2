/// 应用状态管理
import 'package:flutter/foundation.dart';
import '../agent/intent_router.dart';
import '../agent/stock_advisor.dart';
import '../agent/stock_monitor.dart';
import '../agent/sector_recommender.dart';
import '../models/schemas.dart';
import '../storage/local_store.dart';
import '../config/app_config.dart' as config;

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AppState extends ChangeNotifier {
  final StockAdvisor _advisor = StockAdvisor();
  final StockMonitor _monitor = StockMonitor();
  final SectorRecommender _recommender = SectorRecommender();

  int _currentTab = 0;
  int get currentTab => _currentTab;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  final Map<String, List<ChatMessage>> _chatMessages = {
    'analysis': [],
    'monitor': [],
    'sector': [],
  };

  List<ChatMessage> get currentMessages =>
      _chatMessages[_tabKeys[_currentTab]] ?? [];

  static const _tabKeys = ['analysis', 'monitor', 'sector'];
  String get currentTabKey => _tabKeys[_currentTab];

  /// 初始化
  Future<void> init() async {
    // 设置监控回调
    _monitor.onResult = _onMonitorResult;
    await _monitor.restoreTasks();

    // 加载历史记录
    for (final tab in _tabKeys) {
      final history = LocalStore().getChatHistory(tab: tab);
      _chatMessages[tab] = history
          .map((h) => ChatMessage(
                role: h['role'] as String,
                content: h['content'] as String,
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                    int.tryParse(h['timestamp'] as String? ?? '0') ?? 0),
              ))
          .toList();
    }
    notifyListeners();
  }

  void setCurrentTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  /// 发送消息
  Future<void> sendMessage(String message) async {
    if (_isProcessing || message.trim().isEmpty) return;

    final tabKey = currentTabKey;
    _addMessage(tabKey, 'user', message);
    _isProcessing = true;
    _addMessage(tabKey, 'assistant', '正在分析...', isLoading: true);
    notifyListeners();

    try {
      String response;
      switch (_currentTab) {
        case 0: // 分析
          response = await _handleAnalysis(message);
          break;
        case 1: // 监控
          response = await _handleMonitor(message);
          break;
        case 2: // 板块推荐
          response = await _handleSector(message);
          break;
        default:
          response = '未知功能';
      }

      // 移除loading消息，添加真正回复
      _chatMessages[tabKey]?.removeLast();
      _addMessage(tabKey, 'assistant', response);
    } catch (e) {
      _chatMessages[tabKey]?.removeLast();
      _addMessage(tabKey, 'assistant', '处理出错: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<String> _handleAnalysis(String message) async {
    return _advisor.analyze(message);
  }

  Future<String> _handleMonitor(String message) async {
    // 先判断是否要添加监控任务
    final codeRegex = RegExp(r'([036]\d{5})');
    final match = codeRegex.firstMatch(message);

    if (message.contains('监控') ||
        message.contains('盯着') ||
        message.contains('提醒')) {
      if (match != null) {
        final code = match.group(1)!;
        // 解析可能的价格条件
        double? buyBelow, sellAbove, stopLoss;
        final buyMatch = RegExp(r'低于(\d+\.?\d*)').firstMatch(message);
        final sellMatch = RegExp(r'高于(\d+\.?\d*)').firstMatch(message);
        final stopMatch = RegExp(r'止损(\d+\.?\d*)').firstMatch(message);

        if (buyMatch != null) buyBelow = double.tryParse(buyMatch.group(1)!);
        if (sellMatch != null) {
          sellAbove = double.tryParse(sellMatch.group(1)!);
        }
        if (stopMatch != null) stopLoss = double.tryParse(stopMatch.group(1)!);

        final taskId = _monitor.addTask(
          stockCode: code,
          stockName: code,
          buyBelow: buyBelow,
          sellAbove: sellAbove,
          stopLoss: stopLoss,
        );

        return '✅ 已添加监控任务\n'
            '📌 股票: $code\n'
            '${buyBelow != null ? '💰 低于 $buyBelow 提醒买入\n' : ''}'
            '${sellAbove != null ? '💰 高于 $sellAbove 提醒卖出\n' : ''}'
            '${stopLoss != null ? '🛑 止损价: $stopLoss\n' : ''}'
            '🔄 监控间隔: 每${config.AppConfig.monitorInterval}分钟\n'
            '📋 任务ID: $taskId';
      }
    }

    if (message.contains('任务列表') || message.contains('监控列表')) {
      final tasks = _monitor.getAllTasks();
      if (tasks.isEmpty) return '📋 当前没有监控任务';

      final sb = StringBuffer('📋 **监控任务列表**\n\n');
      for (final task in tasks) {
        final status =
            task.status == MonitorStatus.active ? '🟢 活跃' : '⏸️ 暂停';
        sb.writeln(
            '$status ${task.stockName}(${task.stockCode}) - ID: ${task.id}');
        if (task.lastCheckAt != null) {
          sb.writeln('  最后检查: ${task.lastCheckAt}');
        }
      }
      return sb.toString();
    }

    // 其他情况用顾问分析
    return _advisor.analyze(message);
  }

  Future<String> _handleSector(String message) async {
    return _recommender.recommend(message);
  }

  void _addMessage(String tabKey, String role, String content,
      {bool isLoading = false}) {
    _chatMessages[tabKey] ??= [];
    _chatMessages[tabKey]!.add(ChatMessage(
      role: role,
      content: content,
      isLoading: isLoading,
    ));
    if (!isLoading) {
      LocalStore().saveChatMessage(role, content, tab: tabKey);
    }
  }

  void _onMonitorResult(MonitorTask task, AnalysisResult result) {
    final emoji = switch (result.action) {
      StockAction.buy => '🟢',
      StockAction.sell => '🔴',
      StockAction.hold => '🟡',
    };

    final msg = '$emoji **监控提醒 - ${task.stockName}(${task.stockCode})**\n'
        '建议: ${result.action.name} (信心: ${(result.confidence * 100).toStringAsFixed(0)}%)\n'
        '理由: ${result.reason}\n'
        '${result.targetPrice != null ? '目标价: ${result.targetPrice}\n' : ''}'
        '时间: ${DateTime.now()}';

    _addMessage('monitor', 'assistant', msg);
    notifyListeners();
  }

  /// 清除聊天记录
  void clearChat() {
    _chatMessages[currentTabKey]?.clear();
    LocalStore().clearChatHistory(tab: currentTabKey);
    notifyListeners();
  }

  /// 获取监控任务列表
  List<MonitorTask> getMonitorTasks() => _monitor.getAllTasks();
}
