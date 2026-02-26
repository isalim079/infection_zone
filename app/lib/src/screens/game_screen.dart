import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/infection_zone_game.dart';
import '../models/game_models.dart';
import '../network/game_client.dart';
import 'how_to_play_sheet.dart';
import 'lobby_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.client});

  final GameClient client;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static bool _tutorialShownThisSession = false;

  late InfectionZoneGame _game;
  StreamSubscription<GameStateSnapshot>? _stateSub;
  StreamSubscription<Map<String, dynamic>>? _roundEndSub;
  GameStateSnapshot? _state;
  DateTime _lastHudPaint = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _clockTicker;
  bool _handlingRoundEnd = false;
  bool _navigatingAway = false;

  @override
  void initState() {
    super.initState();
    _game = InfectionZoneGame(client: widget.client, playerIdGetter: () => widget.client.socketId ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _tutorialShownThisSession) return;
      _tutorialShownThisSession = true;
      await showHowToPlaySheet(context);
    });
    _stateSub = widget.client.stateStream.listen((s) {
      _state = s;
      if (s.phase != 'in_round' && mounted && !_handlingRoundEnd && !_navigatingAway) {
        _navigatingAway = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LobbyScreen(client: widget.client, nickname: 'Player'),
            ),
          );
        });
        return;
      }
      final now = DateTime.now();
      if (now.difference(_lastHudPaint).inMilliseconds >= 120 && mounted) {
        _lastHudPaint = now;
        setState(() {});
      }
    });

    _clockTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });

    _roundEndSub = widget.client.roundEndStream.listen((summary) async {
      if (!mounted || _handlingRoundEnd || _navigatingAway) return;
      _handlingRoundEnd = true;
      try {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text('Round End: ${summary['winner']}'),
            content: Text('Reason: ${summary['reason']}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              )
            ],
          ),
        );
        if (mounted) {
          _navigatingAway = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LobbyScreen(client: widget.client, nickname: 'Player'),
            ),
          );
        }
      } finally {
        _handlingRoundEnd = false;
      }
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _stateSub?.cancel();
    _roundEndSub?.cancel();
    super.dispose();
  }

  void _use(String ability) => widget.client.useAbility(ability);

  @override
  Widget build(BuildContext context) {
    final me = _state?.byId(widget.client.socketId ?? '');
    final isHuman = me?.team == 'human';
    final humans = _state?.players.where((p) => p.team == 'human').length ?? 0;
    final infected = _state?.players.where((p) => p.team == 'infected').length ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final msLeft = (_state?.roundEndsAt ?? now) - now;

    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  _hudChip('Humans $humans | Infected $infected'),
                  const SizedBox(width: 8),
                  _hudChip('Timer ${(msLeft / 1000).clamp(0, 180).toStringAsFixed(0)}'),
                  const SizedBox(width: 8),
                  _hudChip('${me?.team ?? '-'} G${me?.generation ?? 0}'),
                ],
              ),
            ),
          ),
          if ((_state?.activeEvent ?? '').isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 54),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xDDE54F38), Color(0xDDA12516)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _state!.activeEvent!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
            ),
          Positioned(
            top: 56,
            right: 10,
            child: _miniMap(me),
          ),
          Positioned(
            top: 12,
            right: 10,
            child: IconButton.filledTonal(
              onPressed: () => showHowToPlaySheet(context),
              icon: const Icon(Icons.help_outline),
            ),
          ),
          Positioned(
            left: 24,
            top: 52,
            child: _hudChip(
              isHuman
                  ? 'Left stick move | Right stick aim | FIRE shoots'
                  : 'Track humans on minimap, use abilities on right',
              compact: true,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _hudChip('Pistol Equipped | Ammo ${me?.stunAmmo ?? 0} | Flare ${me?.flareCharges ?? 0}'),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 20,
            child: _JoystickPad(
              onChanged: (x, y) => _game.setMoveInput(x, y),
              accent: const Color(0xCC2F9BFF),
              icon: Icons.directions_run,
            ),
          ),
          Positioned(
            right: 184,
            bottom: 20,
            child: _JoystickPad(
              onChanged: (x, y) => _game.setAimInput(x, y),
              accent: const Color(0xCCDD9323),
              icon: Icons.gps_fixed,
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 168,
                    child: ElevatedButton.icon(
                      onPressed: isHuman && (me?.stunAmmo ?? 0) > 0 ? () => _use('stun_pistol') : null,
                      icon: const Icon(Icons.gps_fixed, size: 18),
                      label: Text(
                        isHuman ? 'FIRE (${me?.stunAmmo ?? 0})' : 'FIRE (HUMAN ONLY)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBB2323),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 168,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xAA0E1521),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x55FFFFFF)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      direction: Axis.vertical,
                      children: _abilityButtons(me),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMap(PlayerState? me) {
    final players = _state?.players ?? const <PlayerState>[];
    return Container(
      width: 148,
      height: 148,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xAA09111C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66FFFFFF)),
      ),
      child: CustomPaint(
        painter: _MiniMapPainter(players: players, localId: me?.id),
      ),
    );
  }

  Widget _hudChip(String text, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: const Color(0x99070D15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x44FFFFFF)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12 : 15,
        ),
      ),
    );
  }

  List<Widget> _abilityButtons(PlayerState? me) {
    if (me == null) return [];
    final buttons = <Widget>[];
    if (me.team == 'human') {
      buttons.addAll([
        _ability('FLARE', () => _use('flare_gun'), enabled: me.flareCharges > 0),
        _ability('DASH', () => _use('adrenaline_dash')),
        _ability('BUILD', () => _use('barricade')),
        _ability('GENERATOR', () => _use('activate_generator')),
      ]);
    } else {
      if (me.generation == 1) {
        buttons.addAll([
          _ability('SCREAM', () => _use('scream_pulse')),
          _ability('INVIS', () => _use('invisibility')),
        ]);
      } else if (me.generation == 2) {
        buttons.add(_ability('POUNCE', () => _use('pounce')));
      } else {
        buttons.add(_ability('NO ACTIVE', () {}, enabled: false));
      }
    }
    return buttons;
  }

  Widget _ability(String label, VoidCallback onTap, {bool enabled = true}) {
    return SizedBox(
      width: 150,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF182739),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0x55FFFFFF)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _JoystickPad extends StatefulWidget {
  const _JoystickPad({
    required this.onChanged,
    required this.accent,
    required this.icon,
  });

  final void Function(double x, double y) onChanged;
  final Color accent;
  final IconData icon;

  @override
  State<_JoystickPad> createState() => _JoystickPadState();
}

