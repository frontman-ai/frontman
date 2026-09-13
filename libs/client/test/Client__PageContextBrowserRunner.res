module Browser = FrontmanBindings.Playwright

let run = async () => {
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
  let bridge = await FrontmanBindings.Fs.Promises.readFile(
    "../frontman-preview-bridge/dist/bridge.js",
  )
  let launched = await Browser.launchFirefox({"headless": true})
  try {
    let parentOrigin = "http://127.0.0.1:43001"
    let childOrigin = "http://127.0.0.1:43002"
    let page = await launched->Browser.newPage({"colorScheme": #dark})
    await page->Browser.route(`${parentOrigin}/**`, route =>
      route->Browser.fulfill({
        "contentType": "text/html",
        "body": `<html data-child-origin="${childOrigin}"><title>Parent shell</title><body><script>window.__frontmanRuntime={framework:"vite",basePath:"frontman"}</script><script type="module" src="/test.js"></script></body></html>`,
      })
    )
    await page->Browser.route(`${parentOrigin}/test.js`, route =>
      route->Browser.fulfill({"contentType": "text/javascript", "body": parentBundle})
    )
    await page->Browser.route(`${childOrigin}/**`, route =>
      route->Browser.fulfill({
        "contentType": "text/html",
        "body": `<title>Cross-origin child</title><meta name="astro-view-transitions-enabled"><main data-astro-transition-persist="outer"><div id="page" data-astro-transition-persist="inner"><span>Child content</span></div></main><script src="/bridge.js" data-frontman-parent-origin="${parentOrigin}" data-frontman-channel="browser-test"></script>`,
      })
    )
    await page->Browser.route(`${childOrigin}/bridge.js`, route =>
      route->Browser.fulfill({"contentType": "text/javascript", "body": bridge})
    )
    let errors = ref([])
    page->Browser.onPageError(error => errors := errors.contents->Array.concat([error]))
    await page->Browser.goto(parentOrigin)
    let result = page->Browser.locator("#test-result")
    await result->Browser.waitFor({"timeout": 15000})
    let resultText = await result->Browser.textContent
    switch resultText->Nullable.getOrThrow {
    | "passed" => ()
    | failure =>
      errors.contents->Array.forEach(error => Console.error(error))
      JsError.throwWithMessage(failure)
    }
    switch errors.contents->Array.get(0) {
    | Some(error) => JsError.throwWithMessage(error->JsExn.message->Option.getOr("Browser error"))
    | None => ()
    }
    Console.log(
      "PASS: Firefox option-marker reproduction, child context, originating task, and no-context fallback",
    )
    await launched->Browser.close
  } catch {
  | exn =>
    await launched->Browser.close
    throw(exn)
  }
}

run()->ignore
