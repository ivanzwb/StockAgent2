/// 东方财富数据源
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schemas.dart';

class EastMoneyDataSource {
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Referer': 'https://quote.eastmoney.com',
  };

  /// 获取东方财富secid格式 (1.600000 / 0.000001)
  static String getSecid(String code) {
    code = code
        .trim()
        .replaceAll(RegExp(r'[SsHhZz.]'), '')
        .replaceAll('SH', '')
        .replaceAll('SZ', '');
    // 清理后只保留数字
    code = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.isEmpty) return '1.$code';

    if (code.startsWith('6') || code.startsWith('9')) return '1.$code';
    if (code.startsWith('0') || code.startsWith('2') || code.startsWith('3')) {
      return '0.$code';
    }
    if (code.startsWith('4') || code.startsWith('8')) return '0.$code';
    return '1.$code';
  }

  /// 获取K线数据
  Future<List<KlineData>> getKline(
    String code, {
    String period = 'day',
    int count = 120,
    String adjust = 'qfq',
  }) async {
    final secid = getSecid(code);
    final kltMap = {
      'day': '101',
      'week': '102',
      'month': '103',
      '5min': '5',
      '15min': '15',
      '30min': '30',
      '60min': '60',
    };
    final fqtMap = {'qfq': '1', 'hfq': '2', 'none': '0'};

    final params = {
      'secid': secid,
      'fields1': 'f1,f2,f3,f4,f5,f6',
      'fields2': 'f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61',
      'klt': kltMap[period] ?? '101',
      'fqt': fqtMap[adjust] ?? '1',
      'beg': '0',
      'end': '20500101',
      'lmt': count.toString(),
      'ut': 'fa5fd1943c7b386f172d6893dbfba10b',
    };

    try {
      final uri = Uri.parse(
              'https://push2his.eastmoney.com/api/qt/stock/kline/get')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data['rc'] != 0) return [];

      final klines = (data['data']?['klines'] as List?) ?? [];
      return klines.map<KlineData>((kline) {
        final parts = (kline as String).split(',');
        return KlineData(
          date: parts[0],
          open: double.tryParse(parts[1]) ?? 0,
          close: double.tryParse(parts[2]) ?? 0,
          high: double.tryParse(parts[3]) ?? 0,
          low: double.tryParse(parts[4]) ?? 0,
          volume: double.tryParse(parts[5]) ?? 0,
          amount: parts.length > 6 ? (double.tryParse(parts[6]) ?? 0) : 0,
          changePercent:
              parts.length > 8 ? (double.tryParse(parts[8]) ?? 0) : 0,
        );
      }).toList();
    } catch (e) {
      print('东方财富获取K线失败 $code: $e');
      return [];
    }
  }

  /// 获取基本面数据
  Future<FundamentalData?> getFundamental(String code) async {
    final secid = getSecid(code);
    final params = {
      'secid': secid,
      'fields':
          'f57,f58,f162,f167,f116,f117,f173,f183,f186,f187,f188,f190',
      'ut': 'fa5fd1943c7b386f172d6893dbfba10b',
    };

    try {
      final uri =
          Uri.parse('https://push2.eastmoney.com/api/qt/stock/get')
              .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['rc'] != 0) return null;

      final d = data['data'] ?? {};
      return FundamentalData(
        code: d['f57']?.toString() ?? code,
        name: d['f58']?.toString() ?? '',
        peRatio: _safeDiv(d['f162'], 100),
        pbRatio: _safeDiv(d['f167'], 100),
        totalMarketCap: _safeDiv(d['f116'], 100000000),
        circulatingMarketCap: _safeDiv(d['f117'], 100000000),
        roe: _safeDiv(d['f173'], 100),
        eps: _safeDiv(d['f183'], 100),
        bvps: _safeDiv(d['f186'], 100),
        revenue: _safeDiv(d['f187'], 100000000),
        netProfit: _safeDiv(d['f188'], 100000000),
        debtRatio: _safeDiv(d['f190'], 100),
      );
    } catch (e) {
      print('东方财富获取基本面数据失败 $code: $e');
      return null;
    }
  }

  double? _safeDiv(dynamic val, num divisor) {
    if (val == null || val == '-') return null;
    try {
      return double.parse((val / divisor).toStringAsFixed(4));
    } catch (_) {
      return null;
    }
  }

  /// 获取所有行业板块
  Future<List<Map<String, dynamic>>> getAllSectors() async {
    return _getSectors('m:90+t:2');
  }

  /// 获取概念板块
  Future<List<Map<String, dynamic>>> getConceptSectors() async {
    return _getSectors('m:90+t:3');
  }

  Future<List<Map<String, dynamic>>> _getSectors(String fs) async {
    final params = {
      'pn': '1',
      'pz': '500',
      'po': '1',
      'np': '1',
      'fltt': '2',
      'invt': '2',
      'fid': 'f3',
      'fs': fs,
      'fields': 'f1,f2,f3,f4,f12,f14',
      'ut': 'fa5fd1943c7b386f172d6893dbfba10b',
    };

    try {
      final uri =
          Uri.parse('https://push2.eastmoney.com/api/qt/bklist/get')
              .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data['rc'] != 0) return [];

      final diff = (data['data']?['diff'] as List?) ?? [];
      return diff
          .map<Map<String, dynamic>>((item) => {
                'code': item['f12'] ?? '',
                'name': item['f14'] ?? '',
                'change_percent': item['f3'] ?? 0,
              })
          .toList();
    } catch (e) {
      print('获取板块列表失败: $e');
      return [];
    }
  }

  /// 获取板块内股票列表
  Future<List<Map<String, dynamic>>> getSectorStocks(
    String sectorCode, {
    int limit = 50,
  }) async {
    final params = {
      'pn': '1',
      'pz': limit.toString(),
      'po': '1',
      'np': '1',
      'fltt': '2',
      'invt': '2',
      'fid': 'f3',
      'fs': 'b:$sectorCode+f:!50',
      'fields': 'f1,f2,f3,f4,f5,f6,f7,f12,f14,f15,f16,f17,f18',
      'ut': 'fa5fd1943c7b386f172d6893dbfba10b',
    };

    try {
      final uri =
          Uri.parse('https://push2.eastmoney.com/api/qt/clist/get')
              .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data['rc'] != 0) return [];

      final diff = (data['data']?['diff'] as List?) ?? [];
      return diff
          .map<Map<String, dynamic>>((item) => {
                'code': item['f12'] ?? '',
                'name': item['f14'] ?? '',
                'price': item['f2'] ?? 0,
                'change_percent': item['f3'] ?? 0,
                'volume': item['f5'] ?? 0,
                'amount': item['f6'] ?? 0,
              })
          .toList();
    } catch (e) {
      print('获取板块股票列表失败 $sectorCode: $e');
      return [];
    }
  }

  /// 搜索股票
  Future<List<Map<String, dynamic>>> searchStock(String keyword) async {
    final params = {
      'input': keyword,
      'type': '14',
      'token': 'D43BF722C8E33BDC906FB84D85E326E8',
      'count': '5',
    };

    try {
      final uri = Uri.parse(
              'https://searchapi.eastmoney.com/api/suggest/get')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final items =
          (data['QuotationCodeTable']?['Data'] as List?) ?? [];
      return items
          .map<Map<String, dynamic>>((item) => {
                'code': item['Code'] ?? '',
                'name': item['Name'] ?? '',
                'market': item['MktNum'] ?? '',
              })
          .toList();
    } catch (e) {
      print('搜索股票失败 $keyword: $e');
      return [];
    }
  }
}
