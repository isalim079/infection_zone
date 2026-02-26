import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/game_models.dart';

class GameClient {
  GameClient({required this.serverUrl});

  final String serverUrl;
  io.Socket? _socket;

  final _stateController = StreamController<GameStateSnapshot>.broadcast();
  final _roundEndController = StreamController<Map<String, dynamic>>.broadcast();
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<GameStateSnapshot> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get roundEndStream => _roundEndController.stream;
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  Stream<String> get errorStream => _errorController.stream;

  String? socketId;
  GameStateSnapshot? latestState;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final socket = io.io(
      serverUrl,
      io.OptionBuilder().setTransports(['websocket']).enableForceNew().build(),
    );

    final connected = Completer<void>();

    socket.onConnect((_) {
      socketId = socket.id;
      if (!connected.isCompleted) {
        connected.complete();
      }
    });

    socket.on('connected', (data) {
      final map = _asMap(data);
      if (map != null) {
        socketId = map['id']?.toString() ?? socketId;
      }
    });

    void onSnapshot(dynamic data) {
      final map = _asMap(data);
      if (map != null) {
        final parsed = GameStateSnapshot.fromJson(map);
        latestState = parsed;
        _stateController.add(parsed);
      }
    }

    socket.on('room_state', onSnapshot);
    socket.on('game_state', onSnapshot);

    socket.on('round_ended', (data) {
      final map = _asMap(data);
      if (map != null) {
        _roundEndController.add(map);
      }
    });

    socket.on('event_triggered', (data) {
      final map = _asMap(data);
      if (map != null) {
        _eventController.add(map);
      }
    });

    socket.on('error_message', (data) {
      final map = _asMap(data);
      if (map != null) {
        _errorController.add(map['message']?.toString() ?? 'Server error');
      }
    });

    socket.onDisconnect((_) {
      _errorController.add('Disconnected from server');
    });

    _socket = socket;
    await connected.future.timeout(const Duration(seconds: 6));
  }

  Future<GameStateSnapshot> waitForFirstState({Duration timeout = const Duration(seconds: 6)}) async {
    if (latestState != null) return latestState!;
    return stateStream.first.timeout(timeout);
  }

  void createRoom({required String name}) {
    _socket?.emit('create_room', {'name': name});
  }

  void joinRoom({required String code, required String name}) {
    _socket?.emit('join_room', {'code': code, 'name': name});
  }

  void setReady(bool ready) {
    _socket?.emit('set_ready', {'ready': ready});
  }

  void startGame() {
    _socket?.emit('start_game');
  }

  void sendInput({
    required double x,
    required double y,
    required double facingX,
    required double facingY,
  }) {
    _socket?.emit('input', {
      'x': x,
      'y': y,
      'facingX': facingX,
      'facingY': facingY,
    });
  }

  void useAbility(String ability, {Map<String, dynamic>? payload}) {
    _socket?.emit('use_ability', {'ability': ability, 'payload': payload ?? {}});
  }

  Future<void> dispose() async {
    _socket?.dispose();
    await _stateController.close();
    await _roundEndController.close();
    await _eventController.close();
    await _errorController.close();
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}
