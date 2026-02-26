import {
  EVENT_INTERVAL_MS,
  EVENTS,
  HUMAN_ABILITY_CONFIG,
  INFECTED_ABILITY_CONFIG,
  INFECTION_RANGE,
  MAP_HEIGHT,
  MAP_WIDTH,
  PLAYER_RADIUS,
  ROUND_DURATION_MS,
  SCORE,
  SPEEDS,
  TICK_MS
} from './constants.js';
import { clamp, distance, normalize, nowMs } from './utils.js';

function randomSpawn() {
  return {
    x: 200 + Math.random() * (MAP_WIDTH - 400),
    y: 200 + Math.random() * (MAP_HEIGHT - 400)
  };
}

function makeCooldowns() {
  return {
    stunPistolAt: 0,
    flareGunAt: 0,
    adrenalineDashAt: 0,
    barricadeAt: 0,
    invisibilityAt: 0,
    screamPulseAt: 0,
    pounceAt: 0
  };
}

function generationForInfectedCount(infectedCount) {
  if (infectedCount <= 1) return 1;
  if (infectedCount <= 3) return 2;
  if (infectedCount <= 6) return 3;
  if (infectedCount <= 10) return 4;
  return 5;
}

const BOT_PREFIX = 'bot:';

export class GameRoom {
  constructor(code, hostId) {
    this.code = code;
    this.hostId = hostId;
    this.players = new Map();
    this.phase = 'lobby';
    this.roundStartedAt = 0;
    this.roundEndsAt = 0;
    this.nextEventAt = 0;
    this.activeEvent = null;
    this.activeEventEndsAt = 0;
    this.lastTickAt = nowMs();
    this.bullets = [];
    this.barricades = [];
    this.generatorDisabledUntil = 0;
  }

  addPlayer(socketId, name, isBot = false) {
    const spawn = randomSpawn();
    this.players.set(socketId, {
      id: socketId,
      name: String(name || 'Player').slice(0, 20),
      ready: false,
      connected: true,
      isBot,
      x: spawn.x,
      y: spawn.y,
      vx: 0,
      vy: 0,
      input: { x: 0, y: 0, facingX: 1, facingY: 0 },
      team: 'human',
      generation: 0,
      justInfectedUntil: 0,
      invisibleUntil: 0,
      stunnedUntil: 0,
      blindedUntil: 0,
      flareCharges: HUMAN_ABILITY_CONFIG.flareGun.charges,
      stunAmmo: HUMAN_ABILITY_CONFIG.stunPistol.ammo,
      barricadeIds: [],
      score: 0,
      stats: {
        infections: 0,
        revives: 0,
        survivedMs: 0
      },
      survived1mAwarded: false,
      survived2mAwarded: false,
      cooldowns: makeCooldowns()
    });
  }

  removePlayer(socketId) {
    this.players.delete(socketId);
    if (this.hostId === socketId) {
      const nonBot = [...this.players.values()].find((p) => !p.isBot);
      this.hostId = nonBot?.id || null;
    }
  }

  setReady(socketId, ready) {
    const p = this.players.get(socketId);
    if (!p) return;
    if (p.isBot) return;
    p.ready = !!ready;
  }

  canStart() {
    if (this.phase !== 'lobby') return false;
    const players = [...this.players.values()];
    const humans = players.filter((p) => !p.isBot);
    if (humans.length < 1) return false;
    const readyCount = humans.filter((p) => p.ready).length;
    return readyCount >= 1;
  }

  addBotPlayersUntil(minTotalPlayers = 4) {
    let i = 1;
    while (this.players.size < minTotalPlayers) {
      const id = `${BOT_PREFIX}${this.code}:${i}`;
      if (!this.players.has(id)) {
        this.addPlayer(id, `Bot${i}`, true);
      }
      i += 1;
    }
  }

