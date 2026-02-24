import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

/// 量化策略页面
class QuantPage extends StatefulWidget {
  const QuantPage({super.key});

  @override
  State<QuantPage> createState() => _QuantPageState();
}

class _QuantPageState extends State<QuantPage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  List<String> _selectedStrategies = ['macd_cross', 'ma_trend', 'rsi_oversold'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.loadQuantTasks();
      state.loadStrategies();
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final strategies = context.read<AppState>().strategies;

          return AlertDialog(
            title: const Text('添加量化任务'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('选择策略:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...strategies.map((s) => CheckboxListTile(
                        title: Text(s.name),
                        subtitle: Text(s.description, style: TextStyle(fontSize: 12)),
                        value: _selectedStrategies.contains(s.id),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              _selectedStrategies.add(s.id);
                            } else {
                              _selectedStrategies.remove(s.id);
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
                  final code = _codeController.text.trim();
                  if (code.isEmpty) return;
                  final name = _nameController.text.trim();
                  final api = context.read<AppState>().api;
                  await api.addQuantTask(
                    code,
                    name.isEmpty ? code : name,
                    _selectedStrategies,
                  );
                  if (mounted) {
                    context.read<AppState>().loadQuantTasks();
                    Navigator.pop(context);
                    _codeController.clear();
                    _nameController.clear();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('量化策略'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AppState>().loadQuantTasks(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.add),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.quantTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_graph, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  Text('暂无量化任务', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('点击 + 添加量化监控', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.quantTasks.length,
            itemBuilder: (context, index) {
              return _buildTaskCard(state.quantTasks[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(QuantTask task) {
    final isRunning = task.status == 'running';
    final latestSignal = task.signals.isNotEmpty ? task.signals.last : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
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
                  '${task.name} (${task.code})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    isRunning ? Icons.pause : Icons.play_arrow,
                    color: isRunning ? AppTheme.holdColor : AppTheme.accentColor,
                  ),
                  onPressed: () async {
                    final api = context.read<AppState>().api;
                    if (isRunning) {
                      await api.stopQuantTask(task.code);
                    } else {
                      await api.startQuantTask(task.code);
                    }
                    context.read<AppState>().loadQuantTasks();
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppTheme.sellColor),
                  onPressed: () async {
                    final api = context.read<AppState>().api;
                    await api.removeQuantTask(task.code);
                    context.read<AppState>().loadQuantTasks();
                  },
                ),
              ],
            ),

            // 策略标签
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: task.strategies.map((s) => Chip(
                    label: Text(s, style: TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
            ),

            // 最新信号
            if (latestSignal != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // 综合信号
              Row(
                children: [
                  Text('综合信号: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.getSignalColor(latestSignal.composite['signal'] ?? 'hold').withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _signalText(latestSignal.composite['signal'] ?? 'hold'),
                      style: TextStyle(
                        color: AppTheme.getSignalColor(latestSignal.composite['signal'] ?? 'hold'),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (latestSignal.price != null) ...[
                    const Spacer(),
                    Text(
                      '¥${latestSignal.price!.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 4),
              Text(
                latestSignal.composite['reason'] ?? '',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),

              // 各策略信号
              const SizedBox(height: 8),
              ...latestSignal.signals.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          _signalIcon(s.signal),
                          size: 14,
                          color: AppTheme.getSignalColor(s.signal),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${s.strategyName}: ${s.reason}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _signalText(String signal) {
    switch (signal) {
      case 'buy': return '买入';
      case 'sell': return '卖出';
      default: return '观望';
    }
  }

  IconData _signalIcon(String signal) {
    switch (signal) {
      case 'buy': return Icons.arrow_upward;
      case 'sell': return Icons.arrow_downward;
      default: return Icons.remove;
    }
  }
}