class _JoystickPadState extends State<_JoystickPad> {
  static const double _radius = 46;
  static const double _knobRadius = 18;
  Offset _offset = Offset.zero;

  void _update(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    Offset delta = localPos - center;
    final dist = delta.distance;
    if (dist > _radius) {
      delta = Offset(delta.dx / dist * _radius, delta.dy / dist * _radius);
    }
    setState(() => _offset = delta);
    widget.onChanged(delta.dx / _radius, delta.dy / _radius);
  }

  void _reset() {
    setState(() => _offset = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    const size = 108.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _update(d.localPosition, const Size(size, size)),
      onPanUpdate: (d) => _update(d.localPosition, const Size(size, size)),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x550E1521),
          border: Border.all(color: const Color(0x66FFFFFF), width: 2),
        ),
        child: Stack(
          children: [
            Positioned(
              left: size / 2 - _knobRadius + _offset.dx,
              top: size / 2 - _knobRadius + _offset.dy,
              child: Container(
                width: _knobRadius * 2,
                height: _knobRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent,
                  border: Border.all(color: const Color(0xCCFFFFFF)),
                ),
                child: Icon(widget.icon, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({required this.players, required this.localId});

  final List<PlayerState> players;
  final String? localId;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF07101A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      bg,
    );

    for (final p in players) {
      final x = (p.x / 3000 * size.width).clamp(4, size.width - 4).toDouble();
      final y = (p.y / 3000 * size.height).clamp(4, size.height - 4).toDouble();
      final paint = Paint()
        ..color = p.id == localId
            ? const Color(0xFFFFFFFF)
            : p.team == 'human'
                ? const Color(0xFF56C5FF)
                : const Color(0xFFE54A4A);
      canvas.drawCircle(Offset(x, y), p.id == localId ? 4.5 : 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => true;
}
