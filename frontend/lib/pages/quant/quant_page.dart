import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class QuantPage extends StatefulWidget {
  const QuantPage({super.key});

  @override
  State<QuantPage> createState() => _QuantPageState();
}

class _QuantPageState extends State<QuantPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  List<String> _selectedStrategies = ['macd_cross', 'ma_trend', 'rsi_oversold'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.loadQuantTasks();
      state.loadStrategies();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
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
                    Text('选择策略:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...strategies.map((s) => CheckboxListTile(
                          title: Text(s.name),
                          subtitle: Text(s.description,
                              style: const TextStyle(fontSize: 11)),
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

  void _showBacktestDialog(String code, String name) {
    showDialog(
      context: context,
      builder: (context) => _BacktestDialog(code: code, name: name),
    );
  }

  void _showRiskControlDialog(QuantTask task) {
    showDialog(
      context: context,
      builder: (context) => _RiskControlDialog(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('量化策略'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '监控', icon: Icon(Icons.monitor)),
            Tab(text: '策略', icon: Icon(Icons.list)),
            Tab(text: '统计', icon: Icon(Icons.analytics)),
          ],
        ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMonitorTab(),
          _buildStrategyTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildMonitorTab() {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.quantTasks.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.quantTasks.length,
          itemBuilder: (context, index) {
            return _buildEnhancedTaskCard(state.quantTasks[index]);
          },
        );
      },
    );
  }

  Widget _buildStrategyTab() {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final strategies = state.strategies;
        if (strategies.isEmpty) {
          return const Center(child: Text('加载中...'));
        }

        final categories = _categorizeStrategies(strategies);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: categories.entries.map((entry) {
            return ExpansionTile(
              title: Text(entry.key,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              initiallyExpanded: true,
              children: entry.value.map((s) => _buildStrategyItem(s)).toList(),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.quantTasks.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.quantTasks.length,
          itemBuilder: (context, index) {
            final task = state.quantTasks[index];
            return _buildStatsCard(task);
          },
        );
      },
    );
  }

  Map<String, List<StrategyDef>> _categorizeStrategies(
      List<StrategyDef> strategies) {
    final map = <String, List<StrategyDef>>{
      '趋势指标': [],
      '超买超卖': [],
      '能量分析': [],
      '形态识别': [],
      '价值投资': [],
    };

    for (final s in strategies) {
      if (s.id.contains('macd') ||
          s.id.contains('ma_') ||
          s.id.contains('expma') ||
          s.id.contains('trix') ||
          s.id.contains('aroon') ||
          s.id.contains('sar')) {
        map['趋势指标']!.add(s);
      } else if (s.id.contains('rsi') ||
          s.id.contains('kdj') ||
          s.id.contains('wr') ||
          s.id.contains('cci') ||
          s.id.contains('boll')) {
        map['超买超卖']!.add(s);
      } else if (s.id.contains('volume') ||
          s.id.contains('obv') ||
          s.id.contains('vr')) {
        map['能量分析']!.add(s);
      } else if (s.id.contains('break') ||
          s.id.contains('double') ||
          s.id.contains('gap')) {
        map['形态识别']!.add(s);
      } else if (s.id.contains('value')) {
        map['价值投资']!.add(s);
      }
    }

    map.removeWhere((key, value) => value.isEmpty);
    return map;
  }

  Widget _buildStrategyItem(StrategyDef s) {
    return ListTile(
      dense: true,
      title: Text(s.name),
      subtitle: Text(s.description, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }

  Widget _buildStatsCard(QuantTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(task.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Text('(${task.code})',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatChip(
                    '策略数', '${task.strategies.length}', AppTheme.accentColor),
                const SizedBox(width: 8),
                _buildStatChip('状态', task.status == 'running' ? '运行中' : '已停止',
                    task.status == 'running' ? Colors.green : Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showBacktestDialog(task.code, task.name),
                    icon: const Icon(Icons.show_chart, size: 18),
                    label: const Text('回测'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRiskControlDialog(task),
                    icon: const Icon(Icons.security, size: 18),
                    label: const Text('风控'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text('暂无量化任务',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text('点击 + 添加量化监控', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEnhancedTaskCard(QuantTask task) {
    final isRunning = task.status == 'running';
    final latestSignal = task.signals.isNotEmpty ? task.signals.last : null;
    final composite = latestSignal?.composite ?? {};
    final finalSignal =
        composite['finalSignal'] ?? composite['signal'] ?? 'hold';
    final riskCheck = latestSignal?.riskCheck;
    final signalConfirm = latestSignal?.signalConfirm;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${task.name} (${task.code})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (latestSignal?.price != null)
                            Text(
                              '¥${latestSignal!.price!.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    _buildSignalBadge(finalSignal),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  composite['finalReason'] ?? composite['reason'] ?? '等待信号...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (riskCheck?.triggered == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          riskCheck?.reason ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _buildStrategyChips(task.strategies),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSignalStrengthIndicator(
                          composite['strength'] ?? 0),
                    ),
                    IconButton(
                      icon: Icon(isRunning ? Icons.pause : Icons.play_arrow,
                          color: isRunning
                              ? AppTheme.holdColor
                              : AppTheme.accentColor),
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
                      icon:
                          Icon(Icons.delete_outline, color: AppTheme.sellColor),
                      onPressed: () async {
                        final api = context.read<AppState>().api;
                        await api.removeQuantTask(task.code);
                        context.read<AppState>().loadQuantTasks();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (latestSignal != null && latestSignal.signals.isNotEmpty)
            Container(
              color: Colors.grey.withOpacity(0.1),
              padding: const EdgeInsets.all(12),
              child: _buildSignalsList(latestSignal.signals),
            ),
        ],
      ),
    );
  }

  Widget _buildSignalBadge(String signal) {
    Color color;
    String text;
    switch (signal) {
      case 'buy':
        color = AppTheme.buyColor;
        text = '买入';
        break;
      case 'sell':
        color = AppTheme.sellColor;
        text = '卖出';
        break;
      default:
        color = AppTheme.holdColor;
        text = '观望';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStrategyChips(List<String> strategies) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: strategies
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(s,
                    style:
                        TextStyle(fontSize: 10, color: AppTheme.accentColor)),
              ))
          .toList(),
    );
  }

  Widget _buildSignalStrengthIndicator(double strength) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('信号强度',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const Spacer(),
            Text('${(strength * 100).toInt()}%',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: strength,
          backgroundColor: Colors.grey.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(
            strength > 0.7
                ? AppTheme.buyColor
                : strength > 0.3
                    ? AppTheme.holdColor
                    : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalsList(List<StrategySignal> signals) {
    final buySignals = signals.where((s) => s.signal == 'buy').toList();
    final sellSignals = signals.where((s) => s.signal == 'sell').toList();
    final holdSignals = signals.where((s) => s.signal == 'hold').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (buySignals.isNotEmpty) ...[
          _buildSignalSection('买入信号', buySignals, AppTheme.buyColor),
          const SizedBox(height: 8),
        ],
        if (sellSignals.isNotEmpty) ...[
          _buildSignalSection('卖出信号', sellSignals, AppTheme.sellColor),
          const SizedBox(height: 8),
        ],
        if (holdSignals.isNotEmpty)
          _buildSignalSection('观望信号', holdSignals, AppTheme.holdColor),
      ],
    );
  }

  Widget _buildSignalSection(
      String title, List<StrategySignal> signals, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        ...signals.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(_signalIcon(s.signal), size: 12, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${s.strategyName}: ${s.reason}',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  String _signalText(String signal) {
    switch (signal) {
      case 'buy':
        return '买入';
      case 'sell':
        return '卖出';
      default:
        return '观望';
    }
  }

  IconData _signalIcon(String signal) {
    switch (signal) {
      case 'buy':
        return Icons.arrow_upward;
      case 'sell':
        return Icons.arrow_downward;
      default:
        return Icons.remove;
    }
  }
}

class _BacktestDialog extends StatefulWidget {
  final String code;
  final String name;

  const _BacktestDialog({required this.code, required this.name});

  @override
  State<_BacktestDialog> createState() => _BacktestDialogState();
}

class _BacktestDialogState extends State<_BacktestDialog> {
  bool _loading = true;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _runBacktest();
  }

  Future<void> _runBacktest() async {
    try {
      final api = context.read<AppState>().api;
      final result = await api.backtest(
          widget.code, ['macd_cross', 'ma_trend', 'rsi_oversold'],
          days: 60);
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('回测分析 - ${widget.name}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _result != null && _result!['success'] == true
                ? _buildResult()
                : Center(child: Text(_result?['message'] ?? '回测失败')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final summary = _result!['summary'] ?? {};
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow('交易次数', '${summary['totalTrades']}'),
          _buildStatRow('盈利次数', '${summary['winTrades']}'),
          _buildStatRow('亏损次数', '${summary['loseTrades']}'),
          _buildStatRow('胜率', '${summary['winRate']}%',
              color: (summary['winRate'] ?? 0) > 50
                  ? AppTheme.buyColor
                  : AppTheme.sellColor),
          _buildStatRow('总收益率', '${summary['totalProfit']}%',
              color: (summary['totalProfit'] ?? 0) > 0
                  ? AppTheme.buyColor
                  : AppTheme.sellColor),
          _buildStatRow('平均收益', '${summary['avgProfit']}%'),
          _buildStatRow('最大盈利', '${summary['maxProfit']}%'),
          _buildStatRow('最大亏损', '${summary['maxLoss']}%'),
          _buildStatRow('最大回撤', '${summary['maxDrawdown']}%',
              color: Colors.orange),
          _buildStatRow('夏普比率', '${summary['sharpeRatio']}'),
          _buildStatRow('基准收益', '${summary['benchmarkReturn']}%'),
          _buildStatRow('超额收益', '${summary['excessReturn']}%',
              color: (summary['excessReturn'] ?? 0) > 0
                  ? AppTheme.buyColor
                  : AppTheme.sellColor),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _RiskControlDialog extends StatefulWidget {
  final QuantTask task;

  const _RiskControlDialog({required this.task});

  @override
  State<_RiskControlDialog> createState() => _RiskControlDialogState();
}

class _RiskControlDialogState extends State<_RiskControlDialog> {
  late double _stopLoss;
  late double _takeProfit;
  late int _confirmCount;

  @override
  void initState() {
    super.initState();
    final rc = widget.task.riskControl;
    _stopLoss = rc?.stopLossPercent ?? -5;
    _takeProfit = rc?.takeProfitPercent ?? 10;
    _confirmCount = rc?.signalConfirmCount ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('风控设置 - ${widget.task.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSlider('止损比例', _stopLoss, -15, 0,
              (v) => setState(() => _stopLoss = v), '%'),
          _buildSlider('止盈比例', _takeProfit, 1, 30,
              (v) => setState(() => _takeProfit = v), '%'),
          _buildSlider('信号确认次数', _confirmCount.toDouble(), 1, 5,
              (v) => setState(() => _confirmCount = v.toInt()), '次'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveRiskControl,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      Function(double) onChanged, String suffix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${value.toStringAsFixed(0)}$suffix'),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _saveRiskControl() async {
    try {
      final api = context.read<AppState>().api;
      await api.updateRiskControl(widget.task.code, {
        'stopLossPercent': _stopLoss,
        'takeProfitPercent': _takeProfit,
        'signalConfirmCount': _confirmCount,
      });
      if (mounted) {
        context.read<AppState>().loadQuantTasks();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
}
