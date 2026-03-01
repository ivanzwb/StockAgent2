import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

/// 板块页面 - 板块列表及推荐
class SectorPage extends StatefulWidget {
  const SectorPage({super.key});

  @override
  State<SectorPage> createState() => _SectorPageState();
}

class _SectorPageState extends State<SectorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadSectors();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSectors();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSectors() async {
    setState(() => _isLoading = true);
    final type = _tabController.index == 0 ? 'industry' : 'concept';
    await context.read<AppState>().loadSectors(type: type);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('板块推荐'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '行业板块'),
            Tab(text: '概念板块'),
          ],
          indicatorColor: AppTheme.primaryColor,
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.sectors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_view,
                      size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  Text('暂无板块数据',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadSectors,
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadSectors,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.sectors.length,
              itemBuilder: (context, index) {
                return _buildSectorCard(state.sectors[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectorCard(SectorInfo sector) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          sector.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: sector.leaderStock.isNotEmpty
            ? Text('领涨: ${sector.leaderStock}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                AppTheme.getChangeColor(sector.changePercent).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${sector.changePercent > 0 ? '+' : ''}${sector.changePercent.toStringAsFixed(2)}%',
            style: TextStyle(
              color: AppTheme.getChangeColor(sector.changePercent),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _analyzeSector(sector),
      ),
    );
  }

  Future<void> _analyzeSector(SectorInfo sector) async {
    String currentStatus = '正在获取板块股票...';
    int currentStep = 0;
    int totalSteps = 5;
    String currentStock = '';
    Map<String, dynamic>? finalResult;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text('分析 ${sector.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: totalSteps > 0 ? currentStep / totalSteps : 0,
                  backgroundColor: Colors.grey[800],
                ),
                const SizedBox(height: 16),
                Text(currentStatus),
                if (currentStock.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    currentStock,
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    try {
      await for (final event in context
          .read<AppState>()
          .api
          .analyzeSectorWithProgress(sector.code, topN: 5)) {
        if (!mounted) return;

        final type = event['type'];
        if (type == 'progress') {
          currentStep = event['current'] as int;
          totalSteps = event['total'] as int;
          currentStock = event['stock'] as String? ?? '';
          currentStatus = '正在分析第 $currentStep / $totalSteps 只股票...';

          // 重新显示更新后的对话框
          if (mounted) {
            Navigator.of(context).pop();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => StatefulBuilder(
                builder: (ctx, setState) => AlertDialog(
                  title: Text('分析 ${sector.name}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: totalSteps > 0 ? currentStep / totalSteps : 0,
                        backgroundColor: Colors.grey[800],
                      ),
                      const SizedBox(height: 16),
                      Text(currentStatus),
                      if (currentStock.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          currentStock,
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }
        } else if (type == 'done') {
          finalResult = event['result'] as Map<String, dynamic>?;
          break;
        } else if (type == 'error') {
          throw Exception(event['message']);
        }
      }

      if (mounted && finalResult != null) {
        Navigator.of(context).pop();
        _showSectorResult(sector.name, finalResult!);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析失败: $e')),
        );
      }
    }
  }

  void _showSectorResult(String sectorName, Map<String, dynamic> result) {
    final stocks = result['stocks'] as List? ?? [];

    if (stocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有找到推荐的股票')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '$sectorName - 推荐股票',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _addToMonitor(stocks),
                    icon: const Icon(Icons.add_moderator, size: 18),
                    label: const Text('一键监控'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: stocks.length,
                itemBuilder: (context, index) {
                  final stock = stocks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${stock['name']} (${stock['code']})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(stock['changePercent'] ?? 0) > 0 ? '+' : ''}${(stock['changePercent'] ?? 0).toStringAsFixed(2)}%',
                                style: TextStyle(
                                  color: AppTheme.getChangeColor(
                                      (stock['changePercent'] ?? 0).toDouble()),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (stock['analysis'] != null &&
                              stock['analysis']['analysis'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              stock['analysis']['analysis'],
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToMonitor(List<dynamic> stocks) async {
    final appState = context.read<AppState>();
    int addedCount = 0;
    int buyCount = 0;

    for (final stock in stocks) {
      final analysis = stock['analysis'];
      if (analysis == null || analysis['analysis'] == null) continue;

      final analysisText = analysis['analysis'] as String;
      final isBuy = analysisText.contains('操作建议') &&
          (analysisText.contains('买入') || analysisText.contains('看涨'));

      if (isBuy) {
        buyCount++;
        try {
          await appState.api.addMonitor(stock['code'], stock['name']);
          addedCount++;
        } catch (e) {
          // 忽略添加失败的股票
        }
      }
    }

    if (mounted) {
      await appState.loadMonitors();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加 $addedCount 只买入推荐股票到监控列表（共 $buyCount 只推荐买入）'),
        ),
      );
    }
  }
}
