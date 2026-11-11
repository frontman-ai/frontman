import {readFile} from "node:fs/promises"
import {createRequire} from "node:module"

const PREFIX = "\0frontman:props:"

const wrapperCode = `

const __frontman_SECRET_KEY = /(?:^|[-_])(?:token|secret|password|passwd|passphrase|authorization|auth|cookie|session|api[-_]?key|access[-_]?key|private[-_]?key|credentials?)(?:$|[-_])/;
const __frontman_MAX_DEPTH = 4;
const __frontman_MAX_COLLECTION_LENGTH = 50;
const __frontman_MAX_VALUE_BYTES = 4096;
const __frontman_MAX_PAYLOAD_BYTES = 16384;

function __frontman_truncateString(value) {
  if (Buffer.byteLength(value, 'utf8') <= __frontman_MAX_VALUE_BYTES) return value;
  return Buffer.from(value, 'utf8').subarray(0, __frontman_MAX_VALUE_BYTES - 11).toString('utf8') + '[Truncated]';
}

function __frontman_isSecretKey(key) {
  const normalized = key.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
  return __frontman_SECRET_KEY.test(normalized);
}

function __frontman_sanitize(value, depth, ancestors) {
  if (value === null || value === undefined) return value;
  const type = typeof value;
  if (type === 'string') return __frontman_truncateString(value);
  if (type === 'number' || type === 'boolean') return value;
  if (type !== 'object') return undefined;
  if (depth >= __frontman_MAX_DEPTH) return '[Max depth]';
  if (ancestors.includes(value)) return '[Circular]';

  const nextAncestors = [...ancestors, value];
  if (Array.isArray(value)) {
    const output = value.slice(0, __frontman_MAX_COLLECTION_LENGTH).map(item =>
      __frontman_sanitize(item, depth + 1, nextAncestors)
    );
    if (value.length > __frontman_MAX_COLLECTION_LENGTH) {
      output.push('[Truncated ' + (value.length - __frontman_MAX_COLLECTION_LENGTH) + ' items]');
    }
    return output;
  }

  const prototype = Object.getPrototypeOf(value);
  if (prototype !== Object.prototype && prototype !== null) return '[Object]';

  const output = {};
  const keys = Object.keys(value);
  for (const key of keys.slice(0, __frontman_MAX_COLLECTION_LENGTH)) {
    if (key.startsWith('data-astro-cid-') || key === 'class' || key === 'class:list') continue;
    output[key] = __frontman_isSecretKey(key)
      ? '[REDACTED]'
      : __frontman_sanitize(value[key], depth + 1, nextAncestors);
  }
  if (keys.length > __frontman_MAX_COLLECTION_LENGTH) {
    output.__truncated__ = keys.length - __frontman_MAX_COLLECTION_LENGTH;
  }
  return output;
}

function __frontman_safeSerialize(displayName, Component, props) {
  try {
    const entry = {
      displayName,
      props: __frontman_sanitize(props || {}, 0, []),
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

  const marker = __frontman_propsMarker(displayName, Component, props);
  if (!marker) return renderInstance;
  const originalRender = renderInstance.render;
  return {
    render(destination) {
      destination.write(unescapeHTML(marker));
      return originalRender.call(renderInstance, destination);
    }
  };
}

function __frontman_propsMarker(displayName, Component, props) {
  const serialized = __frontman_safeSerialize(displayName, Component, props);
  return serialized ? '<!-- __frontman_props__:' + Buffer.from(serialized, 'utf8').toString('base64') + ' -->' : null;
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

async function renderComponentToString(result, displayName, Component, props, ...rest) {
  const resolved = await Component;
  const marker = __frontman_propsMarker(displayName, resolved, props);
  const output = await __original_renderComponentToString(result, displayName, resolved, props, ...rest);
  return marker ? marker + output : output;
}
`

export function frontmanPropsInjectionPlugin() {
  let root
  let runtime
  let htmlRuntimeId

  async function resolveRenderer(parse) {
    const require = createRequire(`${root}/package.json`)
    htmlRuntimeId = require.resolve("astro/runtime/server/index.js").replaceAll("\\", "/")
    let id = require.resolve("astro/runtime/server/render/component.js")
    const visited = new Set()
    while (!visited.has(id)) {
      visited.add(id)
      const ast = parse(await readFile(id, "utf8"))
      if (ast.body.length !== 1 || ast.body[0].type !== "ExportAllDeclaration") {
        return id.replaceAll("\\", "/")
      }
      id = createRequire(id).resolve(ast.body[0].source.value)
    }
    throw new Error("[Frontman] Circular Astro renderer re-export")
  }

  return {
    name: "frontman:props-injection",
    enforce: "pre",
    apply: "serve",
    configResolved(config) {
      root = config.root
    },
    async resolveId(source, importer, options) {
      if (!options?.ssr || importer?.startsWith(PREFIX)) return null
      runtime ??= resolveRenderer(code => this.parse(code))
      const runtimeId = await runtime
      const original = await this.resolve(source, importer, {...options, skipSelf: true})
      return original?.id === runtimeId ? PREFIX + runtimeId : null
    },
    load(id) {
      if (!id.startsWith(PREFIX)) return null
      const original = JSON.stringify(id.slice(PREFIX.length))
      return `
export * from ${original};
import {renderComponent as __original_renderComponent, renderComponentToString as __original_renderComponentToString} from ${original};
import {unescapeHTML} from ${JSON.stringify(htmlRuntimeId)};
${wrapperCode}
export {renderComponent, renderComponentToString};
`
    },
  }
}
