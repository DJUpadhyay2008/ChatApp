import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../../shared/models/message.dart';

enum WsStatus { disconnected, connecting, connected }

class WsClient {
  final Future<String?> Function() getToken;
  final void Function(Message message) onMessageReceived;
  final void Function(WsStatus status)? onStatusChanged;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  WsStatus _status = WsStatus.disconnected;

  WsClient({
    required this.getToken,
    required this.onMessageReceived,
    this.onStatusChanged,
  });

  WsStatus get status => _status;

  void _setStatus(WsStatus newStatus) {
    _status = newStatus;
    onStatusChanged?.call(newStatus);
  }

  Future<void> connect() async {
    if (_isDisposed || _status == WsStatus.connected || _status == WsStatus.connecting) {
      return;
    }

    final token = await getToken();
    if (token == null || token.isEmpty) {
      _setStatus(WsStatus.disconnected);
      return;
    }

    _setStatus(WsStatus.connecting);

    try {
      final wsUri = Uri.parse('${Env.wsBaseUrl}?token=$token');
      _channel = WebSocketChannel.connect(wsUri);

      _subscription = _channel!.stream.listen(
        (data) {
          _handleIncomingData(data);
        },
        onDone: () {
          _onDisconnected();
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _onDisconnected();
        },
        cancelOnError: true,
      );

      _setStatus(WsStatus.connected);
      _startPingTimer();
    } catch (e) {
      debugPrint('WebSocket connection exception: $e');
      _onDisconnected();
    }
  }

  void _handleIncomingData(dynamic rawData) {
    try {
      final map = jsonDecode(rawData as String);
      final type = map['type'];
      if (type == 'new_message' && map['data'] != null) {
        final message = Message.fromJson(map['data']);
        onMessageReceived(message);
      }
    } catch (e) {
      debugPrint('Failed to parse WS event: $e');
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_status == WsStatus.connected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {
          _onDisconnected();
        }
      }
    });
  }

  void _onDisconnected() {
    _cleanup();
    _setStatus(WsStatus.disconnected);

    if (!_isDisposed) {
      // Reconnect with exponential / delayed backoff (5 seconds)
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        connect();
      });
    }
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _cleanup();
    _setStatus(WsStatus.disconnected);
  }
}
