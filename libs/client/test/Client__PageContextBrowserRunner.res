open Test__BrowserTools

let run = async () => {
  let bundles = await build({
    "configFile": false,
    "build": {
      "lib": {"entry": "test/Client__PageContextBrowserMain.res.mjs", "formats": ["es"]},
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
  let bridge = await readFile("../frontman-preview-bridge/dist/bridge.js")
  let servers = ref([])
  let browser = ref(None)
  let serve = async handler => {
    let server = createServer(handler)
    servers := servers.contents->Array.concat([server])
    await Promise.make((resolve, _) => server->listen(0, "127.0.0.1", resolve))
    let address = server->address
    `http://127.0.0.1:${address.port->Int.toString}`
  }
  let cleanup = async () => {
    switch browser.contents {
    | Some(browser) => await browser->closeBrowser
    | None => ()
    }
    let _ = await servers.contents
    ->Array.map(server =>
      Promise.make((resolve, reject) =>
        server->closeServer(
          error =>
            switch error {
            | Value(error) => reject(error)
            | Null | Undefined => resolve()
            },
        )
      )
    )
    ->Promise.all
  }
  try {
    let childOrigin = ref("")
    let parentOrigin = await serve((req, res) => {
      res->setHeader("Content-Type", req.url === "/test.js" ? "text/javascript" : "text/html")
      res->endResponse(
        switch req.url {
        | "/test.js" => parentBundle
        | _ =>
          `<html data-child-origin="${childOrigin.contents}"><title>Parent shell</title><body><script>window.__frontmanRuntime={framework:"vite",basePath:"frontman"}</script><script type="module" src="/test.js"></script></body></html>`
        },
      )
    })
    childOrigin :=
      (
        await serve((req, res) => {
          res->setHeader("Content-Type", req.url === "/bridge.js" ? "text/javascript" : "text/html")
          res->endResponse(
            switch req.url {
            | "/bridge.js" => bridge
            | _ =>
              `<title>Cross-origin child</title><meta name="astro-view-transitions-enabled"><main data-astro-transition-persist="outer"><div id="page" data-astro-transition-persist="inner"><span>${"x"->String.repeat(
                  15001,
                )}</span></div></main><script src="/bridge.js" data-frontman-parent-origin="${parentOrigin}" data-frontman-channel="browser-test"></script>`
            },
          )
        })
      )

    let launched = await launch({"headless": true})
    browser := Some(launched)
    let page = await launched->newPage({"colorScheme": "dark"})
    let errors = ref([])
    page->onError(error => errors := errors.contents->Array.concat([error]))
    await page->goto(parentOrigin)
    let result = page->locator("#test-result")
    await result->waitFor({"timeout": 15000})
    let resultText = await result->textContent
    switch resultText->Nullable.getOrThrow {
    | "passed" => ()
    | failure => JsError.throwWithMessage(failure)
    }
    switch errors.contents->Array.get(0) {
    | Some(error) => JsError.throwWithMessage(error->JsExn.message->Option.getOr("Browser error"))
    | None => ()
    }
    Console.log(
      "PASS: Firefox cross-origin bootstrap, typed context, task isolation, and disconnected fallback",
    )
    await cleanup()
  } catch {
  | exn =>
    await cleanup()
    throw(exn)
  }
}

run()->ignore