  startRound() {
    if (!this.canStart()) return false;
    this.addBotPlayersUntil(4);
    this.phase = 'in_round';
    this.roundStartedAt = nowMs();
    this.roundEndsAt = this.roundStartedAt + ROUND_DURATION_MS;
    this.nextEventAt = this.roundStartedAt + EVENT_INTERVAL_MS;
    this.activeEvent = null;
    this.activeEventEndsAt = 0;
    this.bullets = [];
    this.barricades = [];

    const ids = [...this.players.keys()];
    const patientZeroId = ids[Math.floor(Math.random() * ids.length)];

    for (const p of this.players.values()) {
      const spawn = randomSpawn();
      p.x = spawn.x;
      p.y = spawn.y;
      p.vx = 0;
      p.vy = 0;
      p.input = { x: 0, y: 0, facingX: 1, facingY: 0 };
      p.team = p.id === patientZeroId ? 'infected' : 'human';
      p.generation = p.id === patientZeroId ? 1 : 0;
      p.justInfectedUntil = 0;
      p.invisibleUntil = 0;
      p.stunnedUntil = 0;
      p.blindedUntil = 0;
      p.flareCharges = HUMAN_ABILITY_CONFIG.flareGun.charges;
      p.stunAmmo = HUMAN_ABILITY_CONFIG.stunPistol.ammo;
      p.barricadeIds = [];
      p.score = 0;
      p.stats = { infections: 0, revives: 0, survivedMs: 0 };
      p.survived1mAwarded = false;
      p.survived2mAwarded = false;
      p.cooldowns = makeCooldowns();
    }
    return true;
  }

  updateBots(now) {
    const players = [...this.players.values()];
    for (const bot of players) {
      if (!bot.isBot || bot.stunnedUntil > now) continue;
      if (bot.team === 'human') {
        const infected = players.filter((p) => p.team === 'infected');
        if (!infected.length) continue;
        const nearest = infected.reduce((best, cur) => {
          if (!best) return cur;
          return distance(bot, cur) < distance(bot, best) ? cur : best;
        }, null);
        const away = normalize({ x: bot.x - nearest.x, y: bot.y - nearest.y });
        bot.input = { x: away.x, y: away.y, facingX: away.x, facingY: away.y };
        if (distance(bot, nearest) < 300 && bot.stunAmmo > 0 && Math.random() < 0.06) {
          this.useAbility(bot.id, 'stun_pistol');
        }
      } else {
        const humans = players.filter((p) => p.team === 'human');
        if (!humans.length) continue;
        const nearest = humans.reduce((best, cur) => {
          if (!best) return cur;
          return distance(bot, cur) < distance(bot, best) ? cur : best;
        }, null);
        const chase = normalize({ x: nearest.x - bot.x, y: nearest.y - bot.y });
        bot.input = { x: chase.x, y: chase.y, facingX: chase.x, facingY: chase.y };
        if (bot.generation === 2 && Math.random() < 0.03) {
          this.useAbility(bot.id, 'pounce');
        }
      }
    }
  }

  submitInput(socketId, input) {
    const p = this.players.get(socketId);
    if (!p || this.phase !== 'in_round') return;
    p.input = {
      x: clamp(Number(input?.x) || 0, -1, 1),
      y: clamp(Number(input?.y) || 0, -1, 1),
      facingX: Number(input?.facingX) || p.input.facingX,
      facingY: Number(input?.facingY) || p.input.facingY
    };
  }

