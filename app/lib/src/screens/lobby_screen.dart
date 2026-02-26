import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../network/game_client.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({
    super.key,
    required this.client,
    required this.nickname,
  });

  final GameClient client;
  final String nickname;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  StreamSubscription<GameStateSnapshot>? _stateSub;
  StreamSubscription<String>? _errorSub;
  bool _openingGame = false;

  GameStateSnapshot? _state;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.client.stateStream.listen((s) {
      setState(() => _state = s);
      if (s.phase == 'in_round' && !_openingGame) {
        _openingGame = true;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GameScreen(client: widget.client)),
        );
      }
    });
    _errorSub = widget.client.errorStream.listen((e) => setState(() => _error = e));
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final players = state?.players ?? const <PlayerState>[];
    final myId = widget.client.socketId;
    final me = myId == null ? null : state?.byId(myId);
    final isHost = state?.hostId == myId;

    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room: ${state?.code ?? '...'}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Players (${players.length}/16)'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, i) {
                  final p = players[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(p.ready ? Icons.check_circle : Icons.circle_outlined),
                    title: Text(p.name),
                    subtitle: Text(
                      p.id == state?.hostId
                          ? 'Host'
                          : p.isBot
                              ? 'Bot'
                              : 'Guest',
                    ),
                    trailing: Text('Score ${p.score}'),
                  );
                },
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: me == null ? null : () => widget.client.setReady(!(me.ready)),
                    child: Text((me?.ready ?? false) ? 'Unready' : 'Ready'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isHost ? widget.client.startGame : null,
                    child: const Text('Start Game'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
