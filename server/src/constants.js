export const TICK_RATE = 20;
export const TICK_MS = 1000 / TICK_RATE;
export const ROUND_DURATION_MS = 3 * 60 * 1000;
export const EVENT_INTERVAL_MS = 45 * 1000;
export const MAP_WIDTH = 3000;
export const MAP_HEIGHT = 3000;
export const PLAYER_RADIUS = 18;
export const INFECTION_RANGE = 26;

export const SPEEDS = {
  human: 200,
  infectedGen1: 400,
  infectedGen2: 300,
  infectedGen3: 200,
  infectedGen4: 140,
  infectedGen5: 120
};

export const ROLE_COLORS = {
  human: '#4fa8ff',
  infectedGen1: '#ff2d2d',
  infectedGen2: '#ff8c00',
  infectedGen3: '#ffd22d',
  infectedGen4: '#8e44ad',
  infectedGen5: '#555555'
};

export const HUMAN_ABILITY_CONFIG = {
  stunPistol: { cooldownMs: 250, ammo: 12, stunMs: 2000, speed: 600, lifetimeMs: 2000 },
  flareGun: { cooldownMs: 999_999, charges: 1, blindMs: 4000, revealMs: 6000 },
  adrenalineDash: { cooldownMs: 15000, distance: 400 },
  barricade: { cooldownMs: 4000, maxActive: 2, lifeMs: 10000, hp: 3, length: 80 }
};

export const INFECTED_ABILITY_CONFIG = {
  invisibility: { durationMs: 4000, cooldownMs: 30000 },
  screamPulse: { stunRadius: 200, stunMs: 1500, cooldownMs: 20000 },
  pounce: { distance: 300, cooldownMs: 8000 }
};

export const EVENTS = [
  { key: 'BLACKOUT', durationMs: 10000 },
  { key: 'FRENZY_MODE', durationMs: 8000 },
  { key: 'SUPPLY_DROP', durationMs: 0 },
  { key: 'ALARM_TRIGGERED', durationMs: 5000 },
  { key: 'MUTATION', durationMs: 20000 },
  { key: 'FOG_ROLLS_IN', durationMs: 15000 },
  { key: 'ADRENALINE_SURGE', durationMs: 10000 }
];

export const SCORE = {
  lastHuman: 500,
  survive1Min: 100,
  survive2Min: 200,
  infectAny: 100,
  infectAsP0: 150,
  revive: 100,
  generator: 75,
  perfectInfectionBonus: 1000,
  surviveFullAsLastHumanBonus: 300
};
