const REQUEST_LIMIT = 256;
const WINDOW_MS = 60_000;
const PRINCIPAL_LIMIT = 4_096;

export class RateLimiter {
  #entries = new Map();

  check(principal, now) {
    if (!Number.isFinite(now) || now < 0) return 0;

    const existing = this.#entries.get(principal);
    if (existing && now < existing.startedAt + WINDOW_MS) {
      if (existing.count >= REQUEST_LIMIT) {
        return Math.max(1, Math.ceil((existing.startedAt + WINDOW_MS - now) / 1000));
      }
      existing.count += 1;
      return null;
    }

    if (existing) this.#entries.delete(principal);
    if (this.#entries.size >= PRINCIPAL_LIMIT) {
      for (const [key, entry] of this.#entries) {
        if (now >= entry.startedAt + WINDOW_MS) this.#entries.delete(key);
      }
    }
    if (this.#entries.size >= PRINCIPAL_LIMIT) return 0;

    this.#entries.set(principal, {startedAt: now, count: 1});
    return null;
  }
}
