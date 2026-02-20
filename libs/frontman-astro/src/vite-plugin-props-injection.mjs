// Vite plugin that wraps Astro's renderComponent to inject component props
// as HTML comments into the rendered output.
//
// When an .astro component is rendered server-side, the wrapper writes
// an HTML comment before the component's output:
//   <!-- __frontman_props__:base64json -->
//
// The base64 payload is JSON: { displayName, props, moduleId }
//
// Client-side, the annotation capture script walks the DOM to find these
// comment nodes and associates them with the next annotated element,
// so the AI agent knows which props were passed to each component instance.
//
// This plugin is dev-only and should NOT run in production builds.

/**
 * @returns {import('vite').Plugin}
 */
export function frontmanPropsInjectionPlugin() {
  return {
    name: 'frontman:props-injection',
    enforce: 'pre',
    apply: 'serve',

    // Only apply in SSR (server-side rendering) mode
    transform(code, id, options) {
      if (!options?.ssr) return null

      // Target Astro's renderComponent module
      if (
        !id.includes('astro/dist/runtime/server/render/component') &&
        !id.includes('astro/runtime/server/render/component')
      ) {
        return null
      }

      // Verify this is the right module — warn if the expected function
      // signature is missing (e.g., after an Astro version upgrade that
      // changes the internal API).
      if (!code.includes('function renderComponent(')) {
        console.warn(
          '[Frontman] Could not find renderComponent in Astro internals — ' +
          'component props injection will be disabled. ' +
          'This may happen after an Astro upgrade. File: ' + id
        )
        return null
      }

      // Rename the original function declaration.
      // The recursive call site inside the original (`return renderComponent(...)`)
      // is intentionally left unchanged — it naturally resolves to our wrapper
      // function appended below, which is the desired behavior (props injection
      // applies to nested async component resolution too).
      let transformed = code.replace(
        'function renderComponent(',
        'function __original_renderComponent('
      )

      // Append the wrapper function and helper utilities
      const wrapperCode = `

// --- Frontman props injection wrapper ---

function __frontman_safeSerialize(displayName, Component, props) {
  try {
    const clean = {};
    for (const [key, value] of Object.entries(props || {})) {
      // Skip internal Astro props (scoped CSS hashes)
      if (key.startsWith('data-astro-cid-')) continue;
      // Skip class (styling detail, not semantic)
      if (key === 'class' || key === 'class:list') continue;

      const t = typeof value;
      if (t === 'string' || t === 'number' || t === 'boolean') {
        clean[key] = value;
      } else if (value === null || value === undefined) {
        clean[key] = value;
      } else if (Array.isArray(value)) {
        try {
          const serialized = JSON.stringify(value);
          clean[key] = serialized.length < 1000 ? value : '[Array(' + value.length + ')]';
        } catch {
          clean[key] = '[Array]';
        }
      } else if (t === 'object') {
        try {
          const serialized = JSON.stringify(value);
          clean[key] = serialized.length < 500 ? value : '{...}';
        } catch {
          clean[key] = '{...}';
        }
      }
      // Skip functions, symbols, etc.
    }

    const entry = { displayName, props: clean };
    // Include the component's moduleId (file path) if available
    if (Component && Component.moduleId) {
      entry.moduleId = Component.moduleId;
    }
    return JSON.stringify(entry);
  } catch {
    return null;
  }
}

function __frontman_toBase64(str) {
  if (typeof Buffer !== 'undefined') return Buffer.from(str, 'utf-8').toString('base64');
  if (typeof btoa === 'function') return btoa(unescape(encodeURIComponent(str)));
  return null;
}

function __frontman_wrapInstance(renderInstance, displayName, Component, props) {
  // If no render method (e.g. fragment), pass through
  if (!renderInstance || typeof renderInstance.render !== 'function') {
    return renderInstance;
  }

  const serialized = __frontman_safeSerialize(displayName, Component, props);
  if (!serialized) return renderInstance;

  const encoded = __frontman_toBase64(serialized);
  if (!encoded) return renderInstance;

  const originalRender = renderInstance.render;

  renderInstance.render = function(destination) {
    // Write the props comment BEFORE the component renders.
    // This creates a Comment node in the DOM immediately preceding
    // the component's first rendered element.
    // Guard: markHTMLString is assumed to be in scope from Astro's module.
    // If it's missing (e.g., after an Astro upgrade), skip injection gracefully.
    if (typeof markHTMLString === 'function') {
      destination.write(markHTMLString('<!-- __frontman_props__:' + encoded + ' -->'));
    }
    return originalRender.call(renderInstance, destination);
  };

  return renderInstance;
}

function renderComponent(result, displayName, Component, props, slots) {
  const renderInstance = __original_renderComponent(result, displayName, Component, props, slots);

  // Handle promise (async component resolution)
  if (renderInstance && typeof renderInstance.then === 'function') {
    return renderInstance.then(function(resolved) {
      return __frontman_wrapInstance(resolved, displayName, Component, props);
    });
  }

  return __frontman_wrapInstance(renderInstance, displayName, Component, props);
}

// --- End Frontman props injection wrapper ---
`

      transformed += wrapperCode
      return {
        code: transformed,
        map: null,
      }
    },
  }
}
