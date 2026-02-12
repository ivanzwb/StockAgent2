/// 股票监控器 - Feature 2: 定时监控股票，自动给出买卖建议
import 'dart:async';
import '../config/app_config.dart';
import '../models/schemas.dart';
import 'stock_advisor.dart';
import '../storage/local_store.dart';

/// 监控回调
typedef MonitorCallback = void Function(MonitorTask task, AnalysisResult result);

class StockMonitor {
  static final StockMonitor _instance = StockMonitor._internal();
  factory StockMonitor() => _instance;
  StockMonitor._internal();

  final StockAdvisor _advisor = StockAdvisor();
  Timer? _timer;
  final Map<String, MonitorTask> _tasks = {};
  MonitorCallback? onResult;

  /// 添加监控任务
  String addTask({
    required String stockCode,
    required String stockName,
    double? buyBelow,
    double? sellAbove,
    double? stopLoss,
  }) {
    final id = '${stockCode}_${DateTime.now().millisecondsSinceEpoch}';
    final task = MonitorTask(
      id: id,
      stockCode: stockCode,
      stockName: stockName,
      buyBelow: buyBelow,
      sellAbove: sellAbove,
      stopLoss: stopLoss,
      status: MonitorStatus.active,
      createdAt: DateTime.now(),
    );
    _tasks[id] = task;
    LocalStore().saveMonitorTask(task);

    // 如果定时器未启动，启动
    _ensureTimerRunning();
    return id;
  }

  /// 移除监控任务
  void removeTask(String taskId) {
    _tasks.remove(taskId);
    LocalStore().deleteMonitorTask(taskId);
    if (_tasks.isEmpty) {
      _stopTimer();
    }
  }

  /// 暂停监控任务
  void pauseTask(String taskId) {
    if (_tasks.containsKey(taskId)) {
      _tasks[taskId] = MonitorTask(
        id: _tasks[taskId]!.id,
        stockCode: _tasks[taskId]!.stockCode,
        stockName: _tasks[taskId]!.stockName,
        buyBelow: _tasks[taskId]!.buyBelow,
        sellAbove: _tasks[taskId]!.sellAbove,
        stopLoss: _tasks[taskId]!.stopLoss,
        status: MonitorStatus.paused,
        createdAt: _tasks[taskId]!.createdAt,
        lastCheckAt: _tasks[taskId]!.lastCheckAt,
      );
    }
  }

  /// 恢复监控任务
  void resumeTask(String taskId) {
    if (_tasks.containsKey(taskId)) {
      _tasks[taskId] = MonitorTask(
        id: _tasks[taskId]!.id,
        stockCode: _tasks[taskId]!.stockCode,
        stockName: _tasks[taskId]!.stockName,
        buyBelow: _tasks[taskId]!.buyBelow,
        sellAbove: _tasks[taskId]!.sellAbove,
        stopLoss: _tasks[taskId]!.stopLoss,
        status: MonitorStatus.active,
        createdAt: _tasks[taskId]!.createdAt,
        lastCheckAt: _tasks[taskId]!.lastCheckAt,
      );
    }
  }

  /// 获取所有任务
  List<MonitorTask> getAllTasks() => _tasks.values.toList();

  /// 获取活跃任务数
  int get activeTaskCount =>
      _tasks.values.where((t) => t.status == MonitorStatus.active).length;

  void _ensureTimerRunning() {
    if (_timer != null && _timer!.isActive) return;
    final interval = Duration(minutes: AppConfig.monitorInterval);
    _timer = Timer.periodic(interval, (_) => _checkAllTasks());
    // 首次立即检查
    _checkAllTasks();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkAllTasks() async {
    final activeTasks =
        _tasks.values.where((t) => t.status == MonitorStatus.active).toList();
    if (activeTasks.isEmpty) return;

    for (final task in activeTasks) {
      try {
        final result = await _advisor.quickAnalyze(task.stockCode);
        if (result == null) continue;

        // 更新最后检查时间
        _tasks[task.id] = MonitorTask(
          id: task.id,
          stockCode: task.stockCode,
          stockName: task.stockName,
          buyBelow: task.buyBelow,
          sellAbove: task.sellAbove,
          stopLoss: task.stopLoss,
          status: task.status,
          createdAt: task.createdAt,
          lastCheckAt: DateTime.now(),
        );

        // 保存分析结果
        LocalStore().saveAnalysisResult(result);

        // 回调通知
        onResult?.call(task, result);
      } catch (e) {
        // 忽略单个任务错误
      }
    }
  }

  /// 从存储恢复任务
  Future<void> restoreTasks() async {
    final tasks = LocalStore().getMonitorTasks();
    for (final task in tasks) {
      _tasks[task.id] = task;
    }
    if (_tasks.values.any((t) => t.status == MonitorStatus.active)) {
      _ensureTimerRunning();
    }
  }

  /// 销毁
  void dispose() {
    _stopTimer();
  }
}