  useAbility(socketId, ability, payload = {}) {
    const p = this.players.get(socketId);
    const now = nowMs();
    if (!p || this.phase !== 'in_round' || p.stunnedUntil > now) return;

    if (p.team === 'human') {
      if (ability === 'stun_pistol') {
        if (p.stunAmmo <= 0) return;
        if (now < p.cooldowns.stunPistolAt) return;
        p.cooldowns.stunPistolAt = now + HUMAN_ABILITY_CONFIG.stunPistol.cooldownMs;
        p.stunAmmo -= 1;
        const dir = normalize({ x: p.input.facingX, y: p.input.facingY });
        this.bullets.push({
          id: `${socketId}-${now}-${Math.random()}`,
          ownerId: socketId,
          x: p.x,
          y: p.y,
          vx: dir.x * HUMAN_ABILITY_CONFIG.stunPistol.speed,
          vy: dir.y * HUMAN_ABILITY_CONFIG.stunPistol.speed,
          diesAt: now + HUMAN_ABILITY_CONFIG.stunPistol.lifetimeMs
        });
      }

      if (ability === 'flare_gun') {
        if (p.flareCharges <= 0) return;
        p.flareCharges -= 1;
        p.cooldowns.flareGunAt = now + HUMAN_ABILITY_CONFIG.flareGun.cooldownMs;
        for (const target of this.players.values()) {
          if (target.team === 'infected') {
            target.blindedUntil = Math.max(target.blindedUntil, now + HUMAN_ABILITY_CONFIG.flareGun.blindMs);
          }
        }
      }

      if (ability === 'adrenaline_dash') {
        if (now < p.cooldowns.adrenalineDashAt) return;
        p.cooldowns.adrenalineDashAt = now + HUMAN_ABILITY_CONFIG.adrenalineDash.cooldownMs;
        const dir = normalize({ x: p.input.x, y: p.input.y });
        p.x = clamp(p.x + dir.x * HUMAN_ABILITY_CONFIG.adrenalineDash.distance, PLAYER_RADIUS, MAP_WIDTH - PLAYER_RADIUS);
        p.y = clamp(p.y + dir.y * HUMAN_ABILITY_CONFIG.adrenalineDash.distance, PLAYER_RADIUS, MAP_HEIGHT - PLAYER_RADIUS);
      }

      if (ability === 'barricade') {
        if (now < p.cooldowns.barricadeAt) return;
        p.cooldowns.barricadeAt = now + HUMAN_ABILITY_CONFIG.barricade.cooldownMs;
        if (p.barricadeIds.length >= HUMAN_ABILITY_CONFIG.barricade.maxActive) {
          const old = p.barricadeIds.shift();
          this.barricades = this.barricades.filter((b) => b.id !== old);
        }
        const dir = normalize({ x: p.input.facingX, y: p.input.facingY });
        const bx = p.x + dir.x * 45;
        const by = p.y + dir.y * 45;
        const barricade = {
          id: `${socketId}-b-${now}`,
          ownerId: socketId,
          x: bx,
          y: by,
          hp: HUMAN_ABILITY_CONFIG.barricade.hp,
          diesAt: now + HUMAN_ABILITY_CONFIG.barricade.lifeMs
        };
        this.barricades.push(barricade);
        p.barricadeIds.push(barricade.id);
      }

      if (ability === 'revive') {
        const target = this.players.get(payload.targetId);
        if (!target || target.team !== 'infected') return;
        if (target.generation === 1) return;
        if (target.justInfectedUntil < now) return;
        if (distance(p, target) > 80) return;
        target.team = 'human';
        target.generation = 0;
        target.justInfectedUntil = 0;
        p.stats.revives += 1;
        p.score += SCORE.revive;
      }

      if (ability === 'activate_generator') {
        if (distance(p, { x: 1500, y: 1500 }) <= 140) {
          this.generatorDisabledUntil = now + 30000;
          p.score += SCORE.generator;
        }
      }
    }

    if (p.team === 'infected') {
      if (ability === 'invisibility' && p.generation === 1) {
        if (now < p.cooldowns.invisibilityAt) return;
        p.cooldowns.invisibilityAt = now + INFECTED_ABILITY_CONFIG.invisibility.cooldownMs;
        p.invisibleUntil = now + INFECTED_ABILITY_CONFIG.invisibility.durationMs;
      }

      if (ability === 'scream_pulse' && p.generation === 1) {
        if (now < p.cooldowns.screamPulseAt) return;
        p.cooldowns.screamPulseAt = now + INFECTED_ABILITY_CONFIG.screamPulse.cooldownMs;
        for (const target of this.players.values()) {
          if (target.team !== 'human') continue;
          if (distance(p, target) <= INFECTED_ABILITY_CONFIG.screamPulse.stunRadius) {
            target.stunnedUntil = Math.max(target.stunnedUntil, now + INFECTED_ABILITY_CONFIG.screamPulse.stunMs);
          }
        }
      }

      if (ability === 'pounce' && p.generation === 2) {
        if (now < p.cooldowns.pounceAt) return;
        p.cooldowns.pounceAt = now + INFECTED_ABILITY_CONFIG.pounce.cooldownMs;
        const dir = normalize({ x: p.input.facingX, y: p.input.facingY });
        p.x = clamp(p.x + dir.x * INFECTED_ABILITY_CONFIG.pounce.distance, PLAYER_RADIUS, MAP_WIDTH - PLAYER_RADIUS);
        p.y = clamp(p.y + dir.y * INFECTED_ABILITY_CONFIG.pounce.distance, PLAYER_RADIUS, MAP_HEIGHT - PLAYER_RADIUS);
      }

      if (ability === 'destroy_barricade') {
        const barricade = this.barricades.find((b) => b.id === payload.id);
        if (!barricade) return;
        if (distance(p, barricade) > 100) return;
        barricade.hp -= 1;
        if (barricade.hp <= 0) {
          this.barricades = this.barricades.filter((b) => b.id !== barricade.id);
          const owner = this.players.get(barricade.ownerId);
          if (owner) {
            owner.barricadeIds = owner.barricadeIds.filter((id) => id !== barricade.id);
          }
        }
      }
    }
  }

