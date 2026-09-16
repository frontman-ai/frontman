module Browser = FrontmanBindings.Playwright
module Fs = FrontmanBindings.Fs

@module("../../frontman-preview-bridge/src/preview-loader.mjs")
external makeLoader: {"bridgeUrl": string} => string = "makeFrontmanPreviewLoaderBody"

@module("../../frontman-preview-bridge/src/vite-plugin-preview-loader.mjs")
external makePlugin: {"basePath": string} => {
  "transformIndexHtml": {"handler": (string, {"path": string}) => string},
} = "frontmanPreviewLoaderPlugin"

@module("../../frontman-nextjs/dist/index.js")
external makeNextMiddleware: {..} => WebAPI.Request.t => promise<option<WebAPI.Response.t>> =
  "createMiddleware"

let run = async (~engine, ~launch) => {
  let bundles = await FrontmanBindings.Vite.buildLibrary({
    "configFile": false,
    "build": {
      "lib": {"entry": "test/Client__PageContextBrowser.res.mjs", "formats": ["es"]},
      "write": false,
      "minify": false,
    },
    "define": Dict.fromArray([
      ("process.env.NODE_ENV", `"test"`),
      ("__PACKAGE_VERSION__", `"test"`),
    ]),
  })
  let bundle = bundles->Array.get(0)->Option.getOrThrow
  let entry =
    bundle.output
    ->Array.find(output => output["type"] === "chunk" && output["isEntry"] === Some(true))
    ->Option.getOrThrow
  let parentBundle = entry["code"]->Option.getOrThrow
  let bridge = await Fs.Promises.readFile("../frontman-preview-bridge/dist/bridge.js")
  FrontmanBindings.Process.env->Dict.set("FRONTMAN_ENABLED", "true")
  let middleware = makeNextMiddleware({"basePath": "custom"})
  let response = await middleware(
    WebAPI.Request.fromURL("http://child.test/custom/preview-bridge.js"),
  )
  let nextBridge = await response->Option.getOrThrow->WebAPI.Response.text
  switch nextBridge === bridge {
  | true => ()
  | false => JsError.throwWithMessage("Built Next.js middleware must serve the packaged bridge")
  }
  let nextLoader = await Fs.Promises.readFile("../frontman-nextjs/dist/preview-loader.js")
  let wpLoader = await Fs.Promises.readFile("../frontman-wordpress/assets/preview-loader.js")
  let wpBridge = await Fs.Promises.readFile("../frontman-wordpress/assets/bridge.js")
  let launched = await launch({"headless": true})
  try {
    let parentOrigin = "https://parent.test"
    let childOrigin = "https://preview.test"
    let inline = makeLoader({"bridgeUrl": "/custom/preview-bridge.js"})
    let markup = `<!DOCTYPE html><html><head><title>Cross-origin child</title><meta name="astro-view-transitions-enabled"></head><body><main>Child content</main><script>
      window.addEventListener("message", event => {
        if (event.origin !== "${parentOrigin}" || event.source !== window.parent) return;
        if (event.data === "navigate") location.assign("/next?application=kept#section");
        if (event.data === "reload") location.reload();
        if (event.data === "back") history.back();
        if (event.data === "forward") history.forward();
      });
    </script></body></html>`
    let plugin = makePlugin({"basePath": "custom"})
    let scenarios = [
      (
        "Astro",
        markup->String.replace(
          "</head>",
          `<script>${inline}</script><script>${inline}</script></head>`,
        ),
      ),
      ("Vite", plugin["transformIndexHtml"]["handler"](markup, {"path": "/"})),
      (
        "Next.js",
        markup->String.replace(
          "</head>",
          "<script type=\"module\" src=\"/next-loader.js\"></script></head>",
        ),
      ),
      (
        "WordPress",
        markup->String.replace(
          "</head>",
          "<script src=\"/blog/wp-content/plugins/frontman/assets/preview-loader.js\"></script></head>",
        ),
      ),
    ]
    for index in 0 to scenarios->Array.length - 1 {
      let (platform, childHtml) = scenarios->Array.getUnsafe(index)
      let page = await launched->Browser.newPage({"colorScheme": #dark})
      await page->Browser.route(`${parentOrigin}/**`, route =>
        route->Browser.fulfill({
          "contentType": "text/html",
          "body": "<!DOCTYPE html><html><title>Parent shell</title><body><script>window.__frontmanRuntime={framework:\"vite\",basePath:\"custom\"}</script><script type=\"module\" src=\"/test.js\"></script></body></html>",
        })
      )
      await page->Browser.route(`${parentOrigin}/test.js`, route =>
        route->Browser.fulfill({"contentType": "text/javascript", "body": parentBundle})
      )
      await page->Browser.route(`${childOrigin}/**`, route =>
        route->Browser.fulfill({"contentType": "text/html", "body": childHtml})
      )
      await page->Browser.route(`${childOrigin}/custom/preview-bridge.js`, route =>
        route->Browser.fulfill({
          "contentType": "text/javascript",
          "body": platform === "Next.js" ? nextBridge : bridge,
        })
      )
      await page->Browser.route(`${childOrigin}/next-loader.js`, route =>
        route->Browser.fulfill({"contentType": "text/javascript", "body": nextLoader})
      )
      await page->Browser.route(
        `${childOrigin}/blog/wp-content/plugins/frontman/assets/preview-loader.js`,
        route => route->Browser.fulfill({"contentType": "text/javascript", "body": wpLoader}),
      )
      await page->Browser.route(
        `${childOrigin}/blog/wp-content/plugins/frontman/assets/bridge.js`,
        route => route->Browser.fulfill({"contentType": "text/javascript", "body": wpBridge}),
      )
      let errors = ref([])
      page->Browser.onPageError(error => {
        Console.error(error)
        errors := errors.contents->Array.concat([error])
      })
      await page->Browser.goto(parentOrigin)
      let result = page->Browser.locator("#test-result")
      await result->Browser.waitFor({"timeout": 15000})
      let resultText = await result->Browser.textContent
      switch resultText->Nullable.getOrThrow {
      | "passed" => ()
      | failure => JsError.throwWithMessage(`${engine} / ${platform}: ${failure}`)
      }
      switch errors.contents->Array.get(0) {
      | Some(error) => JsError.throwWithMessage(error->JsExn.message->Option.getOr("Browser error"))
      | None => ()
      }
      Console.log(
        `PASS ${engine} / ${platform}: cross-site context, navigation/reload/history, reactivation, task capture and failure fallback`,
      )
    }
    await launched->Browser.close
  } catch {
  | exn =>
    await launched->Browser.close
    throw(exn)
  }
}

let main = async () => {
  let engines = switch FrontmanBindings.Process.env->Dict.get("PAGE_CONTEXT_BROWSER") {
  | Some("chromium") => [("Chromium", Browser.launchChromium)]
  | Some("firefox") => [("Firefox", Browser.launchFirefox)]
  | Some("webkit") => [("WebKit", Browser.launchWebkit)]
  | None | Some("all") => [
      ("Chromium", Browser.launchChromium),
      ("Firefox", Browser.launchFirefox),
      ("WebKit", Browser.launchWebkit),
    ]
  | Some(value) => JsError.throwWithMessage(`Unknown PAGE_CONTEXT_BROWSER: ${value}`)
  }
  for index in 0 to engines->Array.length - 1 {
    let (engine, launch) = engines->Array.getUnsafe(index)
    await run(~engine, ~launch)
  }
}

let verify = async () => {
  try {
    await main()
  } catch {
  | exn =>
    Console.error(exn)
    FrontmanBindings.Process.exit(1)
  }
}

verify()->ignore
