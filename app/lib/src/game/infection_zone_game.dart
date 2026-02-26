import 'dart:async';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../network/game_client.dart';

class InfectionZoneGame extends FlameGame {
  InfectionZoneGame({
    required this.client,
    required this.playerIdGetter,
  });

  final GameClient client;
  final String Function() playerIdGetter;

  final _stateById = <String, PlayerState>{};
  final _renderPosById = <String, Vector2>{};
  final _barricades = <BarricadeState>[];
  final _bullets = <BulletState>[];
  final _sprites = <String, ui.Image>{};
  ui.Picture? _mapPicture;

  StreamSubscription<GameStateSnapshot>? _sub;
  double _sendAccumulator = 0;
  Vector2 _moveInput = Vector2.zero();
  Vector2 _aimInput = Vector2.zero();
  Vector2 _facing = Vector2(1, 0);
  double _cameraX = 0;
  double _cameraY = 0;
  bool _cameraLocked = false;
  String? activeEvent;
  int roundEndsAt = 0;

  PlayerState? get me => _stateById[playerIdGetter()];

  @override
  Color backgroundColor() => const Color(0xFF0B1018);

  @override
  Future<void> onLoad() async {
    _buildStaticMapPicture();
    await _loadSprites();

    camera.viewfinder.anchor = Anchor.topLeft;
    _sub = client.stateStream.listen((snapshot) {
      final seenIds = <String>{};
      _stateById
        ..clear()
        ..addEntries(snapshot.players.map((p) {
          seenIds.add(p.id);
          _renderPosById.putIfAbsent(p.id, () => Vector2(p.x, p.y));
          return MapEntry(p.id, p);
        }));

      _renderPosById.removeWhere((id, _) => !seenIds.contains(id));
      _barricades
        ..clear()
        ..addAll(snapshot.barricades);
      _bullets
        ..clear()
        ..addAll(snapshot.bullets);
      activeEvent = snapshot.activeEvent;
      roundEndsAt = snapshot.roundEndsAt;
    });
  }

  Future<void> _loadSprites() async {
    Future<void> load(String key, String assetPath) async {
      try {
        _sprites[key] = await images.load(assetPath);
      } catch (_) {
        // Keep shape fallback if an asset is missing.
      }
    }

    await Future.wait([
      load('human', 'human.png'),
      load('p0', 'p0.png'),
      load('g2', 'hunter.png'),
      load('g3', 'crawler.png'),
      load('g4', 'shambler.png'),
      load('g5', 'horde.png'),
      load('bullet', 'bullet.png'),
      load('barricade', 'barricade.png'),
    ]);
  }

