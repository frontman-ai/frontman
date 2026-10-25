/// Extend the normal Chromium suite with a real redirect between loopback origins.
module Http = FrontmanBindings.NodeHttp
type middleware
type server = {middlewares: middleware}
@send external use: (middleware, Http.connectMiddleware) => unit = "use"
type plugin = {name: string, configureServer: server => unit}
type settings
type dependencies = {exclude: array<string>, @as("include") include_?: array<string>}
type config = {
  plugins: array<plugin>,
  test: settings,
  resolve: settings,
  optimizeDeps: dependencies,
}
@module("../vitest.browser.config.js") external base: config = "default"

let fixture: plugin = {
  name: "preview-origin-fixture",
  configureServer: server =>
    server.middlewares->use((request, response, next) => {
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
}

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
