import http from 'node:http';
import express from 'express';
import cors from 'cors';
import { Server } from 'socket.io';
import { LOOP_DELTA_MS, RoomManager } from './game.js';
import { nowMs, randomCode } from './utils.js';

const PORT = Number(process.env.PORT || 5001);
const app = express();
app.use(cors());
app.get('/health', (_req, res) => {
  res.json({ ok: true, ts: nowMs() });
});

const httpServer = http.createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const manager = new RoomManager();
const lastEventSent = new Map();
const lastStateSentAt = new Map();
const STATE_BROADCAST_MS = 100;

function emitRoomState(room) {
  const payload = room.stateFor('');
  io.to(room.code).emit('room_state', payload);
}

function uniqueRoomCode() {
  for (let i = 0; i < 10; i += 1) {
    const code = randomCode();
    if (!manager.rooms.has(code)) return code;
  }
  throw new Error('Could not allocate room code');
}

io.on('connection', (socket) => {
  socket.emit('connected', { id: socket.id });

  socket.on('create_room', ({ name }) => {
    const code = uniqueRoomCode();
    const room = manager.createRoom(code, socket.id, name);
    socket.join(code);
    emitRoomState(room);
  });

  socket.on('join_room', ({ code, name }) => {
    const room = manager.joinRoom(String(code || '').toUpperCase(), socket.id, name);
    if (!room) {
      socket.emit('error_message', { message: 'Room not found or full' });
      return;
    }
    socket.join(room.code);
    emitRoomState(room);
  });

  socket.on('set_ready', ({ ready }) => {
    const room = manager.getRoomByPlayer(socket.id);
    if (!room) return;
    room.setReady(socket.id, ready);
    emitRoomState(room);
  });

  socket.on('start_game', () => {
    const room = manager.getRoomByPlayer(socket.id);
    if (!room) return;
    if (room.hostId !== socket.id) return;
    const started = room.startRound();
    if (!started) {
      socket.emit('error_message', { message: 'Need at least 3 ready players to start' });
      return;
    }
    io.to(room.code).emit('round_started', { roundEndsAt: room.roundEndsAt });
    emitRoomState(room);
  });

  socket.on('input', (payload) => {
    const room = manager.getRoomByPlayer(socket.id);
    if (!room) return;
    room.submitInput(socket.id, payload);
  });

  socket.on('use_ability', ({ ability, payload }) => {
    const room = manager.getRoomByPlayer(socket.id);
    if (!room) return;
    room.useAbility(socket.id, ability, payload);
  });

  socket.on('disconnect', () => {
    const room = manager.getRoomByPlayer(socket.id);
    manager.removePlayer(socket.id);
    if (room) {
      emitRoomState(room);
    }
  });
});

setInterval(() => {
  const updates = [];
  const tickNow = nowMs();
  for (const room of manager.rooms.values()) {
    const ended = room.tick(tickNow);
    const snapshot = room.stateFor('');
    updates.push([room.code, snapshot, ended]);
  }

  for (const [code, snapshot, ended] of updates) {
    const prevStateAt = lastStateSentAt.get(code) || 0;
    const shouldEmitState = ended || tickNow - prevStateAt >= STATE_BROADCAST_MS;
    if (shouldEmitState) {
      io.to(code).emit('game_state', snapshot);
      lastStateSentAt.set(code, tickNow);
    }
    if (ended) {
      io.to(code).emit('round_ended', ended);
      io.to(code).emit('room_state', snapshot);
      lastEventSent.delete(code);
    }
    const eventSig = snapshot.activeEvent ? `${snapshot.activeEvent}:${snapshot.activeEventEndsAt}` : '';
    if (eventSig && lastEventSent.get(code) !== eventSig) {
      io.to(code).emit('event_triggered', {
        key: snapshot.activeEvent,
        endsAt: snapshot.activeEventEndsAt
      });
      lastEventSent.set(code, eventSig);
    } else if (!eventSig) {
      lastEventSent.delete(code);
    }
  }
}, LOOP_DELTA_MS);

httpServer.listen(PORT, () => {
  console.log(`Infection Zone server listening on :${PORT}`);
});
