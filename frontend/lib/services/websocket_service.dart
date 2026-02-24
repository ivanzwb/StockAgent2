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

  WebSocketService({String wsUrl = 'ws://localhost:3000/ws'}) : _wsUrl = wsUrl;

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isConnected => _isConnected;

  void updateUrl(String url) {
    _wsUrl = url;
  }

  /// 连接 WebSocket
  void connect() {
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
          _scheduleReconnect();
        },
        onDone: () {
          print('WebSocket 已断开');
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      print('WebSocket 连接失败: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// 断开连接
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
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
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      print('WebSocket 重连中...');
      connect();
    });
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
