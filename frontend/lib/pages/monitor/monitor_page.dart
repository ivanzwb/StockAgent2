import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

/// 监控页面 - 股票监控管理
class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  Map<String, Map<String, dynamic>> _quotes = {};
  final Set<String> _expandedMonitors = {};
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadMonitors().then((_) {
        _loadQuotes();
      });
    });
    _wsSubscription = context.read<AppState>().wsService.events.listen((event) {
      if (event['type'] == 'monitor' &&
          event['event'] == 'analysis_completed') {
        context.read<AppState>().loadMonitors();
        _loadQuotes();
      }
    });
  }

  Future<void> _loadQuotes() async {
    final monitors = context.read<AppState>().monitors;
    for (final monitor in monitors) {
      try {
        final quote =
            await context.read<AppState>().api.getStockQuote(monitor.code);
        if (mounted) {
          setState(() {
            _quotes[monitor.code] = quote;
          });
        }
      } catch (e) {
        // Ignore errors
      }
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加监控'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '股票代码',
                hintText: '如 600000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '股票名称（可选）',
                hintText: '如 浦发银行',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = _codeController.text.trim();
              if (code.isEmpty) return;
              final name = _nameController.text.trim();
              final api = context.read<AppState>().api;
              await api.addMonitor(code, name);
              if (mounted) {
                context.read<AppState>().loadMonitors();
                // 获取新添加股票的报价
                try {
                  final quote = await api.getStockQuote(code);
                  setState(() {
                    _quotes[code] = quote;
                  });
                } catch (e) {}
                Navigator.pop(context);
                _codeController.clear();
                _nameController.clear();
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showConfigDialog() {
    final intervalController = TextEditingController(text: '30');
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 加载当前配置
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final interval =
                  await context.read<AppState>().api.getMonitorConfig();
              if (mounted && Navigator.canPop(context)) {
                setDialogState(() {
                  intervalController.text = interval.toString();
                });
              }
            } catch (e) {}
          });

          return AlertDialog(
            title: const Text('监控设置'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('监控刷新间隔（分钟）'),
                const SizedBox(height: 8),
                TextField(
                  controller: intervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '1-60之间的整数',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final interval = int.tryParse(intervalController.text);
                  if (interval == null || interval < 1 || interval > 60) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入1-60之间的整数')),
                    );
                    return;
                  }
                  await context
                      .read<AppState>()
                      .api
                      .setMonitorInterval(interval);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已设置为每 $interval 分钟刷新')),
                    );
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddToQuantDialog(MonitorItem monitor) {
    final selectedStrategies = <String>[
      'macd_cross',
      'ma_trend',
      'rsi_oversold'
    ];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final strategies = context.read<AppState>().strategies;

          return AlertDialog(
            title: Text('加入量化: ${monitor.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('股票: ${monitor.name} (${monitor.code})',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  Text('选择策略:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...strategies.map((s) => CheckboxListTile(
                        title: Text(s.name),
                        subtitle:
                            Text(s.description, style: TextStyle(fontSize: 12)),
                        value: selectedStrategies.contains(s.id),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              selectedStrategies.add(s.id);
                            } else {
                              selectedStrategies.remove(s.id);
                            }
                          });
                        },
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedStrategies.isEmpty) return;
                  final api = context.read<AppState>().api;
                  await api.addQuantTask(
                    monitor.code,
                    monitor.name,
                    selectedStrategies,
                  );
                  if (mounted) {
                    context.read<AppState>().loadQuantTasks();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${monitor.name} 已加入量化策略')),
                    );
                  }
                },
                child: const Text('添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 确保加载策略列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadStrategies();
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('股票监控'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfigDialog,
            tooltip: '设置',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AppState>().loadMonitors();
              _loadQuotes();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.monitors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monitor_heart_outlined,
                      size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  Text('暂无监控',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('点击 + 添加股票监控',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.monitors.length,
            itemBuilder: (context, index) {
              return _buildMonitorCard(state.monitors[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildMonitorCard(MonitorItem monitor) {
    final isRunning = monitor.status == 'running';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRunning ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${monitor.name} (${monitor.code})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (_quotes[monitor.code] != null) ...[
                  Text(
                    '${_quotes[monitor.code]!['currentPrice']}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getChangeColor(
                          (_quotes[monitor.code]!['changePercent'] ?? 0)
                              .toDouble()),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(_quotes[monitor.code]!['changePercent'] ?? 0) > 0 ? '+' : ''}${_quotes[monitor.code]!['changePercent']}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getChangeColor(
                          (_quotes[monitor.code]!['changePercent'] ?? 0)
                              .toDouble()),
                    ),
                  ),
                ],
                const Spacer(),
                // 启动/停止
                IconButton(
                  icon: Icon(
                    isRunning ? Icons.pause : Icons.play_arrow,
                    color:
                        isRunning ? AppTheme.holdColor : AppTheme.accentColor,
                  ),
                  onPressed: () async {
                    final api = context.read<AppState>().api;
                    if (isRunning) {
                      await api.stopMonitor(monitor.code);
                      await context.read<AppState>().loadMonitors();
                    } else {
                      await api.startMonitor(monitor.code);
                      await context.read<AppState>().loadMonitors();
                      try {
                        final quote = await api.getStockQuote(monitor.code);
                        if (mounted) {
                          setState(() {
                            _quotes[monitor.code] = quote;
                          });
                        }
                      } catch (e) {}
                    }
                  },
                  tooltip: isRunning ? '停止' : '启动',
                ),
                // 加入量化
                IconButton(
                  icon: Icon(Icons.auto_graph, color: AppTheme.accentColor),
                  onPressed: () => _showAddToQuantDialog(monitor),
                  tooltip: '加入量化',
                ),
                // 删除
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppTheme.sellColor),
                  onPressed: () async {
                    final api = context.read<AppState>().api;
                    await api.removeMonitor(monitor.code);
                    context.read<AppState>().loadMonitors();
                  },
                  tooltip: '删除',
                ),
              ],
            ),
          ),
          if (monitor.results.isNotEmpty)
            ExpansionTile(
              title: Text(
                '分析历史 (${monitor.results.length}条)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              initiallyExpanded: false,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedMonitors.add(monitor.code);
                  } else {
                    _expandedMonitors.remove(monitor.code);
                  }
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: monitor.results.reversed.map((result) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.timestamp,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              result.analysis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
