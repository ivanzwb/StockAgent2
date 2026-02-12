/// 股票代码查询服务
import 'eastmoney_data_source.dart';
import 'sina_data_source.dart';

class StockCodeService {
  final _eastmoney = EastMoneyDataSource();
  final _sina = SinaDataSource();
  final Map<String, String> _cache = {};

  /// 股票名称/代码 → 纯6位代码
  Future<String?> nameToCode(String name) async {
    if (_cache.containsKey(name)) return _cache[name];

    final clean = name.trim();

    // 已经是6位数字代码
    if (RegExp(r'^\d{6}$').hasMatch(clean)) return clean;

    // 带市场前缀
    for (final prefix in ['SH', 'SZ', 'sh', 'sz']) {
      if (clean.startsWith(prefix)) {
        final code = clean.substring(prefix.length);
        if (RegExp(r'^\d{6}$').hasMatch(code)) return code;
      }
    }

    // 使用东方财富搜索
    final results = await _eastmoney.searchStock(name);
    if (results.isNotEmpty) {
      final code = results[0]['code'] as String;
      _cache[name] = code;
      return code;
    }
    return null;
  }

  /// 搜索股票
  Future<List<Map<String, dynamic>>> search(String keyword) async {
    final results = await _eastmoney.searchStock(keyword);
    for (final r in results) {
      _cache[r['name'] ?? ''] = r['code'] ?? '';
    }
    return results;
  }

  /// 根据代码获取名称
  Future<String> getStockName(String code) async {
    final quote = await _sina.getRealtimeQuote(code);
    if (quote != null) {
      _cache[quote.name] = code;
      return quote.name;
    }
    return code;
  }
}
