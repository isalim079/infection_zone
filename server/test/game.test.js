import test from 'node:test';
import assert from 'node:assert/strict';
import { GameRoom } from '../src/game.js';

function addPlayers(room, n) {
  for (let i = 0; i < n; i += 1) {
    room.addPlayer(`p${i}`, `P${i}`);
    room.setReady(`p${i}`, true);
  }
}

test('round starts when enough players are ready', () => {
  const room = new GameRoom('ABCD', 'p0');
  addPlayers(room, 4);
  assert.equal(room.canStart(), true);
  const started = room.startRound();
  assert.equal(started, true);
  assert.equal(room.phase, 'in_round');
  const infected = [...room.players.values()].filter((p) => p.team === 'infected');
  assert.equal(infected.length, 1);
});

test('infected touching human infects and awards score', () => {
  const room = new GameRoom('ABCD', 'a');
  addPlayers(room, 3);
  room.startRound();

  const infected = [...room.players.values()].find((p) => p.team === 'infected');
  const human = [...room.players.values()].find((p) => p.team === 'human');

  infected.x = 100;
  infected.y = 100;
  human.x = 105;
  human.y = 100;

  room.resolveInfections(Date.now());
  assert.equal(human.team, 'infected');
  assert.ok(infected.score >= 100);
});

test('revive changes recently infected player back to human', () => {
  const room = new GameRoom('ABCD', 'a');
  addPlayers(room, 4);
  room.startRound();

  const humans = [...room.players.values()].filter((p) => p.team === 'human');
  const helper = humans[0];
  const target = humans[1];

  target.team = 'infected';
  target.generation = 2;
  target.justInfectedUntil = Date.now() + 2000;
  helper.x = 100;
  helper.y = 100;
  target.x = 110;
  target.y = 100;

  room.useAbility(helper.id, 'revive', { targetId: target.id });
  assert.equal(target.team, 'human');
});
