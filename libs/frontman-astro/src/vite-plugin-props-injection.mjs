import MagicString from "magic-string"

const RUNTIME_MODULES = [
  "astro/dist/runtime/server/render/component",
  "astro/runtime/server/render/component",
]

function findClosingBrace(code, openingBrace) {
  let depth = 0
  let quote = null
  let lineComment = false
  let blockComment = false

  for (let index = openingBrace; index < code.length; index++) {
    const char = code[index]
    const next = code[index + 1]

    if (lineComment) {
      if (char === "\n") lineComment = false
      continue
    }
    if (blockComment) {
      if (char === "*" && next === "/") {
        blockComment = false
        index++
      }
      continue
    }
    if (quote) {
      if (char === "\\") index++
      else if (char === quote) quote = null
      continue
    }
    if (char === "/" && next === "/") {
      lineComment = true
      index++
      continue
    }
    if (char === "/" && next === "*") {
      blockComment = true
      index++
      continue
    }
    if (char === '"' || char === "'" || char === "`") {
      quote = char
      continue
    }
    if (char === "{") depth++
    if (char === "}" && --depth === 0) return index
  }

  return -1
}

function findRenderComponent(code) {
  const declaration = /\bfunction\s+renderComponent\s*\(([^)]*)\)\s*\{/g
  const matches = [...code.matchAll(declaration)]
  if (matches.length !== 1) return null

  const match = matches[0]
  const parameters = match[1].split(",").map(parameter => parameter.trim())
  if (parameters.length !== 5) return null

  const nameStart = match.index + match[0].indexOf("renderComponent")
  const openingBrace = match.index + match[0].lastIndexOf("{")
  const closingBrace = findClosingBrace(code, openingBrace)
  if (closingBrace === -1) return null

  return {nameStart, openingBrace, closingBrace}
}

function hasMarkHTMLStringBinding(code) {
  return (
    /import\s*\{[^}]*\bmarkHTMLString\b[^}]*\}/s.test(code) ||
    /\b(?:function|const|let|var)\s+markHTMLString\b/.test(code)
  )
}