  applyRandomEvent(now) {
    const event = EVENTS[Math.floor(Math.random() * EVENTS.length)];
    this.activeEvent = event.key;
    this.activeEventEndsAt = event.durationMs > 0 ? now + event.durationMs : now;

    if (event.key === 'SUPPLY_DROP') {
      const humans = [...this.players.values()].filter((p) => p.team === 'human');
      if (humans.length) {
        const winner = humans[Math.floor(Math.random() * humans.length)];
        winner.stunAmmo += 4;
        winner.flareCharges += 1;
      }
    }

    if (event.key === 'MUTATION') {
      const p0 = [...this.players.values()].find((p) => p.team === 'infected' && p.generation === 1);
      if (p0) {
        p0.cooldowns.invisibilityAt = 0;
        p0.cooldowns.screamPulseAt = 0;
      }
    }
  }

  tick(now = nowMs()) {
    if (this.phase !== 'in_round') return null;

    const deltaMs = Math.min(100, Math.max(0, now - this.lastTickAt));
    this.lastTickAt = now;
    const deltaSec = deltaMs / 1000;

    if (now >= this.nextEventAt) {
      this.applyRandomEvent(now);
      this.nextEventAt = now + EVENT_INTERVAL_MS;
    }

    if (this.activeEvent && now > this.activeEventEndsAt && this.activeEventEndsAt > 0) {
      this.activeEvent = null;
      this.activeEventEndsAt = 0;
    }

    this.updateBots(now);

    for (const p of this.players.values()) {
      if (p.team === 'human') {
        p.stats.survivedMs = now - this.roundStartedAt;
        if (!p.survived1mAwarded && p.stats.survivedMs >= 60_000) {
          p.survived1mAwarded = true;
          p.score += SCORE.survive1Min;
        }
        if (!p.survived2mAwarded && p.stats.survivedMs >= 120_000) {
          p.survived2mAwarded = true;
          p.score += SCORE.survive2Min;
        }
      }

      if (p.stunnedUntil > now) continue;
      const dir = normalize(p.input);
      let speed = p.team === 'human' ? SPEEDS.human : this.speedForGeneration(p.generation);

      if (this.activeEvent === 'FRENZY_MODE' && p.team === 'infected') speed *= 1.5;
      if (this.activeEvent === 'ADRENALINE_SURGE' && p.team === 'human') speed *= 1.5;

      p.vx = dir.x * speed;
      p.vy = dir.y * speed;
      p.x = clamp(p.x + p.vx * deltaSec, PLAYER_RADIUS, MAP_WIDTH - PLAYER_RADIUS);
      p.y = clamp(p.y + p.vy * deltaSec, PLAYER_RADIUS, MAP_HEIGHT - PLAYER_RADIUS);
    }

    this.barricades = this.barricades.filter((b) => b.hp > 0 && b.diesAt > now);

    this.updateBullets(now, deltaSec);
    this.resolveInfections(now);

    if (now >= this.roundEndsAt) {
      return this.finishRound('timer');
    }

    const humans = [...this.players.values()].filter((p) => p.team === 'human');
    if (humans.length === 0) {
      return this.finishRound('infected');
    }

    return null;
  }

  updateBullets(now, deltaSec) {
    const nextBullets = [];
    for (const bullet of this.bullets) {
      if (bullet.diesAt <= now) continue;
      bullet.x += bullet.vx * deltaSec;
      bullet.y += bullet.vy * deltaSec;
      let hit = false;
      for (const p of this.players.values()) {
        if (p.team !== 'infected') continue;
        if (distance(bullet, p) <= PLAYER_RADIUS + 6) {
          p.stunnedUntil = Math.max(p.stunnedUntil, now + HUMAN_ABILITY_CONFIG.stunPistol.stunMs);
          hit = true;
          break;
        }
      }
      if (!hit) {
        nextBullets.push(bullet);
      }
    }
    this.bullets = nextBullets;
  }

