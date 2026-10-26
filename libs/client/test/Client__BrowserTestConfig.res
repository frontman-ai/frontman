@@live

/// Reuse the Chromium suite configuration and add HTTP fixtures for origin-boundary tests.
module Http = FrontmanBindings.NodeHttp
module Vite = FrontmanBindings.Astro
type settings
type dependencies = {exclude: array<string>, @as("include") include_?: array<string>}
type config = {
  plugins: array<Vite.vitePlugin>,
  test: settings,
  resolve: settings,
  optimizeDeps: dependencies,
}
@module("../vitest.browser.config.js") external base: config = "default"

let fixture = Vite.makeVitePlugin({
  name: "preview-origin-fixture",
  configureServer: server =>
    server.middlewares->Vite.use((request, response, next) => {
      switch request->Http.url {
      | "/__preview_redirect" =>
        let host = request->Http.headers->Dict.get("host")->Option.getOrThrow
        let port = host->String.split(":")->Array.at(-1)->Option.getOrThrow
        let otherHost = host->String.startsWith("localhost") ? "127.0.0.1" : "localhost"
        response->Http.setStatusCode(302)
        response->Http.setHeader("Location", `http://${otherHost}:${port}/__preview_page`)
        response->Http.end
      | "/__preview_page" =>
        response->Http.setHeader("Content-Type", "text/html")
        response->Http.endWithData(`<!doctype html><title>Supported preview</title><body style="background:white">
          <h1 id="marker">Preview ready</h1><iframe src="/__preview_nested"></iframe></body>`)
      | "/__preview_nested" =>
        response->Http.setHeader("Content-Type", "text/html")
        response->Http.endWithData("<!doctype html><p>Same-origin nested frame</p>")
      | _ => next()
      }
    }),
})

let default = {
  ...base,
  plugins: base.plugins->Array.concat([fixture]),
  optimizeDeps: {
    ...base.optimizeDeps,
    include_: [
      "@base-ui/react/alert-dialog",
      "@base-ui/react/menu",
      "@base-ui/react/tooltip",
      "@bluehotdog/reworker/src/Response.res.mjs",
      "@bluehotdog/reworker/src/Runtime.res.mjs",
      "@bluehotdog/reworker/src/WindowTransport.res.mjs",
    ],
  },
}
