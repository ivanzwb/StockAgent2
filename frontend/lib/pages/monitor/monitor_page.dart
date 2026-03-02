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
              await api.addMonitor(code, name.isEmpty ? code : name);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('股票监控'),
        actions: [
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
