import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../utils/constants.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _isConnected = false;
  String? _authHeader;

  bool get isConnected => _isConnected;

  void setAuthHeader(String authHeader) {
    _authHeader = authHeader;
    if (_socket != null) {
      _socket!.disconnect();
      initSocket();
    }
  }

  void initSocket() {
    if (_authHeader == null) return;

    _socket = io.io(AppConfig.socketUrl,
      io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': _authHeader!.replaceAll('Bearer ', '')})
        .enableAutoConnect()
        .build()
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('Socket connected');
      // Join a room specific to this driver if your server expects it
      if (_authHeader != null) {
         // Some servers use 'join' event to subscribe to updates
         _socket!.emit('join', {'role': 'driver'});
      }
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('Socket disconnected');
      notifyListeners();
    });

    _socket!.onConnectError((data) => debugPrint('Socket Connect Error: $data'));
    _socket!.onError((data) => debugPrint('Socket Error: $data'));
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}
