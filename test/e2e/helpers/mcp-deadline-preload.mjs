const nativeSetTimeout = globalThis.setTimeout;

globalThis.setTimeout = (callback, delay, ...args) =>
  nativeSetTimeout(callback, delay >= 600000 ? 10_000 : delay, ...args);
