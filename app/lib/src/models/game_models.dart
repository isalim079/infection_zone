class PlayerState {
  PlayerState({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.team,
    required this.generation,
    required this.ready,
    required this.stunned,
    required this.blinded,
    required this.invisible,
    required this.score,
    required this.stunAmmo,
    required this.flareCharges,
    required this.justInfectedUntil,
    required this.isBot,
  });

  final String id;
  final String name;
  final double x;
  final double y;
  final String team;
  final int generation;
  final bool ready;
  final bool stunned;
  final bool blinded;
  final bool invisible;
  final int score;
  final int stunAmmo;
  final int flareCharges;
  final int justInfectedUntil;
  final bool isBot;

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Player',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      team: json['team'] as String? ?? 'human',
      generation: (json['generation'] as num?)?.toInt() ?? 0,
      ready: json['ready'] as bool? ?? false,
      stunned: json['stunned'] as bool? ?? false,
      blinded: json['blinded'] as bool? ?? false,
      invisible: json['invisible'] as bool? ?? false,
      score: (json['score'] as num?)?.toInt() ?? 0,
      stunAmmo: (json['stunAmmo'] as num?)?.toInt() ?? 0,
      flareCharges: (json['flareCharges'] as num?)?.toInt() ?? 0,
      justInfectedUntil: (json['justInfectedUntil'] as num?)?.toInt() ?? 0,
      isBot: json['isBot'] as bool? ?? false,
    );
  }
}

class BarricadeState {
  BarricadeState({
    required this.id,
    required this.x,
    required this.y,
    required this.hp,
  });

  final String id;
  final double x;
  final double y;
  final int hp;

  factory BarricadeState.fromJson(Map<String, dynamic> json) {
    return BarricadeState(
      id: json['id']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      hp: (json['hp'] as num?)?.toInt() ?? 0,
    );
  }
}

class BulletState {
  BulletState({
    required this.id,
    required this.x,
    required this.y,
  });

  final String id;
  final double x;
  final double y;

  factory BulletState.fromJson(Map<String, dynamic> json) {
    return BulletState(
      id: json['id']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }
}

class GameStateSnapshot {
  GameStateSnapshot({
    required this.code,
    required this.phase,
    required this.hostId,
    required this.roundEndsAt,
    required this.activeEvent,
    required this.activeEventEndsAt,
    required this.p0Id,
    required this.players,
    required this.bullets,
    required this.barricades,
  });

  final String code;
  final String phase;
  final String? hostId;
  final int roundEndsAt;
  final String? activeEvent;
  final int activeEventEndsAt;
  final String? p0Id;
  final List<PlayerState> players;
  final List<BulletState> bullets;
  final List<BarricadeState> barricades;

  factory GameStateSnapshot.fromJson(Map<String, dynamic> json) {
    final players = _mapList(json['players']).map(PlayerState.fromJson).toList();
    final bullets = _mapList(json['bullets']).map(BulletState.fromJson).toList();
    final barricades = _mapList(json['barricades']).map(BarricadeState.fromJson).toList();

    return GameStateSnapshot(
      code: json['code'] as String? ?? '',
      phase: json['phase'] as String? ?? 'lobby',
      hostId: json['hostId']?.toString(),
      roundEndsAt: (json['roundEndsAt'] as num?)?.toInt() ?? 0,
      activeEvent: json['activeEvent'] as String?,
      activeEventEndsAt: (json['activeEventEndsAt'] as num?)?.toInt() ?? 0,
      p0Id: json['p0Id']?.toString(),
      players: players,
      bullets: bullets,
      barricades: barricades,
    );
  }

  PlayerState? byId(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final item in value) {
    if (item is Map<String, dynamic>) {
      out.add(item);
    } else if (item is Map) {
      out.add(item.map((k, v) => MapEntry(k.toString(), v)));
    }
  }
  return out;
}
