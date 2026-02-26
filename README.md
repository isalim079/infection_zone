# Infection Zone MVP

Playable Flutter + Flame client with Node.js + Socket.io backend.

## What is implemented
- Real-time multiplayer room server (`3-16` target, bot auto-fill for solo testing).
- Lobby flow: create room, join room, ready, host start.
- Authoritative round loop (3 min), infection spread, revive window, scoring, random events.
- Human/infected abilities (core set wired).
- Mobile top-down gameplay with joystick + ability buttons.
- Android-emulator-ready default server URL (`http://10.0.2.2:5001`).

## Run locally (Android emulator)

1. Start backend:
```bash
cd /Volumes/Salim_EX/salim/infection_zone/server
npm install
npm start
```

2. Start app on emulator (new terminal):
```bash
cd /Volumes/Salim_EX/salim/infection_zone/app
flutter pub get
flutter run -d emulator-5554
```

3. In app menu:
- Keep server URL as `http://10.0.2.2:5001`
- Enter nickname
- Tap `Quick Play`
- Tap `Ready`
- Tap `Start Game`

Notes:
- If only one real player is in room, server injects bots to start a playable match.
- Use `flutter devices` to find your emulator id if different from `emulator-5554`.

## Verification done
- `server`: `npm test` passed.
- `app`: `flutter analyze` passed.
- `app`: `flutter test` passed.
- Smoke run: app launched successfully on Android emulator and backend `/health` returned OK.

## Asset sources
Downloaded PNG assets from OpenMoji (open-source):
- https://github.com/hfg-gmuend/openmoji

Files are under:
- `/Volumes/Salim_EX/salim/infection_zone/app/assets/images`
