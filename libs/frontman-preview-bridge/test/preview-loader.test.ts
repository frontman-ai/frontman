import { describe, expect, test, vi } from "vitest"
import { JSDOM } from "jsdom"
import { readFile } from "node:fs/promises"

vi.mock("node:fs/promises", async importOriginal => {
  const original = await importOriginal<typeof import("node:fs/promises")>()
  return { ...original, readFile: vi.fn(original.readFile) }
})

import { frontmanPreviewLoaderPlugin, makeFrontmanPreviewLoaderBody } from "../src/vite-plugin-preview-loader.mjs"

describe("shared preview loader plugin", () => {
  test("hands off exact runtime params, cleans the URL, escapes script strings, and installs once", () => {
    const dom = new JSDOM("<!doctype html><head></head><body></body>", {
      url: "https://child.example/path?keep=1&__frontman_parent_origin=https%3A%2F%2Fparent.example%3A9443&__frontman_channel=a%26b#section",
      runScripts: "outside-only",
    })
    const bridgeUrl = '/custom/bridge.js?value=</script>"'
    const body = makeFrontmanPreviewLoaderBody({ bridgeUrl })
    expect(body).not.toContain("</script>")
    dom.window.eval(body)
    dom.window.eval(body)
    const scripts = dom.window.document.querySelectorAll("script[data-frontman-bridge]")
    expect(scripts).toHaveLength(1)
    expect(scripts[0].getAttribute("src")).toBe(bridgeUrl)
    expect(scripts[0].getAttribute("data-frontman-parent-origin")).toBe("https://parent.example:9443")
    expect(scripts[0].getAttribute("data-frontman-channel")).toBe("a&b")
    expect(dom.window.location.href).toBe("https://child.example/path?keep=1#section")
    dom.window.close()
  })

  test("honors custom base paths, nested shell routes, and HTML without a head", () => {
    const plugin = frontmanPreviewLoaderPlugin({ basePath: "tools" })
    const html = "<body>App</body>"
    const transformed = plugin.transformIndexHtml.handler(html, { path: "/" })
    expect(transformed).toContain("/tools/preview-bridge.js")
    expect(plugin.transformIndexHtml.handler(transformed, { path: "/" })).toBe(transformed)
    expect(plugin.transformIndexHtml.handler(html, { path: "/tools" })).toBe(html)
    expect(plugin.transformIndexHtml.handler(html, { path: "/tools/" })).toBe(html)
    expect(plugin.transformIndexHtml.handler(html, { path: "/TOOLS/nested/" })).toBe(html)
    expect(plugin.transformIndexHtml.handler(html, { path: "/toolsmith" })).not.toBe(html)
  })

  test("returns an explicit asset error", async () => {
    vi.mocked(readFile).mockRejectedValueOnce(new Error("asset missing"))
    const error = vi.spyOn(console, "error").mockImplementation(() => {})
    let handler
    frontmanPreviewLoaderPlugin({ basePath: "tools" }).configureServer({
      middlewares: { use: (_path, callback) => { handler = callback } },
    })
    const response = { statusCode: 0, end: vi.fn() }
    await handler({}, response)
    expect(response.statusCode).toBe(500)
    expect(response.end).toHaveBeenCalledWith("Frontman preview bridge asset unavailable")
    expect(error).toHaveBeenCalled()
    error.mockRestore()
  })
})
