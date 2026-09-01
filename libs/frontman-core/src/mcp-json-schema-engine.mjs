import Ajv2020 from "ajv/dist/2020.js";

const SCHEMA_DEPTH_LIMIT = 32;
const SCHEMA_NODE_LIMIT = 1_024;
const INSTANCE_DEPTH_LIMIT = 64;
const INSTANCE_NODE_LIMIT = 65_536;
const INSTANCE_BYTE_LIMIT = 2_097_152;
const OPERATION_TIME_LIMIT_MS = 100;
const DIALECT = "https://json-schema.org/draft/2020-12/schema";

const measure = (value, depthLimit, nodeLimit) => {
  const stack = [[value, 1]];
  let nodes = 0;
  while (stack.length > 0) {
    const [current, depth] = stack.pop();
    if (current === null || typeof current !== "object") continue;
    nodes += 1;
    if (depth > depthLimit || nodes > nodeLimit) return false;
    const children = Array.isArray(current) ? current : Object.values(current);
    for (const child of children) stack.push([child, depth + 1]);
  }
  return true;
};

const schemaPolicyAllows = schema => {
  const stack = [schema];
  while (stack.length > 0) {
    const current = stack.pop();
    if (current === null || typeof current !== "object") continue;
    if (!Array.isArray(current)) {
      if ("$schema" in current && current.$schema !== DIALECT) return false;
      for (const keyword of ["$ref", "$dynamicRef"]) {
        if (keyword in current && (typeof current[keyword] !== "string" || !current[keyword].startsWith("#"))) {
          return false;
        }
      }
    }
    for (const child of Array.isArray(current) ? current : Object.values(current)) stack.push(child);
  }
  return true;
};

export const compileSchema = schema => {
  if (!measure(schema, SCHEMA_DEPTH_LIMIT, SCHEMA_NODE_LIMIT) || !schemaPolicyAllows(schema)) return null;
  const startedAt = performance.now();
  try {
    const ajv = new Ajv2020({allErrors: false, strict: false, validateFormats: false});
    const validate = ajv.compile(schema);
    return performance.now() - startedAt <= OPERATION_TIME_LIMIT_MS ? validate : null;
  } catch {
    return null;
  }
};

export const validateInstance = (validate, value) => {
  let encoded;
  try {
    encoded = JSON.stringify(value);
  } catch {
    return false;
  }
  if (Buffer.byteLength(encoded, "utf8") > INSTANCE_BYTE_LIMIT) return false;
  if (!measure(value, INSTANCE_DEPTH_LIMIT, INSTANCE_NODE_LIMIT)) return false;
  const startedAt = performance.now();
  try {
    const valid = validate(value) === true;
    return performance.now() - startedAt <= OPERATION_TIME_LIMIT_MS && valid;
  } catch {
    return false;
  }
};