  void _buildStaticMapPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bg = Paint()..color = const Color(0xFF09101A);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 3000, 3000), bg);

    final gridPaint = Paint()..color = const Color(0xFF1D2A3A);
    const step = 120.0;
    for (double x = 0; x <= 3000; x += step) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, 3000), gridPaint);
    }
    for (double y = 0; y <= 3000; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, 3000, 1), gridPaint);
    }

    final safeRoom = Paint()..color = const Color(0x3326A65B);
    canvas.drawRect(const Rect.fromLTWH(80, 80, 300, 300), safeRoom);

    final generator = Paint()..color = const Color(0x55FFD166);
    canvas.drawCircle(const Offset(1500, 1500), 130, generator);

    _mapPicture = recorder.endRecording();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_aimInput.length2 > 0.01) {
      final target = _aimInput.normalized();
      final alpha = (dt * 18).clamp(0, 1).toDouble();
      _facing.x += (target.x - _facing.x) * alpha;
      _facing.y += (target.y - _facing.y) * alpha;
      if (_facing.length2 > 0.0001) {
        _facing = _facing.normalized();
      }
    } else if (_facing.length2 <= 0.0001 && _moveInput.length2 > 0.01) {
      _facing = _moveInput.normalized();
    }

    _sendAccumulator += dt;
    if (_sendAccumulator >= 0.05) {
      _sendAccumulator = 0;
      client.sendInput(
        x: _moveInput.x,
        y: _moveInput.y,
        facingX: _facing.x,
        facingY: _facing.y,
      );
    }

    final moveAlpha = (dt * 12).clamp(0, 1).toDouble();
    for (final entry in _stateById.entries) {
      final target = entry.value;
      final renderPos = _renderPosById.putIfAbsent(entry.key, () => Vector2(target.x, target.y));
      renderPos.x += (target.x - renderPos.x) * moveAlpha;
      renderPos.y += (target.y - renderPos.y) * moveAlpha;
    }

    final local = me;
    if (local != null && size.x > 0 && size.y > 0) {
      final localRender = _renderPosById[local.id] ?? Vector2(local.x, local.y);
      final targetX = (localRender.x - size.x / 2).clamp(0, 3000 - size.x).toDouble();
      final targetY = (localRender.y - size.y / 2).clamp(0, 3000 - size.y).toDouble();
      if (!_cameraLocked) {
        _cameraX = targetX;
        _cameraY = targetY;
        _cameraLocked = true;
      } else {
        final alpha = (dt * 10).clamp(0, 1).toDouble();
        _cameraX += (targetX - _cameraX) * alpha;
        _cameraY += (targetY - _cameraY) * alpha;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final camX = _cameraX.roundToDouble();
    final camY = _cameraY.roundToDouble();
    canvas.save();
    canvas.translate(-camX, -camY);
    _drawMap(canvas);
    _drawBarricades(canvas);
    _drawBullets(canvas);
    _drawPlayers(canvas);
    _drawAimReticle(canvas);
    canvas.restore();
  }

  void _drawMap(Canvas canvas) {
    final picture = _mapPicture;
    if (picture != null) {
      canvas.drawPicture(picture);
    }
  }

  void _drawPlayers(Canvas canvas) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final p in _stateById.values) {
      if (p.invisible && p.id != playerIdGetter()) continue;
      final pos = _renderPosById[p.id] ?? Vector2(p.x, p.y);

      Color color;
      if (p.team == 'human') {
        color = const Color(0xFF54B7FF);
      } else {
        switch (p.generation) {
          case 1:
            color = const Color(0xFFFF2D2D);
          case 2:
            color = const Color(0xFFFF8A00);
          case 3:
            color = const Color(0xFFFFD43B);
          case 4:
            color = const Color(0xFFA85BCB);
          default:
            color = const Color(0xFF5A5A5A);
        }
      }

      if (p.stunned) {
        color = Color.lerp(color, Colors.white, 0.6) ?? color;
      }

      final sprite = _spriteForPlayer(p);
      if (sprite != null) {
        final rect = Rect.fromCenter(center: Offset(pos.x, pos.y), width: 40, height: 40);
        canvas.drawImageRect(
          sprite,
          Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
          rect,
          Paint()..colorFilter = p.stunned ? const ColorFilter.mode(Colors.white70, BlendMode.modulate) : null,
        );
      } else {
        final playerPaint = Paint()..color = color;
        canvas.drawCircle(Offset(pos.x, pos.y), 18, playerPaint);
      }

      if (p.id == playerIdGetter()) {
        final ringPaint = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(Offset(pos.x, pos.y), 24, ringPaint);
      }

      textPainter.text = TextSpan(
        text: p.name,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pos.x - textPainter.width / 2, pos.y - 30));
    }
  }

  void _drawAimReticle(Canvas canvas) {
    final local = me;
    if (local == null) return;
    final pos = _renderPosById[local.id] ?? Vector2(local.x, local.y);
    final dir = _facing.length2 > 0.001 ? _facing.normalized() : Vector2(1, 0);
    final range = local.team == 'human' ? 150.0 : 120.0;
    final endX = pos.x + dir.x * range;
    final endY = pos.y + dir.y * range;
    final color = local.team == 'human' ? const Color(0xFF73C9FF) : const Color(0xFFFF8A80);

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(pos.x, pos.y), Offset(endX, endY), linePaint);

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(endX, endY), 12, ringPaint);
    canvas.drawLine(Offset(endX - 8, endY), Offset(endX + 8, endY), linePaint);
    canvas.drawLine(Offset(endX, endY - 8), Offset(endX, endY + 8), linePaint);
  }

  void setMoveInput(double x, double y) {
    _moveInput = Vector2(x.clamp(-1, 1), y.clamp(-1, 1));
  }

  void setAimInput(double x, double y) {
    _aimInput = Vector2(x.clamp(-1, 1), y.clamp(-1, 1));
  }

  void _drawBarricades(Canvas canvas) {
    final sprite = _sprites['barricade'];
    final paint = Paint()..color = const Color(0xFFB08A4A);
    for (final b in _barricades) {
      if (sprite != null) {
        canvas.drawImageRect(
          sprite,
          Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
          Rect.fromCenter(center: Offset(b.x, b.y), width: 84, height: 26),
          Paint(),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(b.x, b.y), width: 80, height: 14), const Radius.circular(3)),
          paint,
        );
      }
    }
  }

  void _drawBullets(Canvas canvas) {
    final sprite = _sprites['bullet'];
    final paint = Paint()..color = const Color(0xFFE4F9FF);
    for (final b in _bullets) {
      if (sprite != null) {
        canvas.drawImageRect(
          sprite,
          Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
          Rect.fromCenter(center: Offset(b.x, b.y), width: 18, height: 18),
          Paint(),
        );
      } else {
        canvas.drawCircle(Offset(b.x, b.y), 6, paint);
      }
    }
  }

  ui.Image? _spriteForPlayer(PlayerState p) {
    if (p.team == 'human') return _sprites['human'];
    switch (p.generation) {
      case 1:
        return _sprites['p0'];
      case 2:
        return _sprites['g2'];
      case 3:
        return _sprites['g3'];
      case 4:
        return _sprites['g4'];
      default:
        return _sprites['g5'];
    }
  }

  @override
  Future<void> onRemove() async {
    await _sub?.cancel();
    super.onRemove();
  }
}
