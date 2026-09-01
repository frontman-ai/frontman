import {EventEmitter} from "node:events";
import {describe, expect, it} from "vitest";
import {validateBounded, validateWithRuntime} from "../src/mcp-json-schema.mjs";

class ControlledWorker extends EventEmitter {
  constructor({postError} = {}) {
    super();
    this.postError = postError;
    this.terminated = false;
    queueMicrotask(() => this.emit("message", "ready"));
  }

  postMessage() {
    if (this.postError) throw this.postError;
  }

  terminate() {
    this.terminated = true;
  }
}

describe("bounded MCP JSON Schema worker", () => {
  it("validates ordinary values in a real worker", async () => {
    await expect(validateBounded({type: "string"}, "valid")).resolves.toBe(true);
    await expect(validateBounded({type: "string"}, 1)).resolves.toBe(false);
  });

  it("terminates at the first millisecond beyond the 100 ms operation budget", async () => {
    const timers = [];
    const worker = new ControlledWorker();
    const promise = validateWithRuntime({}, null, {
      createWorker: () => worker,
      schedule: (callback, delay) => {
        const timer = {callback, delay};
        timers.push(timer);
        return timer;
      },
      cancel: () => {},
    });
    await Promise.resolve();
    const operationTimer = timers.find(timer => timer.delay === 101);
    expect(operationTimer).toBeDefined();
    operationTimer.callback();
    await expect(promise).resolves.toBe(false);
    expect(worker.terminated).toBe(true);
    expect(worker.listenerCount("message")).toBe(0);
  });

  it("fails closed and cleans up when postMessage throws", async () => {
    const worker = new ControlledWorker({postError: new Error("clone failed")});
    await expect(validateWithRuntime({}, null, {createWorker: () => worker})).resolves.toBe(false);
    expect(worker.terminated).toBe(true);
    expect(worker.listenerCount("error")).toBe(0);
  });

  it("fails closed when worker construction throws", async () => {
    await expect(validateWithRuntime({}, null, {
      createWorker: () => { throw new Error("worker unavailable"); },
    })).resolves.toBe(false);
  });
});
