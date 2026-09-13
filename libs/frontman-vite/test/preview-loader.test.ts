import { expect, test, vi } from "vitest"
import { frontmanPlugin } from "../dist/index.js"

test("built Vite plugin wires the shared loader and resolves its bridge asset", async () => {
  const loader = frontmanPlugin({ basePath: "custom" }).find(plugin => plugin.name === "frontman-preview-loader")
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
