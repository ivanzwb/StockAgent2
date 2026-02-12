/// 板块分析工具 - LangChain Tool
import 'dart:convert';
import 'package:langchain_core/tools.dart';
import '../data_sources/eastmoney_data_source.dart';

/// 获取板块列表工具
final getSectorListTool = Tool.fromFunction<String, String>(
  name: 'get_sector_list',
  description: '获取A股市场板块列表（行业板块或概念板块）。返回板块名称、代码和涨跌幅。'
      '用于查看市场各板块表现，找到热门板块。',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {
      'sector_type': {
        'type': 'string',
        'description': '板块类型: industry(行业板块) 或 concept(概念板块)',
        'default': 'industry',
      },
    },
    'required': [],
  },
  func: _getSectorList,
  getInputFromJson: (json) => (json['sector_type'] as String?) ?? 'industry',
);

Future<String> _getSectorList(String sectorType) async {
  final eastmoney = EastMoneyDataSource();
  List<Map<String, dynamic>> sectors;
  if (sectorType == 'concept') {
    sectors = await eastmoney.getConceptSectors();
  } else {
    sectors = await eastmoney.getAllSectors();
  }

  if (sectors.isEmpty) return '获取板块列表失败';

  // 只返回前50个
  final limited = sectors.take(50).toList();
  return const JsonEncoder.withIndent('  ').convert(limited);
}

/// 获取板块内股票列表工具
final getSectorStocksTool =
    Tool.fromFunction<Map<String, dynamic>, String>(
  name: 'get_sector_stocks',
  description: '获取某个板块内的股票列表。输入板块代码（如BK0477），返回该板块下'
      '所有股票的代码、名称、当前价格和涨跌幅。用于筛选板块内优质股票。',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {
      'sector_code': {
        'type': 'string',
        'description': '板块代码，如 BK0477',
      },
      'limit': {
        'type': 'integer',
        'description': '返回股票数量上限',
        'default': 20,
      },
    },
    'required': ['sector_code'],
  },
  func: _getSectorStocks,
  getInputFromJson: (json) => json,
);

Future<String> _getSectorStocks(Map<String, dynamic> input) async {
  final sectorCode = input['sector_code'] as String;
  final limit = (input['limit'] as int?) ?? 20;

  final eastmoney = EastMoneyDataSource();
  final stocks = await eastmoney.getSectorStocks(sectorCode, limit: limit);

  if (stocks.isEmpty) return '获取板块股票失败: $sectorCode';

  return const JsonEncoder.withIndent('  ').convert(stocks);
}
