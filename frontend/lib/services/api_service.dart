import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// API 服务 - 与后端通信
class ApiService {
  String _baseUrl;

  ApiService({String baseUrl = 'http://localhost:3000'}) : _baseUrl = baseUrl;

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String url) {
    _baseUrl = url;
  }

  // ==================== 分析相关 ====================

  /// 分析单只股票
  Future<AnalysisResult> analyzeStock(String stock) async {
    final response = await _post('/api/analyze', {'stock': stock});
    return AnalysisResult.fromJson(response['data']);
  }

  /// 批量分析股票
  Future<List<AnalysisResult>> analyzeMultipleStocks(
      List<String> stocks) async {
    final response = await _post('/api/analyze/batch', {'stocks': stocks});
    return (response['data'] as List)
        .map((r) => AnalysisResult.fromJson(r))
        .toList();
  }

  /// 聊天式交互
  Future<Map<String, dynamic>> chat(String message) async {
    final response = await _post('/api/chat', {'message': message});
    return response['data'];
  }

  /// 获取分析历史
  Future<List<AnalysisResult>> getHistory(
      {String? code, int limit = 10}) async {
    final path = code != null ? '/api/history/$code' : '/api/history';
    final response = await _get('$path?limit=$limit');
    return (response['data'] as List)
        .map((r) => AnalysisResult.fromJson(r))
        .toList();
  }

  // ==================== 监控相关 ====================

  /// 获取监控列表
  Future<List<MonitorItem>> getMonitors() async {
    final response = await _get('/api/monitor');
    return (response['data'] as List)
        .map((m) => MonitorItem.fromJson(m))
        .toList();
  }

  /// 添加监控
  Future<Map<String, dynamic>> addMonitor(String code, String name) async {
    return await _post('/api/monitor/add', {'code': code, 'name': name});
  }

  /// 删除监控
  Future<Map<String, dynamic>> removeMonitor(String code) async {
    return await _post('/api/monitor/remove', {'code': code});
  }

  /// 启动监控
  Future<Map<String, dynamic>> startMonitor(String code) async {
    return await _post('/api/monitor/start', {'code': code});
  }

  /// 停止监控
  Future<Map<String, dynamic>> stopMonitor(String code) async {
    return await _post('/api/monitor/stop', {'code': code});
  }

  // ==================== 板块相关 ====================

  /// 获取板块列表
  Future<List<SectorInfo>> getSectors({String type = 'industry'}) async {
    final response = await _get('/api/sector/list?type=$type');
    return (response['data'] as List)
        .map((s) => SectorInfo.fromJson(s))
        .toList();
  }

  /// 分析板块推荐股票
  Future<Map<String, dynamic>> analyzeSector(String sectorCode,
      {int topN = 5}) async {
    final response = await _post(
        '/api/sector/analyze', {'sectorCode': sectorCode, 'topN': topN},
        timeout: const Duration(minutes: 5));
    return response['data'];
  }

  // ==================== 量化相关 ====================

  /// 获取可用策略列表
  Future<List<StrategyDef>> getStrategies() async {
    final response = await _get('/api/quant/strategies');
    return (response['data'] as List)
        .map((s) => StrategyDef.fromJson(s))
        .toList();
  }

  /// 获取量化任务列表
  Future<List<QuantTask>> getQuantTasks() async {
    final response = await _get('/api/quant/tasks');
    return (response['data'] as List)
        .map((t) => QuantTask.fromJson(t))
        .toList();
  }

  /// 添加量化任务
  Future<Map<String, dynamic>> addQuantTask(
      String code, String name, List<String> strategies) async {
    return await _post('/api/quant/add',
        {'code': code, 'name': name, 'strategies': strategies});
  }

  /// 删除量化任务
  Future<Map<String, dynamic>> removeQuantTask(String code) async {
    return await _post('/api/quant/remove', {'code': code});
  }

  /// 启动量化任务
  Future<Map<String, dynamic>> startQuantTask(String code) async {
    return await _post('/api/quant/start', {'code': code});
  }

  /// 停止量化任务
  Future<Map<String, dynamic>> stopQuantTask(String code) async {
    return await _post('/api/quant/stop', {'code': code});
  }

  // ==================== 配置相关 ====================

  /// 获取 LLM 配置
  Future<LLMConfig> getLLMConfig() async {
    final response = await _get('/api/config/llm');
    return LLMConfig.fromJson(response['data']);
  }

  /// 更新 LLM 配置
  Future<LLMConfig> updateLLMConfig(Map<String, dynamic> config) async {
    final response = await _put('/api/config/llm', config);
    return LLMConfig.fromJson(response['data']);
  }

  /// 获取工具列表
  Future<List<ToolSkill>> getTools() async {
    final response = await _get('/api/config/tools');
    return (response['data'] as List)
        .map((t) => ToolSkill.fromJson(t))
        .toList();
  }

  /// 更新工具状态
  Future<void> updateToolEnabled(String id, bool enabled) async {
    await _put('/api/config/tools/$id', {'enabled': enabled});
  }

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      await _get('/api/health');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== 内部方法 ====================

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? '请求失败');
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 120)}) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      final respBody = jsonDecode(response.body);
      throw Exception(respBody['error'] ?? '请求失败');
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      final respBody = jsonDecode(response.body);
      throw Exception(respBody['error'] ?? '请求失败');
    }

    return jsonDecode(response.body);
  }
}