  resolveInfections(now) {
    const infected = [...this.players.values()].filter((p) => p.team === 'infected');
    const humans = [...this.players.values()].filter((p) => p.team === 'human');

    for (const inf of infected) {
      if (inf.stunnedUntil > now) continue;
      for (const human of humans) {
        if (human.team !== 'human') continue;
        if (distance(inf, human) > INFECTION_RANGE + PLAYER_RADIUS) continue;
        human.team = 'infected';
        const infectedCount = [...this.players.values()].filter((p) => p.team === 'infected').length;
        human.generation = generationForInfectedCount(infectedCount);
        human.justInfectedUntil = now + 3000;

        inf.stats.infections += 1;
        inf.score += SCORE.infectAny;
        if (inf.generation === 1) {
          inf.score += SCORE.infectAsP0;
        }
      }
    }
  }

  speedForGeneration(generation) {
    if (generation <= 1) return SPEEDS.infectedGen1;
    if (generation === 2) return SPEEDS.infectedGen2;
    if (generation === 3) return SPEEDS.infectedGen3;
    if (generation === 4) return SPEEDS.infectedGen4;
    return SPEEDS.infectedGen5;
  }

  finishRound(reason) {
    const humans = [...this.players.values()].filter((p) => p.team === 'human');
    if (humans.length === 1) {
      humans[0].score += SCORE.lastHuman;
      if (reason === 'timer') {
        humans[0].score += SCORE.surviveFullAsLastHumanBonus;
      }
    }

    if (reason === 'infected') {
      for (const p of this.players.values()) {
        if (p.team === 'infected') {
          p.score += SCORE.perfectInfectionBonus;
        }
      }
    }

    this.phase = 'lobby';
    for (const p of this.players.values()) {
      p.ready = false;
    }

    const standings = [...this.players.values()]
      .map((p) => ({
        id: p.id,
        name: p.name,
        score: p.score,
        infections: p.stats.infections,
        revives: p.stats.revives,
        survivedMs: p.stats.survivedMs
      }))
      .sort((a, b) => b.score - a.score);

    return {
      winner: reason === 'timer' ? 'humans' : 'infected',
      reason,
      standings
    };
  }

  stateFor(playerId) {
    const now = nowMs();
    const p0 = [...this.players.values()].find((p) => p.team === 'infected' && p.generation === 1);

    return {
      code: this.code,
      phase: this.phase,
      hostId: this.hostId,
      roundEndsAt: this.roundEndsAt,
      activeEvent: this.activeEvent,
      activeEventEndsAt: this.activeEventEndsAt,
      generatorDisabledUntil: this.generatorDisabledUntil,
      p0Id: p0?.id || null,
      players: [...this.players.values()].map((p) => ({
        id: p.id,
        name: p.name,
        isBot: p.isBot,
        ready: p.ready,
        x: Number(p.x.toFixed(2)),
        y: Number(p.y.toFixed(2)),
        team: p.team,
        generation: p.generation,
        stunned: p.stunnedUntil > now,
        blinded: p.blindedUntil > now,
        invisible: p.invisibleUntil > now,
        score: p.score,
        stunAmmo: p.stunAmmo,
        flareCharges: p.flareCharges,
        cooldowns: p.cooldowns,
        justInfectedUntil: p.justInfectedUntil
      })),
      bullets: this.bullets.map((b) => ({ id: b.id, x: b.x, y: b.y })),
      barricades: this.barricades.map((b) => ({ id: b.id, x: b.x, y: b.y, hp: b.hp }))
    };
  }
}

export class RoomManager {
  constructor() {
    this.rooms = new Map();
    this.playerToRoom = new Map();
  }

  createRoom(code, hostId, playerName) {
    const room = new GameRoom(code, hostId);
    room.addPlayer(hostId, playerName);
    this.rooms.set(code, room);
    this.playerToRoom.set(hostId, code);
    return room;
  }

  joinRoom(code, socketId, playerName) {
    const room = this.rooms.get(code);
    if (!room) return null;
    if (room.players.size >= 16) return null;
    room.addPlayer(socketId, playerName);
    this.playerToRoom.set(socketId, code);
    return room;
  }

  getRoomByPlayer(socketId) {
    const code = this.playerToRoom.get(socketId);
    if (!code) return null;
    return this.rooms.get(code) || null;
  }

  removePlayer(socketId) {
    const room = this.getRoomByPlayer(socketId);
    if (!room) return;
    const code = room.code;
    room.removePlayer(socketId);
    this.playerToRoom.delete(socketId);
    const humanPlayers = [...room.players.values()].filter((p) => !p.isBot);
    if (humanPlayers.length === 0) {
      for (const p of room.players.values()) {
        this.playerToRoom.delete(p.id);
      }
      this.rooms.delete(code);
    }
  }
}

export const LOOP_DELTA_MS = TICK_MS;
