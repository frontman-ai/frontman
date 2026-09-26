import { copyFile, readFile } from "node:fs/promises"
import { makeFrontmanPreviewLoaderBody } from "./preview-loader.mjs"
export { makeFrontmanPreviewLoaderBody } from "./preview-loader.mjs"

const bridgeAsset = new URL("../dist/bridge.js", import.meta.url)

export const copyPreviewBridgeAsset = () => copyFile(bridgeAsset, "dist/bridge.js")

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

export function frontmanPreviewLoaderPlugin({ basePath }) {
  const bridgeUrl = `/${basePath}/preview-bridge.js`

  return {
    name: "frontman-preview-loader",
    apply: "serve",
    configureServer(server) {
      server.middlewares.use(bridgeUrl, async (_req, res) => {
        try {
          const bridge = await readFile(bridgeAsset, "utf8")
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
