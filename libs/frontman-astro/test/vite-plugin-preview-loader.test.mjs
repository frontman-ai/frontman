import { describe, expect, test, vi } from "vitest"
import { frontmanPreviewLoaderPlugin, makeFrontmanPreviewLoaderBody } from "../src/vite-plugin-preview-loader.mjs"

describe("frontman Astro preview loader plugin", () => {
  test("exports loader body for Astro head-inline injection", () => {
    const body = makeFrontmanPreviewLoaderBody({ bridgeUrl: "/frontman/preview-bridge.js" })

    expect(body).not.toContain("<script")
    expect(body).toContain("data-frontman-preview-loader-installed")
    expect(body).toContain("__frontman_parent_origin")
    expect(body).toContain("__frontman_channel")
  })

  test("injects one stable loader into development HTML", () => {
    const plugin = frontmanPreviewLoaderPlugin({ basePath: "frontman" })
    const html = "<!doctype html><html><head><title>App</title></head><body></body></html>"
    const transformed = plugin.transformIndexHtml.handler(html, { path: "/" })

    expect(transformed).toContain("data-frontman-preview-loader")
    expect(transformed).toContain("__frontman_parent_origin")
    expect(transformed).toContain("__frontman_channel")
    expect(transformed).toContain("/frontman/preview-bridge.js")
    expect(plugin.transformIndexHtml.handler(transformed, { path: "/" })).toBe(transformed)
  })

  test("does not inject into the Frontman shell route", () => {
    const plugin = frontmanPreviewLoaderPlugin({ basePath: "frontman" })
    const html = "<!doctype html><html><head></head><body></body></html>"

    expect(plugin.transformIndexHtml.handler(html, { path: "/frontman" })).toBe(html)
    expect(plugin.transformIndexHtml.handler(html, { path: "/frontman/" })).toBe(html)
  })

  test("serves the bridge bundle from the development proxy route", async () => {
    const plugin = frontmanPreviewLoaderPlugin({ basePath: "frontman" })
    let registeredPath
    let handler
    const server = {
      middlewares: {
        use: vi.fn((path, fn) => {
          registeredPath = path
          handler = fn
        }),
      },
    }

    plugin.configureServer(server)

    let body = ""
    const res = {
      statusCode: 0,
      headers: {},
      setHeader(name, value) {
        this.headers[name] = value
      },
      end(value) {
        body = value
      },
    }

    await handler({}, res, () => {})

    expect(registeredPath).toBe("/frontman/preview-bridge.js")
    expect(res.statusCode).toBe(200)
    expect(res.headers["Content-Type"]).toBe("text/javascript; charset=utf-8")
    expect(body).toContain("FrontmanPreviewBridge")
  })
})
