import {Worker} from "node:worker_threads";
import {compileSchema, validateInstance} from "./mcp-json-schema-engine.mjs";

const OPERATION_TIME_LIMIT_MS = 100;
const STARTUP_TIME_LIMIT_MS = 5_000;

export {compileSchema, validateInstance};

export const validateWithRuntime = (schema, value, runtime = {}) => new Promise(resolve => {
  const createWorker = runtime.createWorker ?? (() => {
    const workerUrl = new URL(import.meta.url);
    workerUrl.pathname = workerUrl.pathname.replace(/[^/]*$/, "mcp-json-schema-worker.mjs");
    return new Worker(workerUrl);
  });
  const schedule = runtime.schedule ?? setTimeout;
  const cancel = runtime.cancel ?? clearTimeout;
  let settled = false;
  let worker;
  let operationTimer;
  let startupTimer;
  const finish = result => {
    if (settled) return;
    settled = true;
    cancel(startupTimer);
    cancel(operationTimer);
    worker.removeAllListeners();
    worker.terminate();
    resolve(result);
  };
  try {
    worker = createWorker();
  } catch {
    resolve(false);
    return;
  }
  startupTimer = schedule(() => finish(false), STARTUP_TIME_LIMIT_MS);
  worker.on("message", message => {
    if (message === "ready") {
      operationTimer = schedule(() => finish(false), OPERATION_TIME_LIMIT_MS + 1);
      try {
        worker.postMessage({schema, value});
      } catch {
        finish(false);
      }
    } else {
      finish(message === true);
    }
  });
  worker.on("error", () => finish(false));
  worker.on("exit", code => {
    if (code !== 0) finish(false);
  });
});

export const validateBounded = (schema, value) => validateWithRuntime(schema, value);
