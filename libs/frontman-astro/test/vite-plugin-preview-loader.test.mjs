import { expect, test, vi } from "vitest"
import { make } from "../dist/integration.js"

test("built Astro integration wires shared loader, head-inline bootstrap and navigation", async () => {
  const scripts = []
  const updates = []
  make({ basePath: "custom" }).hooks["astro:config:setup"]({
    command: "dev",
    config: { root: "/project/", base: "/", devToolbar: { enabled: true }, markdown: { rehypePlugins: [] }, trailingSlash: "ignore" },
    addDevToolbarApp() {},
    injectScript: (stage, source) => scripts.push([stage, source]),
    updateConfig: config => updates.push(config),
  })
  expect(scripts.find(([stage]) => stage === "head-inline")[1]).toContain("/custom/preview-bridge.js")
  expect(scripts.find(([stage]) => stage === "page")[1]).toContain("/navigation.js")
  const loader = updates.flatMap(config => config.vite?.plugins ?? []).find(plugin => plugin.name === "frontman-preview-loader")
  expect(loader.transformIndexHtml.handler("<head></head>", { path: "/" })).toContain("/custom/preview-bridge.js")
  let handler
  loader.configureServer({ middlewares: { use: (path, callback) => {
    expect(path).toBe("/custom/preview-bridge.js")
    handler = callback
  } } })
  const response = { statusCode: 0, setHeader: vi.fn(), end: vi.fn() }
  await handler({}, response)
  expect(response.statusCode).toBe(200)
  expect(response.end).toHaveBeenCalledWith(expect.stringContaining("FrontmanPreviewBridge"))
})
