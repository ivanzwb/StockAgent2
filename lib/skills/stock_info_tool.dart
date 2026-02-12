/// 股票行情工具 - LangChain Tool
import 'dart:convert';
import 'package:langchain_core/tools.dart';
import '../data_sources/sina_data_source.dart';
import '../data_sources/eastmoney_data_source.dart';
import '../data_sources/stock_code_service.dart';

/// 获取股票实时行情
final getStockQuoteTool = Tool.fromFunction<String, String>(
  name: 'get_stock_quote',
  description: '获取股票实时行情数据。输入股票代码(如600000)或股票名称(如浦发银行)，'
      '返回当前价格、涨跌幅、成交量等实时信息。',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {
      'stock': {
        'type': 'string',
        'description': '股票代码或名称，如 600000 或 浦发银行',
      },
    },
    'required': ['stock'],
  },
  func: _getStockQuote,
  getInputFromJson: (json) => json['stock'] as String,
);

Future<String> _getStockQuote(String stockInput) async {
  final codeService = StockCodeService();
  final code = await codeService.nameToCode(stockInput);
  if (code == null) return '未找到股票: $stockInput';

  final sina = SinaDataSource();
  final quote = await sina.getRealtimeQuote(code);
  if (quote == null) return '获取行情失败: $code';

  return const JsonEncoder.withIndent('  ').convert(quote.toJson());
}

/// 获取K线数据
final getStockKlineTool = Tool.fromFunction<Map<String, dynamic>, String>(
  name: 'get_stock_kline',
  description: '获取股票K线历史数据。返回开盘价、收盘价、最高价、最低价、成交量等。'
      '用于趋势分析和技术分析。',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {
      'stock_code': {
        'type': 'string',
        'description': '股票代码，如 600000',
      },
      'period': {
        'type': 'string',
        'description': 'K线周期: day/week/month/5min/15min/30min/60min',
        'default': 'day',
      },
      'count': {
        'type': 'integer',
        'description': '获取数据条数',
        'default': 60,
      },
    },
    'required': ['stock_code'],
  },
  func: _getStockKline,
  getInputFromJson: (json) => json,
);

Future<String> _getStockKline(Map<String, dynamic> input) async {
  final code = input['stock_code'] as String;
  final period = (input['period'] as String?) ?? 'day';
  final count = (input['count'] as int?) ?? 60;

  final eastmoney = EastMoneyDataSource();
  final klines = await eastmoney.getKline(code, period: period, count: count);
  if (klines.isEmpty) return '获取K线数据失败: $code';

  final data = klines.map((k) => k.toJson()).toList();
  // 只返回最后count条
  final subset = data.length > count ? data.sublist(data.length - count) : data;
  return const JsonEncoder.withIndent('  ').convert(subset);
}
