export const makeControlledWorker = (delay, response, counters) => ({
  _onmessage: undefined,
  set onmessage(callback) {
    this._onmessage = callback
    queueMicrotask(() => callback({data: {ok: true, error: undefined, ready: true}}))
  },
  get onmessage() {
    return this._onmessage
  },
  onerror: undefined,
  postMessage() {
    counters.posted += 1
    setTimeout(() => this.onmessage?.({data: response}), delay)
  },
  terminate() {
    counters.terminated += 1
  },
})

export const makeThrowingWorker = counters => ({
  _onmessage: undefined,
  set onmessage(callback) {
    this._onmessage = callback
    queueMicrotask(() => callback({data: {ok: true, error: undefined, ready: true}}))
  },
  get onmessage() {
    return this._onmessage
  },
  onerror: undefined,
  postMessage() {
    counters.posted += 1
    throw new Error('post failed')
  },
  terminate() {
    counters.terminated += 1
  },
})
