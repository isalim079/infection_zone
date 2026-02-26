import 'package:flutter/material.dart';

import '../network/game_client.dart';
import 'how_to_play_sheet.dart';
import 'lobby_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _nicknameController = TextEditingController(text: 'Survivor');
  final _roomCodeController = TextEditingController();
  final _serverController = TextEditingController(text: 'http://10.0.2.2:5001');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nicknameController.dispose();
    _roomCodeController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _connectAndOpen({required String mode}) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final client = GameClient(serverUrl: _serverController.text.trim());

    try {
      await client.connect();
      if (mode == 'create' || mode == 'quick') {
        client.createRoom(name: _nicknameController.text.trim());
      } else {
        client.joinRoom(
          code: _roomCodeController.text.trim().toUpperCase(),
          name: _nicknameController.text.trim(),
        );
      }
      await client.waitForFirstState();
      if (mode == 'quick') {
        client.setReady(true);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            client: client,
            nickname: _nicknameController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      await client.dispose();
      setState(() => _error = 'Connection failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF080C13), Color(0xFF111A29), Color(0xFF1F1A12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Card(
                color: const Color(0xCC0D131D),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'INFECTION ZONE',
                        style: TextStyle(
                          color: Color(0xFFE23A3A),
                          fontSize: 36,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nicknameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nickname',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _serverController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Server URL',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _roomCodeController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Room Code',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _busy ? null : () => _connectAndOpen(mode: 'create'),
                              child: const Text('Create Room'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _busy ? null : () => _connectAndOpen(mode: 'quick'),
                              child: const Text('Quick Play'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : () => _connectAndOpen(mode: 'join'),
                              child: const Text('Join Room'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _busy ? null : () => showHowToPlaySheet(context),
                        icon: const Icon(Icons.help_outline),
                        label: const Text('How To Play'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
