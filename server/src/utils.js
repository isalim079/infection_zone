export function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export function distance(a, b) {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.hypot(dx, dy);
}

export function normalize(vec) {
  const length = Math.hypot(vec.x, vec.y);
  if (!length) {
    return { x: 0, y: 0 };
  }
  return { x: vec.x / length, y: vec.y / length };
}

export function randomCode(length = 4) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += chars[Math.floor(Math.random() * chars.length)];
  }
  return out;
}

export function nowMs() {
  return Date.now();
}
