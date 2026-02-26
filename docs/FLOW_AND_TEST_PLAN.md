# Infection Zone - Product Flow and Stabilization Plan

## 1) End-to-End Player Flow

### A. Entry
1. Open app (landscape).
2. Main menu shows:
   - Nickname
   - Server URL
   - `Create Room`
   - `Quick Play` (same as create for now)
   - `Join Room`
   - `How To Play`

### B. Lobby
1. Room code visible and copyable.
2. Player list visible with role tags (`Host`, `Guest`, `Bot`).
3. Ready toggle per player.
4. Host starts game.
5. Guard against duplicate navigation to game screen.

### C. In-Game Core Loop
1. Left stick = move.
2. Right stick = aim (smooth aiming vector).
3. Fire button:
   - Human: enabled, ammo shown.
   - Infected: visible but disabled with clear text.
4. Abilities panel:
   - Human: FLARE / DASH / BUILD / GENERATOR.
   - Infected: SCREAM / INVIS / POUNCE by generation.
5. Minimap:
   - Shows all players on map (color-coded, larger points).
6. Aiming feedback:
   - Aim line + reticle always visible for local player.

### D. Round End
1. Round end modal shown once.
2. Return to lobby once.
3. No unmounted-context calls.

## 2) Technical Guardrails
1. Snapshot parser handles dynamic map/list payloads.
2. State updates throttled to avoid frame drops.
3. Camera/player interpolation to prevent shaking.
4. Navigation guards prevent stacked routes.
5. Joystick hit-testing uses opaque behavior.

## 3) Acceptance Criteria
1. No shaking from duplicate game overlays.
2. Aim direction updates smoothly while right stick moves.
3. Fire button always present (disabled for infected).
4. Minimap visibly shows all players.
5. Menu has explicit `Create Room` button.
6. Tutorial/help accessible from menu and in-game.

## 4) Validation Checklist
1. `flutter analyze`
2. `flutter test`
3. `npm test`
4. Manual smoke:
   - Create Room -> Ready -> Start -> Move/Aim/Fire -> End -> Lobby
