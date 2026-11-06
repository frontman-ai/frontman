open Vitest

type browser
type context
type page
type locator
type launcher
type route
type request
type webSocketRoute
type webSocket
type response
type launchOptions = {@live headless: bool, @live args: array<string>}
type contextOptions = {@live serviceWorkers: string}
type waitOptions = {@live state: string}

@module("playwright") external chromium: launcher = "chromium"
@module("node:process") external env: Dict.t<string> = "env"
@module("node:fs") external readFileSync: (string, string) => string = "readFileSync"
@send external launch: (launcher, launchOptions) => promise<browser> = "launch"
@send external newContext: (browser, contextOptions) => promise<context> = "newContext"
@send external newPage: context => promise<page> = "newPage"
@send external setDefaultTimeout: (context, int) => unit = "setDefaultTimeout"
@send external setDefaultNavigationTimeout: (context, int) => unit = "setDefaultNavigationTimeout"
@send external close: browser => promise<unit> = "close"
@send external goto: (page, string) => promise<unit> = "goto"
@send external reload: page => promise<unit> = "reload"
@send external locator: (page, string) => locator = "locator"
@send external click: locator => promise<unit> = "click"
@send external fill: (locator, string) => promise<unit> = "fill"
@send external press: (locator, string) => promise<unit> = "press"
@send external getAttribute: (locator, string) => promise<Null.t<string>> = "getAttribute"
@send external isChecked: locator => promise<bool> = "isChecked"
@send external isVisible: locator => promise<bool> = "isVisible"
@send external count: locator => promise<int> = "count"
@send external waitFor: locator => promise<unit> = "waitFor"
@send external waitForState: (locator, waitOptions) => promise<unit> = "waitFor"
@send external route: (context, string, route => promise<unit>) => promise<unit> = "route"
@send external request: route => request = "request"
@send external requestUrl: request => string = "url"
@send external responseUrl: response => string = "url"
@send external responseStatus: response => int = "status"
@send external waitForResponse: (page, string) => promise<response> = "waitForResponse"
@send external abort: route => promise<unit> = "abort"
@send external continueRequest: route => promise<unit> = "continue"
@send external routeWebSocket: (context, string, webSocketRoute => unit) => promise<unit> = "routeWebSocket"
@send external socketUrl: webSocketRoute => string = "url"
@send external connectToServer: webSocketRoute => unit = "connectToServer"
@send external closeSocket: webSocketRoute => unit = "close"
@send external evaluate: (page, string => unit, string) => promise<unit> = "evaluate"
@send external onSocket: (page, string, webSocket => unit) => unit = "on"
@send external onSocketEvent: (webSocket, string, unit => unit) => unit = "on"
@send external onResponse: (page, string, response => unit) => unit = "on"
@send external onPageError: (page, string, 'a => unit) => unit = "on"

let setToken: string => unit = %raw(`token => localStorage.setItem("frontman:embeddedClientToken", token)`)
let url = env->Dict.get("FRONTMAN_WP_BROWSER_URL")

testAsync("real WordPress connection survives reload and MCP access changes", ~skip=url->Option.isNone, ~timeout=120000, async t => {
  let wp = url->Option.getOrThrow
  let phoenix = env->Dict.get("FRONTMAN_WP_BROWSER_PHOENIX_URL")->Option.getOrThrow
  let password = readFileSync(env->Dict.get("FRONTMAN_WP_BROWSER_PASSWORD")->Option.getOrThrow, "utf8")->String.trim
  let token = readFileSync(env->Dict.get("FRONTMAN_WP_BROWSER_TOKEN")->Option.getOrThrow, "utf8")->String.trim
  let secondToken = readFileSync(env->Dict.get("FRONTMAN_WP_BROWSER_TOKEN_SECOND")->Option.getOrThrow, "utf8")->String.trim
  let spki = env->Dict.get("FRONTMAN_WP_BROWSER_SPKI")->Option.getOrThrow
  let proxyPort = env->Dict.get("FRONTMAN_WP_BROWSER_PROXY_PORT")->Option.getOrThrow
  let blockedPort = env->Dict.get("FRONTMAN_WP_BROWSER_BLOCKED_PORT")->Option.getOrThrow
  let socketOrigin = phoenix->String.replace("https://", "wss://")
  let allowed = (value, base) => value == base || value->String.startsWith(base ++ "/")
  let browser = await chromium->launch({
    headless: true,
    args: [
      `--ignore-certificate-errors-spki-list=${spki}`,
      `--proxy-server=http://127.0.0.1:${proxyPort}`,
      "--proxy-bypass-list=<-loopback>",
      "--disable-quic",
    ],
  })
  let phase = ref("create browser context")
  let allowedSockets = ref(0)
  let blockedSockets = ref(0)
  let observedSockets = ref(0)
  let socketCloses = ref(0)
  let socketErrors = ref(0)
  let bundleOk = ref(0)
  let bundleFailed = ref(0)
  let pageErrors = ref(0)
  let mark = value => {
    phase := value
    Console.log(`WordPress browser: ${value}`)
  }
  try {
    let context = await browser->newContext({serviceWorkers: "block"})
    context->setDefaultTimeout(15000)
    context->setDefaultNavigationTimeout(20000)
    mark("configure network allowlist")
    await context->route("**/*", async route => {
      let target = route->request->requestUrl
      if allowed(target, wp) || allowed(target, phoenix) {
        await route->continueRequest
      } else {
        await route->abort
      }
    })
    await context->routeWebSocket("**/*", socket => {
      if allowed(socket->socketUrl, socketOrigin) {
        allowedSockets := allowedSockets.contents + 1
        socket->connectToServer
      } else {
        blockedSockets := blockedSockets.contents + 1
        socket->closeSocket
      }
    })
    let redirectPage = await context->newPage
    mark("reject redirect outside the fixture")
    let redirectResponse = redirectPage->waitForResponse("**/frontman-browser/redirect.php?*")
    let rejected = try {
      await redirectPage->goto(`${wp}/frontman-browser/redirect.php?port=${blockedPort}`)
      false
    } catch {
    | _ => true
    }
    t->expect((await redirectResponse)->responseStatus)->Expect.toBe(307)
    t->expect(rejected)->Expect.toBe(true)
    let page = await context->newPage
    page->onResponse("response", response => {
      if response->responseUrl->String.split("?")->Array.get(0)->Option.getOr("")->String.endsWith("/frontman-browser/frontman.es.js") {
        if response->responseStatus == 200 {
          bundleOk := bundleOk.contents + 1
        } else {
          bundleFailed := bundleFailed.contents + 1
        }
      }
    })
    page->onPageError("pageerror", _ => pageErrors := pageErrors.contents + 1)
    page->onSocket("websocket", socket => {
      observedSockets := observedSockets.contents + 1
      socket->onSocketEvent("close", () => socketCloses := socketCloses.contents + 1)
      socket->onSocketEvent("socketerror", () => socketErrors := socketErrors.contents + 1)
    })
    mark("open WordPress login")
    await page->goto(wp ++ "/wp-login.php")
    await page->locator("#user_login")->fill("admin")
    try {
      await page->locator("#user_pass")->fill(password)
      await page->evaluate(setToken, token)
    } catch {
    | _ => failwith("Could not initialize private browser credentials; details redacted.")
    }
    mark("sign in to WordPress")
    await page->locator("#wp-submit")->click
    await page->goto(wp ++ "/index.php/frontman")
    mark("dismiss WordPress warning")
    await page->locator("#frontman-warning-dismiss")->click
    let openSettings = async () => {
      let setup = page->locator("button:has-text('Connect AI provider')")
      await page->locator("[aria-label='Settings']")->waitFor
      if await setup->isVisible {
        await setup->click
      } else {
        await page->locator("[aria-label='Settings']")->click
      }
      await page->locator("button:has-text('General')")->click
    }
    let linked = () => page->locator("text=This site is linked to your Frontman account.")
    let enabled = () => page->locator("text=MCP enabled")
    let disabled = () => page->locator("text=MCP disabled")
    let access = () => page->locator("label:has-text('MCP access for this site') input")
    mark("wait for ACP and open settings")
    try {
      await page->locator("fieldset.contents:not([disabled])")->waitForState({state: "attached"})
      await openSettings()
    } catch {
    | _ => {
        let roots = await page->locator("#root")->count
        let settings = await page->locator("[aria-label='Settings']")->count
        let fieldsets = await page->locator("fieldset.contents")->count
        let ready = await page->locator("fieldset.contents:not([disabled])")->count
        let scripts = await page->locator("script")->count
        Console.log(`WordPress browser structure: root=${roots->Int.toString} settings=${settings->Int.toString} fieldsets=${fieldsets->Int.toString} enabled=${ready->Int.toString}; sockets allowed=${allowedSockets.contents->Int.toString} blocked=${blockedSockets.contents->Int.toString} observed=${observedSockets.contents->Int.toString} closed=${socketCloses.contents->Int.toString} errors=${socketErrors.contents->Int.toString}`)
        Console.log(`WordPress browser bundle: scripts=${scripts->Int.toString} responses200=${bundleOk.contents->Int.toString} otherResponses=${bundleFailed.contents->Int.toString} pageErrors=${pageErrors.contents->Int.toString}`)
        failwith("ACP readiness or settings unavailable")
      }
    }
    mark("approve unlinked connection")
    await page->locator("text=This enables MCP access and creates a native Application Password")->waitFor
    await page->locator("text=Registered tools can change and delete site content.")->waitFor
    let nativeSettings = page->locator("a[aria-label='Open WordPress plugin settings (opens in a new tab)']")
    let href = await nativeSettings->getAttribute("href")
    let target = await nativeSettings->getAttribute("target")
    let rel = await nativeSettings->getAttribute("rel")
    t->expect(href->Null.toOption)->Expect.toBe(Some(wp ++ "/wp-admin/options-general.php?page=frontman-diagnostics"))
    t->expect(target->Null.toOption)->Expect.toBe(Some("_blank"))
    t->expect(rel->Null.toOption)->Expect.toBe(Some("noopener noreferrer"))
    await page->locator("button:has-text('Enable MCP and connect')")->click
    await linked()->waitFor
    await enabled()->waitFor
    await page->locator("text=A saved link does not confirm that its credentials are valid.")->waitFor
    await page->locator("text=This controls MCP access for the entire site.")->waitFor
    await page->locator("text=Disabling MCP does not revoke Application Passwords")->waitFor
    t->expect(await page->locator("button:has-text('Enable MCP and connect')")->count)->Expect.toBe(0)
    t->expect(await access()->isChecked)->Expect.toBe(true)
    mark("verify linked after reload")
    await page->reload
    await openSettings()
    await linked()->waitFor
    await enabled()->waitFor
    t->expect(await access()->isChecked)->Expect.toBe(true)
    mark("disable MCP access")
    await access()->click
    await disabled()->waitFor
    t->expect(await access()->isChecked)->Expect.toBe(false)
    await page->locator("text=Access is disabled. Your saved connection is retained.")->waitFor
    t->expect(await page->locator("button:has-text('Enable MCP and connect')")->count)->Expect.toBe(0)
    mark("verify disabled link after reload")
    await page->reload
    await openSettings()
    await linked()->waitFor
    await disabled()->waitFor
    t->expect(await access()->isChecked)->Expect.toBe(false)
    mark("re-enable MCP access")
    await access()->click
    await enabled()->waitFor
    t->expect(await access()->isChecked)->Expect.toBe(true)
    mark("verify re-enabled link after reload")
    await page->reload
    await openSettings()
    await linked()->waitFor
    await enabled()->waitFor
    t->expect(await access()->isChecked)->Expect.toBe(true)
    mark("expire WordPress session in another tab")
    let admin = await context->newPage
    await admin->goto(wp ++ "/wp-admin/")
    let logout = await admin->locator("#wp-admin-bar-logout a")->getAttribute("href")
    await admin->goto(logout->Null.toOption->Option.getOrThrow)
    await admin->locator("#loginform")->waitFor
    await page->locator("body")->press("Escape")
    await openSettings()
    await page->locator("text=Could not check WordPress access. Sign in to WordPress and reload Frontman.")->waitFor
    t->expect(await page->locator("button:has-text('Enable MCP and connect')")->count)->Expect.toBe(0)
    let retry = page->waitForResponse("**/frontman/mcp/status")
    await page->locator("button:has-text('Check again')")->click
    t->expect((await retry)->responseStatus)->Expect.toBe(401)
    await page->locator("text=Could not check WordPress access. Sign in to WordPress and reload Frontman.")->waitFor
    mark("restore WordPress session and retry")
    await admin->locator("#user_login")->fill("admin")
    try {
      await admin->locator("#user_pass")->fill(password)
    } catch {
    | _ => failwith("Could not initialize private browser credentials; details redacted.")
    }
    await admin->locator("#wp-submit")->click
    await page->locator("button:has-text('Check again')")->click
    await linked()->waitFor
    await enabled()->waitFor
    t->expect(await access()->isChecked)->Expect.toBe(true)
    mark("switch to an unlinked Frontman account")
    try {
      await page->evaluate(setToken, secondToken)
    } catch {
    | _ => failwith("Could not initialize private browser credentials; details redacted.")
    }
    await page->reload
    await openSettings()
    await page->locator("text=This enables MCP access and creates a native Application Password")->waitFor
    mark("approve with invalid Frontman session")
    await page->evaluate(setToken, "invalid-browser-test-token")
    await page->locator("button:has-text('Enable MCP and connect')")->click
    await page->locator("text=Your Frontman session expired. Sign in again.")->waitFor
    await page->locator("text=A connection attempt may have created a")->waitFor
    await page->locator("text=Remove the \"Frontman MCP\" Application Password in your WordPress profile before retrying.")->waitFor
  } catch {
  | _ => {
      await browser->close
      failwith(`WordPress browser failed during: ${phase.contents}. Details redacted.`)
    }
  }
  await browser->close
})
