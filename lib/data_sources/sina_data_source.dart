/// 新浪财经数据源
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schemas.dart';

class SinaDataSource {
  static const _headers = {
    'Referer': 'https://finance.sina.com.cn',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  /// 格式化股票代码为新浪格式 (sh600000 / sz000001)
  static String formatCode(String code) {
    code = code.trim().toUpperCase();
    if (code.startsWith('SH') || code.startsWith('SZ')) {
      return code.toLowerCase();
    }
    code = code
        .replaceAll('.SH', '')
        .replaceAll('.SZ', '')
        .replaceAll('.ss', '')
        .replaceAll('.sz', '');
    if (code.startsWith('6') || code.startsWith('9')) return 'sh$code';
    if (code.startsWith('0') || code.startsWith('2') || code.startsWith('3')) {
      return 'sz$code';
    }
    if (code.startsWith('4') || code.startsWith('8')) return 'bj$code';
    return 'sh$code';
  }

  /// 获取实时行情
  Future<StockQuote?> getRealtimeQuote(String code) async {
    final sinaCode = formatCode(code);
    final url = 'https://hq.sinajs.cn/list=$sinaCode';

    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return null;

      // 新浪返回GBK编码，但http包默认按latin1处理
      // 对于Web端，直接用bodyBytes解码
      final text = _decodeResponse(response);
      return _parseRealtime(sinaCode, text);
    } catch (e) {
      print('获取实时行情失败 $code: $e');
      return null;
    }
  }

  /// 批量获取实时行情
  Future<List<StockQuote>> getBatchQuotes(List<String> codes) async {
    final sinaCodes = codes.map((c) => formatCode(c)).toList();
    final codesStr = sinaCodes.join(',');
    final url = 'https://hq.sinajs.cn/list=$codesStr';

    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return [];

      final text = _decodeResponse(response);
      final results = <StockQuote>[];

      for (final line in text.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final match = RegExp(r'var hq_str_(\w+)="(.+)"').firstMatch(trimmed);
        if (match != null) {
          final codeKey = match.group(1)!;
          final quote = _parseRealtime(codeKey, trimmed);
          if (quote != null) results.add(quote);
        }
      }
      return results;
    } catch (e) {
      print('批量获取行情失败: $e');
      return [];
    }
  }

  String _decodeResponse(http.Response response) {
    // 尝试GBK解码，降级到latin1
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return latin1.decode(response.bodyBytes);
    }
  }

  StockQuote? _parseRealtime(String sinaCode, String text) {
    try {
      final match = RegExp(r'"(.+)"').firstMatch(text);
      if (match == null) return null;

      final data = match.group(1)!.split(',');
      if (data.length < 32) return null;

      final pureCode = sinaCode.substring(2);
      final closePrice = double.tryParse(data[2]) ?? 0;
      final currentPrice = double.tryParse(data[3]) ?? 0;

      double changePct = 0;
      if (closePrice > 0) {
        changePct =
            double.parse(((currentPrice - closePrice) / closePrice * 100)
                .toStringAsFixed(2));
      }

      return StockQuote(
        code: pureCode,
        name: data[0],
        currentPrice: currentPrice,
        openPrice: double.tryParse(data[1]) ?? 0,
        closePrice: closePrice,
        highPrice: double.tryParse(data[4]) ?? 0,
        lowPrice: double.tryParse(data[5]) ?? 0,
        volume: (double.tryParse(data[8]) ?? 0) / 100, // 转换为手
        amount: double.tryParse(data[9]) ?? 0,
        changePercent: changePct,
        timestamp: '${data[30]} ${data[31]}',
      );
    } catch (e) {
      print('解析行情数据失败 $sinaCode: $e');
      return null;
    }
  }
}
