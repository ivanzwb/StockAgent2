/// 本地存储 - 使用Hive进行数据持久化
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/schemas.dart';

class LocalStore {
  static final LocalStore _instance = LocalStore._internal();
  factory LocalStore() => _instance;
  LocalStore._internal();

  static const String _analysisBoxName = 'analysis_results';
  static const String _monitorBoxName = 'monitor_tasks';
  static const String _chatBoxName = 'chat_history';

  Box? _analysisBox;
  Box? _monitorBox;
  Box? _chatBox;

  /// 初始化
  static Future<void> init() async {
    await Hive.initFlutter();
    final store = LocalStore();
    store._analysisBox = await Hive.openBox(_analysisBoxName);
    store._monitorBox = await Hive.openBox(_monitorBoxName);
    store._chatBox = await Hive.openBox(_chatBoxName);
  }

  // === 分析结果 ===

  void saveAnalysisResult(AnalysisResult result) {
    final key = '${result.code}_${result.timestamp.millisecondsSinceEpoch}';
    _analysisBox?.put(key, jsonEncode(result.toJson()));
  }

  List<AnalysisResult> getAnalysisResults({String? code, int limit = 20}) {
    final box = _analysisBox;
    if (box == null) return [];

    final results = <AnalysisResult>[];
    final keys = box.keys.toList().reversed.take(100);
    for (final key in keys) {
      final jsonStr = box.get(key) as String?;
      if (jsonStr == null) continue;
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final result = AnalysisResult.fromJson(json);
        if (code == null || result.code == code) {
          results.add(result);
        }
      } catch (_) {}
    }
    return results.take(limit).toList();
  }

  // === 监控任务 ===

  void saveMonitorTask(MonitorTask task) {
    _monitorBox?.put(task.id, jsonEncode(task.toJson()));
  }

  void deleteMonitorTask(String taskId) {
    _monitorBox?.delete(taskId);
  }

  List<MonitorTask> getMonitorTasks() {
    final box = _monitorBox;
    if (box == null) return [];

    final tasks = <MonitorTask>[];
    for (final key in box.keys) {
      final jsonStr = box.get(key) as String?;
      if (jsonStr == null) continue;
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        tasks.add(MonitorTask.fromJson(json));
      } catch (_) {}
    }
    return tasks;
  }

  // === 聊天记录 ===

  void saveChatMessage(String role, String content, {String? tab}) {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    _chatBox?.put(key, jsonEncode({
      'role': role,
      'content': content,
      'tab': tab ?? 'analysis',
      'timestamp': key,
    }));
  }

  List<Map<String, dynamic>> getChatHistory({String? tab, int limit = 50}) {
    final box = _chatBox;
    if (box == null) return [];

    final messages = <Map<String, dynamic>>[];
    final keys = box.keys.toList().reversed.take(200);
    for (final key in keys) {
      final jsonStr = box.get(key) as String?;
      if (jsonStr == null) continue;
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (tab == null || json['tab'] == tab) {
          messages.add(json);
        }
      } catch (_) {}
    }
    return messages.reversed.take(limit).toList();
  }

  void clearChatHistory({String? tab}) {
    final box = _chatBox;
    if (box == null) return;
    if (tab == null) {
      box.clear();
    } else {
      final keysToDelete = <dynamic>[];
      for (final key in box.keys) {
        final jsonStr = box.get(key) as String?;
        if (jsonStr == null) continue;
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (json['tab'] == tab) keysToDelete.add(key);
        } catch (_) {}
      }
      for (final key in keysToDelete) {
        box.delete(key);
      }
    }
  }
}
