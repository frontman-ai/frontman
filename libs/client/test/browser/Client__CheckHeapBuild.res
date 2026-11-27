open FrontmanBindings.Bindings__Test__Playwright

@val external moduleUrl: string = "import.meta.url"

let check = async browser => {
  let page = await browser->newPage
  let fixture = WebAPI.URL.make(~url="./heap-build.html", ~base=moduleUrl)
  await page->goto(fixture.href)
  let scripts = page->locator(`script[src="https://cdn.us.heap-api.com/config/heap-browser-test/heap_config.js"]`)
  if await scripts->count != 1 {
    JsError.throwWithMessage("The standalone client did not initialize the configured Heap environment")
  }
}

let run = async () => {
  let browser = await chromium->launch({headless: true, args: ["--allow-file-access-from-files"]})
  try {
    await check(browser)
  } catch {
  | exn =>
    await browser->close
    throw(exn)
  }
  await browser->close
}

await run()
