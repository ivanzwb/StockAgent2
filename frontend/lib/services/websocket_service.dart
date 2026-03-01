import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket 服务 - 接收实时事件推送
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  String _wsUrl;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  static const int maxRetryCount = 3;
  bool _shouldReconnect = true;

  WebSocketService({String wsUrl = 'ws://localhost:3000/ws'}) : _wsUrl = wsUrl;

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isConnected => _isConnected;
  bool get canRetry => _retryCount < maxRetryCount;
  int get retryCount => _retryCount;
  bool get shouldReconnect => _shouldReconnect;

  void updateUrl(String url) {
    _wsUrl = url;
  }

  /// 连接 WebSocket - 手动点击连接时调用
  void connect({bool manual = false}) {
    if (manual) {
      _retryCount = 0;
      _shouldReconnect = true;
    }
    _doConnect();
  }

  /// 内部连接方法
  void _doConnect() {
    if (!_shouldReconnect) {
      print('WebSocket 已停止重连，请手动点击连接');
      return;
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final event = jsonDecode(data as String) as Map<String, dynamic>;
            _eventController.add(event);
          } catch (e) {
            print('WebSocket 消息解析错误: $e');
          }
        },
        onError: (error) {
          print('WebSocket 错误: $error');
          _isConnected = false;
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket 已断开');
          _isConnected = false;
          _handleDisconnect();
        },
      );
    } catch (e) {
      print('WebSocket 连接失败: $e');
      _isConnected = false;
      _handleDisconnect();
    }
  }

  /// 处理断开连接
  void _handleDisconnect() {
    _retryCount++;
    if (_retryCount >= maxRetryCount) {
      _shouldReconnect = false;
      print('WebSocket 重连次数已达上限($maxRetryCount)，停止自动重连');
      _eventController.add({
        'type': 'system',
        'event': 'reconnect_failed',
        'data': {'retryCount': _retryCount, 'maxRetry': maxRetryCount}
      });
    } else {
      _scheduleReconnect();
    }
  }

  /// 断开连接
  void disconnect() {
    _reconnectTimer?.cancel();
    _shouldReconnect = false;
    _channel?.sink.close();
    _isConnected = false;
  }

  /// 重置重连状态 - 用户修改配置后调用
  void resetReconnectState() {
    _retryCount = 0;
    _shouldReconnect = true;
  }

  /// 发送消息
  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  /// 按事件类型过滤
  Stream<Map<String, dynamic>> on(String type) {
    return events.where((e) => e['type'] == type);
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      print('WebSocket 重连中... (${_retryCount}/$maxRetryCount)');
      _doConnect();
    });
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
