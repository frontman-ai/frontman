import {parentPort} from "node:worker_threads";
import {compileSchema, validateInstance} from "./mcp-json-schema-engine.mjs";

parentPort.on("message", ({schema, value}) => {
  const validator = compileSchema(schema);
  parentPort.postMessage(validator !== null && validateInstance(validator, value));
});
parentPort.postMessage("ready");