function recursiveCalls(code, start, end) {
  const calls = []
  const pattern = /\brenderComponent\s*(?=\()/g
  pattern.lastIndex = start

  for (let match = pattern.exec(code); match && match.index < end; match = pattern.exec(code)) {
    calls.push({start: match.index, end: match.index + "renderComponent".length})
  }
  return calls
}

const wrapperCode = `

const __frontman_SECRET_KEY = /token|secret|password|passwd|passphrase|authorization|auth|cookie|session|api[-_]?key|access[-_]?key|private[-_]?key|credential/i;
const __frontman_MAX_DEPTH = 4;
const __frontman_MAX_COLLECTION_LENGTH = 50;
const __frontman_MAX_VALUE_BYTES = 4096;
const __frontman_MAX_PAYLOAD_BYTES = 16384;

function __frontman_truncateString(value) {
  if (Buffer.byteLength(value, 'utf8') <= __frontman_MAX_VALUE_BYTES) return value;
  return Buffer.from(value, 'utf8').subarray(0, __frontman_MAX_VALUE_BYTES - 11).toString('utf8') + '[Truncated]';
}

function __frontman_sanitize(value, depth, seen) {
  if (value === null || value === undefined) return value;
  const type = typeof value;
  if (type === 'string') return __frontman_truncateString(value);
  if (type === 'number' || type === 'boolean') return value;
  if (type !== 'object') return undefined;
  if (depth >= __frontman_MAX_DEPTH) return '[Max depth]';
  if (seen.has(value)) return '[Circular]';

  seen.add(value);
  if (Array.isArray(value)) {
    const output = value.slice(0, __frontman_MAX_COLLECTION_LENGTH).map(item =>
      __frontman_sanitize(item, depth + 1, seen)
    );
    if (value.length > __frontman_MAX_COLLECTION_LENGTH) {
      output.push('[Truncated ' + (value.length - __frontman_MAX_COLLECTION_LENGTH) + ' items]');
    }
    return output;
  }

  const prototype = Object.getPrototypeOf(value);
  if (prototype !== Object.prototype && prototype !== null) return '[Object]';

  const output = {};
  const entries = Object.entries(value);
  for (const [key, item] of entries.slice(0, __frontman_MAX_COLLECTION_LENGTH)) {
    if (key.startsWith('data-astro-cid-') || key === 'class' || key === 'class:list') continue;
    output[key] = __frontman_SECRET_KEY.test(key)
      ? '[REDACTED]'
      : __frontman_sanitize(item, depth + 1, seen);
  }
  if (entries.length > __frontman_MAX_COLLECTION_LENGTH) {
    output.__truncated__ = entries.length - __frontman_MAX_COLLECTION_LENGTH;
  }
  return output;
}

function __frontman_safeSerialize(displayName, Component, props) {
  try {
    const entry = {
      displayName,
      props: __frontman_sanitize(props || {}, 0, new WeakSet()),
    };
    if (Component && Component.moduleId) {
      entry.moduleId = String(Component.moduleId).replaceAll('\\\\', '/');
    }

    let serialized = JSON.stringify(entry);
    if (Buffer.byteLength(serialized, 'utf8') > __frontman_MAX_PAYLOAD_BYTES) {
      serialized = JSON.stringify({displayName, props: {__truncated__: true}, moduleId: entry.moduleId});
    }
    return serialized;
  } catch {
    return null;
  }
}

function __frontman_wrapInstance(renderInstance, displayName, Component, props) {
  if (!renderInstance || typeof renderInstance.render !== 'function') return renderInstance;

  const serialized = __frontman_safeSerialize(displayName, Component, props);
  if (!serialized) return renderInstance;
  const encoded = Buffer.from(serialized, 'utf8').toString('base64');
  const originalRender = renderInstance.render;
  renderInstance.render = function(destination) {
    destination.write(markHTMLString('<!-- __frontman_props__:' + encoded + ' -->'));
    return originalRender.call(renderInstance, destination);
  };
  return renderInstance;
}

function __frontman_renderAndWrap(result, displayName, Component, props, slots) {
  const renderInstance = __original_renderComponent(result, displayName, Component, props, slots);
  if (renderInstance && typeof renderInstance.then === 'function') {
    return renderInstance.then(resolved =>
      __frontman_wrapInstance(resolved, displayName, Component, props)
    );
  }
  return __frontman_wrapInstance(renderInstance, displayName, Component, props);
}

function renderComponent(result, displayName, Component, props, slots) {
  if (Component && typeof Component.then === 'function') {
    return Component.then(resolved =>
      __frontman_renderAndWrap(result, displayName, resolved, props, slots)
    );
  }
  return __frontman_renderAndWrap(result, displayName, Component, props, slots);
}
`

export function frontmanPropsInjectionPlugin() {
  let warned = false

  function warn(id) {
    if (warned) return
    warned = true
    console.warn(
      "[Frontman] Unsupported Astro renderComponent runtime; component props capture disabled. " + id,
    )
  }

  return {
    name: "frontman:props-injection",
    enforce: "pre",
    apply: "serve",
    transform(code, id, options) {
      if (!options?.ssr || !RUNTIME_MODULES.some(moduleId => id.includes(moduleId))) return null

      const renderComponent = findRenderComponent(code)
      if (!renderComponent || !hasMarkHTMLStringBinding(code)) {
        warn(id)
        return null
      }

      const output = new MagicString(code)
      output.overwrite(
        renderComponent.nameStart,
        renderComponent.nameStart + "renderComponent".length,
        "__original_renderComponent",
      )
      for (const call of recursiveCalls(
        code,
        renderComponent.openingBrace + 1,
        renderComponent.closingBrace,
      )) {
        output.overwrite(call.start, call.end, "__original_renderComponent")
      }
      output.append(wrapperCode)

      return {
        code: output.toString(),
        map: output.generateMap({hires: true, source: id, includeContent: true}),
      }
    },
  }
}
