import { createRequire } from "node:module"
import { readFile } from "node:fs/promises"

const require = createRequire(import.meta.url)

const parentOriginParam = "__frontman_parent_origin"
const channelParam = "__frontman_channel"

function escapeScriptString(value) {
  return JSON.stringify(value).replace(/</g, "\\u003c")
}

export function makeFrontmanPreviewLoaderBody({ bridgeUrl }) {
  return `(function(){
  var installedAttribute = "data-frontman-preview-loader-installed";
  if (document.documentElement.hasAttribute(installedAttribute)) return;
  document.documentElement.setAttribute(installedAttribute, "true");

  var params = new URLSearchParams(window.location.search);
  var parentOrigin = params.get(${escapeScriptString(parentOriginParam)});
  var channel = params.get(${escapeScriptString(channelParam)});
  if (!parentOrigin || !channel) {
    console.error("Frontman preview bridge loader missing runtime params", {
      hasParentOrigin: !!parentOrigin,
      hasChannel: !!channel
    });
    return;
  }

  params.delete(${escapeScriptString(parentOriginParam)});
  params.delete(${escapeScriptString(channelParam)});
  var cleanSearch = params.toString();
  var cleanUrl = window.location.pathname + (cleanSearch ? "?" + cleanSearch : "") + window.location.hash;
  window.history.replaceState(window.history.state, "", cleanUrl);

  if (document.querySelector("script[data-frontman-bridge]")) return;
  var script = document.createElement("script");
  script.src = ${escapeScriptString(bridgeUrl)};
  script.async = false;
  script.setAttribute("data-frontman-bridge", "true");
  script.setAttribute("data-frontman-parent-origin", parentOrigin);
  script.setAttribute("data-frontman-channel", channel);
  script.onerror = function() {
    console.error("Frontman preview bridge script failed to load", { src: script.src });
  };
  document.head.appendChild(script);
})();`
}

function makeLoaderScript({ bridgeUrl }) {
  return `<script data-frontman-preview-loader>${makeFrontmanPreviewLoaderBody({ bridgeUrl })}</script>`
}

function shouldSkipHtmlTransform(html, ctx, basePath) {
  if (html.includes("data-frontman-preview-loader")) return true

  const path = String(ctx?.path ?? "")
  const normalizedBase = `/${basePath}`.toLowerCase()
  const normalizedPath = path.toLowerCase().replace(/\/+$/, "")
  return normalizedPath === normalizedBase || normalizedPath.startsWith(`${normalizedBase}/`)
}

export function frontmanPreviewLoaderPlugin(options = {}) {
  const basePath = options.basePath || "frontman"
  const bridgeUrl = options.bridgeUrl || `/${basePath}/preview-bridge.js`

  return {
    name: "frontman-preview-loader",
    apply: "serve",
    configureServer(server) {
      server.middlewares.use(bridgeUrl, async (_req, res, next) => {
        try {
          const bridgePath = require.resolve("@frontman-ai/frontman-preview-bridge/dist/bridge.js")
          const bridge = await readFile(bridgePath, "utf8")
          res.statusCode = 200
          res.setHeader("Content-Type", "text/javascript; charset=utf-8")
          res.end(bridge)
        } catch (error) {
          console.error("Frontman preview bridge asset unavailable", error)
          res.statusCode = 500
          res.end("Frontman preview bridge asset unavailable")
        }
      })
    },
    transformIndexHtml: {
      order: "pre",
      handler(html, ctx) {
        if (shouldSkipHtmlTransform(html, ctx, basePath)) return html

        const loader = makeLoaderScript({ bridgeUrl })
        if (/<head\b[^>]*>/i.test(html)) {
          return html.replace(/<head(\s[^>]*)?>/i, match => `${match}\n${loader}`)
        }
        return `${loader}\n${html}`
      },
    },
  }
}
