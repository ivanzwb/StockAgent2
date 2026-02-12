/// 应用配置管理 - 使用Hive本地存储
import 'package:hive_flutter/hive_flutter.dart';

class AppConfig {
  static const String _boxName = 'app_config';
  static late Box _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  // LLM配置
  static String get llmProvider => _box.get('llm_provider', defaultValue: 'openai');
  static set llmProvider(String v) => _box.put('llm_provider', v);

  static String get apiKey => _box.get('api_key', defaultValue: '');
  static set apiKey(String v) => _box.put('api_key', v);

  static String get apiBase => _box.get('api_base', defaultValue: '');
  static set apiBase(String v) => _box.put('api_base', v);

  static String get modelName => _box.get('model_name', defaultValue: 'gpt-4o-mini');
  static set modelName(String v) => _box.put('model_name', v);

  static double get temperature =>
      (_box.get('temperature', defaultValue: 0.3) as num).toDouble();
  static set temperature(double v) => _box.put('temperature', v);

  static int get maxTokens => _box.get('max_tokens', defaultValue: 4096);
  static set maxTokens(int v) => _box.put('max_tokens', v);

  // 监控配置
  static int get monitorInterval =>
      _box.get('monitor_interval', defaultValue: 60);
  static set monitorInterval(int v) => _box.put('monitor_interval', v);

  /// 检查LLM是否已配置
  static bool get isConfigured => apiKey.isNotEmpty;

  /// 获取有效的API Base URL
  static String? get effectiveApiBase {
    if (apiBase.isNotEmpty) return apiBase;
    if (llmProvider == 'deepseek') return 'https://api.deepseek.com/v1';
    return null; // 使用langchain_openai默认值
  }
}
