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
    final loadingDialog = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('分析 ${sector.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在分析板块内TOP5股票...',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );

    try {
      final result = await context
          .read<AppState>()
          .api
          .analyzeSector(sector.code, topN: 5);
      if (mounted) {
        Navigator.of(context).pop();
        _showSectorResult(sector.name, result);
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                '$sectorName - 推荐股票',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: stocks.length,
                  itemBuilder: (context, index) {
                    final stock = stocks[index];
                    return Card(
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
                                        (stock['changePercent'] ?? 0)
                                            .toDouble()),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (stock['analysis'] != null &&
                                stock['analysis']['analysis'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                (stock['analysis']['analysis'] as String)
                                            .length >
                                        300
                                    ? '${(stock['analysis']['analysis'] as String).substring(0, 300)}...'
                                    : stock['analysis']['analysis'],
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
      ),
    );
  }
}
