import { createRequire } from "node:module"
import { readFile } from "node:fs/promises"

const require = createRequire(import.meta.url)

export function isPreviewBridgePath(requestUrl, basePath = "frontman") {
  const url = new URL(requestUrl)
  const expected = `/${basePath}/preview-bridge.js`.replace(/\/+/g, "/").toLowerCase()
  return url.pathname.toLowerCase() === expected
}

export async function makePreviewBridgeResponse() {
  try {
    const bridgePath = require.resolve("@frontman-ai/frontman-preview-bridge/dist/bridge.js")
    const bridge = await readFile(bridgePath, "utf8")
    return new Response(bridge, {
      status: 200,
      headers: {
        "Content-Type": "text/javascript; charset=utf-8",
        "Cache-Control": "no-store",
      },
    })
  } catch (error) {
    console.error("Frontman preview bridge asset unavailable", error)
    return new Response("Frontman preview bridge asset unavailable", {
      status: 500,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    })
  }
}
