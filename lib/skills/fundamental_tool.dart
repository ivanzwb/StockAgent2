/// 基本面分析工具 - LangChain Tool
import 'dart:convert';
import 'package:langchain_core/tools.dart';
import '../data_sources/eastmoney_data_source.dart';

/// 获取基本面数据工具
final getFundamentalDataTool = Tool.fromFunction<String, String>(
  name: 'get_fundamental_data',
  description: '获取股票基本面数据。包括市盈率(PE)、市净率(PB)、总市值、流通市值、'
      '营收、净利润、ROE、每股收益、每股净资产、资产负债率等。'
      '用于评估股票的内在价值和财务健康状况。',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {
      'stock_code': {
        'type': 'string',
        'description': '股票代码，如 600000',
      },
    },
    'required': ['stock_code'],
  },
  func: _getFundamentalData,
  getInputFromJson: (json) => json['stock_code'] as String,
);

Future<String> _getFundamentalData(String stockCode) async {
  final eastmoney = EastMoneyDataSource();
  final data = await eastmoney.getFundamental(stockCode);

  if (data == null) return '获取基本面数据失败: $stockCode';

  return const JsonEncoder.withIndent('  ').convert(data.toJson());
}
