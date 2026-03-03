import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/background_service.dart';

const String _keyServerHost = 'server_host';
const String _keyServerPort = 'server_port';
const String _keyServerUseSsl = 'server_use_ssl';

/// 应用全局状态管理
class AppState extends ChangeNotifier {
  final ApiService api;
  final WebSocketService ws;

  // 连接状态
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // WebSocket 服务访问
  WebSocketService get wsService => ws;

  // 分析相关
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;
  AnalysisResult? _lastAnalysis;
  AnalysisResult? get lastAnalysis => _lastAnalysis;
  List<AnalysisResult> _analysisHistory = [];
  List<AnalysisResult> get analysisHistory => _analysisHistory;

  // 监控相关
  List<MonitorItem> _monitors = [];
  List<MonitorItem> get monitors => _monitors;

  // 板块相关
  List<SectorInfo> _sectors = [];
  List<SectorInfo> get sectors => _sectors;

  // 量化相关
  List<QuantTask> _quantTasks = [];
  List<QuantTask> get quantTasks => _quantTasks;
  List<StrategyDef> _strategies = [];
  List<StrategyDef> get strategies => _strategies;

  // 配置相关
  LLMConfig? _llmConfig;
  LLMConfig? get llmConfig => _llmConfig;
  List<ToolSkill> _tools = [];
  List<ToolSkill> get tools => _tools;

  // 聊天消息
  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  // 错误信息
  String? _error;
  String? get error => _error;

  StreamSubscription? _wsSubscription;
  static SharedPreferences? _prefs;
  final BackgroundServiceManager _bgService = BackgroundServiceManager();
  bool _isBgServiceRunning = false;
  bool get isBgServiceRunning => _isBgServiceRunning;

  AppState({required this.api, required this.ws}) {
    _initWebSocket();
    _initBackgroundService();
  }

  Future<void> _initBackgroundService() async {
    await initializeService();
  }

  Future<void> startBackgroundService() async {
    await _bgService.startService();
    _isBgServiceRunning = true;
    notifyListeners();
  }

  Future<void> stopBackgroundService() async {
    await _bgService.stopService();
    _isBgServiceRunning = false;
    notifyListeners();
  }

  static Future<Map<String, dynamic>> loadServerConfig() async {
    _prefs ??= await SharedPreferences.getInstance();
    final host = _prefs!.getString(_keyServerHost) ?? 'localhost';
    final port = _prefs!.getInt(_keyServerPort) ?? 3000;
    final useSsl = _prefs!.getBool(_keyServerUseSsl) ?? false;
    return {
      'host': host,
      'port': port,
      'useSsl': useSsl,
    };
  }

  Future<Map<String, dynamic>> getServerConfig() async {
    _prefs ??= await SharedPreferences.getInstance();
    return {
      'host': _prefs!.getString(_keyServerHost) ?? 'localhost',
      'port': _prefs!.getInt(_keyServerPort) ?? 3000,
      'useSsl': _prefs!.getBool(_keyServerUseSsl) ?? false,
    };
  }

  void _initWebSocket() {
    ws.connect();
    _wsSubscription = ws.events.listen((event) {
      _handleWsEvent(event);
    });
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final eventName = event['event'];
    final data = event['data'];

    if (type == 'monitor') {
      if (eventName == 'analysis_completed') {
        // 刷新监控列表
        loadMonitors();
        _addSystemMessage('📊 ${data['name']} 分析完成');
      }
    } else if (type == 'quant') {
      if (eventName == 'strategies_completed') {
        loadQuantTasks();
        final composite = data['composite'] ?? {};
        final signal = composite['signal'] ?? 'hold';
        final icon = signal == 'buy'
            ? '🟢'
            : signal == 'sell'
                ? '🔴'
                : '🟡';
        _addSystemMessage('$icon ${data['name']} 量化信号: ${composite['reason']}');
      }
    }

    notifyListeners();
  }

