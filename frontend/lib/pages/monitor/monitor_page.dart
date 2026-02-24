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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadMonitors();
    });
  }

  @override
  void dispose() {
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
            onPressed: () => context.read<AppState>().loadMonitors(),
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
                  Icon(Icons.monitor_heart_outlined, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  Text('暂无监控', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('点击 + 添加股票监控', style: TextStyle(color: AppTheme.textSecondary)),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                const Spacer(),
                // 启动/停止
                IconButton(
                  icon: Icon(
                    isRunning ? Icons.pause : Icons.play_arrow,
                    color: isRunning ? AppTheme.holdColor : AppTheme.accentColor,
                  ),
                  onPressed: () async {
                    final api = context.read<AppState>().api;
                    if (isRunning) {
                      await api.stopMonitor(monitor.code);
                    } else {
                      await api.startMonitor(monitor.code);
                    }
                    context.read<AppState>().loadMonitors();
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

            if (monitor.results.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                '最新分析 (${monitor.results.last.timestamp})',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                monitor.results.last.analysis.length > 200
                    ? '${monitor.results.last.analysis.substring(0, 200)}...'
                    : monitor.results.last.analysis,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
