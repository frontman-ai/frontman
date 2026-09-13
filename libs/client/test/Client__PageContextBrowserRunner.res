module Http = FrontmanBindings.NodeHttp
module Browser = FrontmanBindings.Playwright

let run = async () => {
  let bundles = await FrontmanBindings.Vite.buildLibrary({
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
  let bridge = await FrontmanBindings.Fs.Promises.readFile(
    "../frontman-preview-bridge/dist/bridge.js",
  )
  let servers = ref([])
  let browser = ref(None)
  let serve = async handler => {
    let server = Http.createServer(handler)
    servers := servers.contents->Array.concat([server])
    await Promise.make((resolve, _) => server->Http.listen(0, "127.0.0.1", resolve))
    let port = switch server->Http.address->Nullable.getOrThrow {
    | Tcp({port}) => port
    | Pipe(_) => JsError.throwWithMessage("Expected a TCP server address")
    }
    `http://127.0.0.1:${port->Int.toString}`
  }
  let cleanup = async () => {
    switch browser.contents {
    | Some(browser) => await browser->Browser.close
    | None => ()
    }
    let _ = await servers.contents
    ->Array.map(server =>
      Promise.make((resolve, reject) =>
        server->Http.close(
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
      let url = req->Http.url
      res->Http.setHeader("Content-Type", url === "/test.js" ? "text/javascript" : "text/html")
      res->Http.endWithData(
        switch url {
        | "/test.js" => parentBundle
        | _ =>
          `<html data-child-origin="${childOrigin.contents}"><title>Parent shell</title><body><script>window.__frontmanRuntime={framework:"vite",basePath:"frontman"}</script><script type="module" src="/test.js"></script></body></html>`
        },
      )
    })
    childOrigin :=
      (
        await serve((req, res) => {
          let url = req->Http.url
          res->Http.setHeader(
            "Content-Type",
            url === "/bridge.js" ? "text/javascript" : "text/html",
          )
          res->Http.endWithData(
            switch url {
            | "/bridge.js" => bridge
            | _ =>
              `<title>Cross-origin child</title><meta name="astro-view-transitions-enabled"><main data-astro-transition-persist="outer"><div id="page" data-astro-transition-persist="inner"><span>${"x"->String.repeat(
                  15001,
                )}</span></div></main><script src="/bridge.js" data-frontman-parent-origin="${parentOrigin}" data-frontman-channel="browser-test"></script>`
            },
          )
        })
      )

    let launched = await Browser.launchFirefox({"headless": true})
    browser := Some(launched)
    let page = await launched->Browser.newPage({"colorScheme": #dark})
    let errors = ref([])
    page->Browser.onPageError(error => errors := errors.contents->Array.concat([error]))
    await page->Browser.goto(parentOrigin)
    let result = page->Browser.locator("#test-result")
    await result->Browser.waitFor({"timeout": 15000})
    let resultText = await result->Browser.textContent
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