  // ==================== 连接管理 ====================

  Future<void> checkConnection() async {
    _isConnected = await api.healthCheck();
    notifyListeners();
  }

  void updateServerUrl(String host, int port, bool useSsl) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_keyServerHost, host);
    await _prefs!.setInt(_keyServerPort, port);
    await _prefs!.setBool(_keyServerUseSsl, useSsl);

    final protocol = useSsl ? 'https' : 'http';
    final wsProtocol = useSsl ? 'wss' : 'ws';
    final httpUrl = '$protocol://$host:$port';
    final wsUrl = '$wsProtocol://$host:$port/ws';
    api.updateBaseUrl(httpUrl);
    ws.updateUrl(wsUrl);
    ws.resetReconnectState();
    ws.disconnect();
    ws.connect(manual: true);
    checkConnection();
    loadConfig();
  }

  // ==================== 分析功能 ====================

  Future<void> analyzeStock(String stock) async {
    _isAnalyzing = true;
    _error = null;
    notifyListeners();

    try {
      final result = await api.analyzeStock(stock);
      _lastAnalysis = result;
      _analysisHistory.insert(0, result);
      _addAssistantMessage(result.analysis);
    } catch (e) {
      _error = e.toString();
      _addSystemMessage('❌ 分析失败: $_error');
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// 聊天式交互
  Future<void> sendMessage(String message) async {
    _addUserMessage(message);
    _isAnalyzing = true;
    _error = null;
    notifyListeners();

    try {
      final intentData = await api.chat(message);
      final intent = intentData['intent'];

      if (intent != null) {
        final intentType = intent['intent'];
        final stocks = List<String>.from(intent['stocks'] ?? []);

        switch (intentType) {
          case 'analyze':
            if (stocks.isNotEmpty) {
              for (final stock in stocks) {
                await analyzeStock(stock);
              }
            }
            break;
          case 'monitor':
            await _handleMonitorIntent(intent);
            break;
          case 'sector':
            await _handleSectorIntent(intent);
            break;
          case 'quant':
            await _handleQuantIntent(intent);
            break;
          default:
            _addAssistantMessage('我不太理解你的意思，请尝试：\n'
                '1. 分析 [股票名称/代码]\n'
                '2. 监控 [股票名称/代码]\n'
                '3. 推荐 [板块名称] 的股票\n'
                '4. 用量化策略监控 [股票名称/代码]');
        }
      }
    } catch (e) {
      _error = e.toString();
      _addSystemMessage('❌ 处理失败: $_error');
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> _handleMonitorIntent(Map<String, dynamic> intent) async {
    final stocks = List<String>.from(intent['stocks'] ?? []);
    final action = intent['action'] ?? 'add';

    for (final stock in stocks) {
      switch (action) {
        case 'add':
          await api.addMonitor(stock, stock);
          _addSystemMessage('✅ 已添加 $stock 到监控列表');
          break;
        case 'remove':
          await api.removeMonitor(stock);
          _addSystemMessage('✅ 已移除 $stock 的监控');
          break;
        case 'start':
          await api.startMonitor(stock);
          _addSystemMessage('✅ 已启动 $stock 的监控');
          break;
        case 'stop':
          await api.stopMonitor(stock);
          _addSystemMessage('✅ 已停止 $stock 的监控');
          break;
      }
    }
    await loadMonitors();
  }

  Future<void> _handleSectorIntent(Map<String, dynamic> intent) async {
    final sector = intent['sector'] ?? '';
    _addSystemMessage('🔍 正在分析 $sector 板块...');
    notifyListeners();

    // Search for sector
    final type = intent['sectorType'] ?? 'industry';
    final sectors = await api.getSectors(type: type);
    final matched = sectors
        .where((s) => s.name.contains(sector) || sector.contains(s.name))
        .toList();

    if (matched.isEmpty) {
      _addAssistantMessage('未找到板块: $sector');
      return;
    }

    final targetSector = matched.first;
    final result = await api.analyzeSector(targetSector.code, topN: 5);
    _addAssistantMessage(
        '${targetSector.name} 板块分析完成:\n${_formatSectorResult(result)}');
  }

  Future<void> _handleQuantIntent(Map<String, dynamic> intent) async {
    final stocks = List<String>.from(intent['stocks'] ?? []);
    final strategies = List<String>.from(
        intent['strategies'] ?? ['macd_cross', 'ma_trend', 'rsi_oversold']);
    final action = intent['action'] ?? 'add';

    for (final stock in stocks) {
      switch (action) {
        case 'add':
          await api.addQuantTask(stock, stock, strategies);
          await api.startQuantTask(stock);
          _addSystemMessage('✅ 已启动 $stock 的量化监控');
          break;
        case 'stop':
          await api.stopQuantTask(stock);
          _addSystemMessage('✅ 已停止 $stock 的量化监控');
          break;
        case 'remove':
          await api.removeQuantTask(stock);
          _addSystemMessage('✅ 已删除 $stock 的量化任务');
          break;
      }
    }
    await loadQuantTasks();
  }

  String _formatSectorResult(Map<String, dynamic> result) {
    final stocks = result['stocks'] as List? ?? [];
    if (stocks.isEmpty) return '暂无推荐';

    final buffer = StringBuffer();
    for (final stock in stocks) {
      final name = stock['name'] ?? '';
      final code = stock['code'] ?? '';
      buffer.writeln('- $name($code)');
    }
    return buffer.toString();
  }

  // ==================== 监控功能 ====================

  Future<void> loadMonitors() async {
    try {
      _monitors = await api.getMonitors();
      notifyListeners();
    } catch (e) {
      print('加载监控列表失败: $e');
    }
  }

  // ==================== 板块功能 ====================

  Future<void> loadSectors({String type = 'industry'}) async {
    try {
      _sectors = await api.getSectors(type: type);
      notifyListeners();
    } catch (e) {
      print('加载板块列表失败: $e');
    }
  }

  // ==================== 量化功能 ====================

  Future<void> loadQuantTasks() async {
    try {
      _quantTasks = await api.getQuantTasks();
      notifyListeners();
    } catch (e) {
      print('加载量化任务失败: $e');
    }
  }

  Future<void> loadStrategies() async {
    try {
      _strategies = await api.getStrategies();
      notifyListeners();
    } catch (e) {
      print('加载策略列表失败: $e');
    }
  }

  // ==================== 配置功能 ====================

  Future<void> loadConfig() async {
    try {
      _llmConfig = await api.getLLMConfig();
      _tools = await api.getTools();
      notifyListeners();
    } catch (e) {
      print('加载配置失败: $e');
    }
  }

  Future<void> saveLLMConfig(Map<String, dynamic> config) async {
    try {
      _llmConfig = await api.updateLLMConfig(config);
      _addSystemMessage('✅ LLM 配置已更新');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleTool(String id, bool enabled) async {
    try {
      await api.updateToolEnabled(id, enabled);
      final tool = _tools.firstWhere((t) => t.id == id);
      tool.enabled = enabled;
      notifyListeners();
    } catch (e) {
      print('更新工具状态失败: $e');
    }
  }

  // ==================== 消息管理 ====================

  void _addUserMessage(String text) {
    _messages.add(
        ChatMessage(role: 'user', content: text, timestamp: DateTime.now()));
  }

  void _addAssistantMessage(String text) {
    _messages.add(ChatMessage(
        role: 'assistant', content: text, timestamp: DateTime.now()));
  }

  void _addSystemMessage(String text) {
    _messages.add(
        ChatMessage(role: 'system', content: text, timestamp: DateTime.now()));
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    ws.dispose();
    super.dispose();
  }
}

/// 聊天消息
class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}
