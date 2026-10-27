open Vitest

type browser
type page
type locator
type launcher
type route
type request
type response
type launchOptions = {headless: bool}
type execOptions = {encoding: string, stdio: array<string>}
type screenshotOptions = {path: string, fullPage: bool}
type mkdirOptions = {recursive: bool}
@module("playwright") external chromium: launcher = "chromium"
@send external launch: (launcher, launchOptions) => promise<browser> = "launch"
@send external newPage: browser => promise<page> = "newPage"
@send external close: browser => promise<unit> = "close"
@send external goto: (page, string) => promise<unit> = "goto"
@send external gotoResponse: (page, string) => promise<response> = "goto"
@send external responseStatus: response => int = "status"
@send external locator: (page, string) => locator = "locator"
@send external count: locator => promise<int> = "count"
@send external textContent: locator => promise<string> = "textContent"
@send external click: locator => promise<unit> = "click"
@send external fill: (locator, string) => promise<unit> = "fill"
@send external pageUrl: page => string = "url"
@send external route: (page, string, route => promise<unit>) => promise<unit> = "route"
@send external request: route => request = "request"
@send external requestUrl: request => string = "url"
@send external abort: route => promise<unit> = "abort"
@send external continueRequest: route => promise<unit> = "continue"
@send external screenshot: (page, screenshotOptions) => promise<unit> = "screenshot"
@module("node:fs") external mkdirSync: (string, mkdirOptions) => unit = "mkdirSync"
@module("node:process") external env: Dict.t<string> = "env"
@module("node:child_process")
external execFileSync: (string, array<string>, execOptions) => string = "execFileSync"

let url = env->Dict.get("FRONTMAN_ASTRA_URL")
testAsync("synthetic Astra storefront and registry mutations in Chromium", ~skip=url->Option.isNone, ~timeout=120000, async t => {
  let base = url->Option.getOrThrow
  let container = env->Dict.get("FRONTMAN_ASTRA_CONTAINER")->Option.getOrThrow
  let runtime = env->Dict.get("CONTAINER_RUNTIME")->Option.getOr("docker")
  let evidence = env->Dict.get("FRONTMAN_ASTRA_EVIDENCE_DIR")->Option.getOrThrow
  mkdirSync(evidence, {recursive: true})
  let mutate = (name, input) => {
    let receipt = execFileSync(runtime, ["exec", container, "php", "-d", "display_errors=stderr", "/tmp/AstraFixture.php", name, input], {encoding: "utf8", stdio: ["ignore", "pipe", "inherit"]})
    t->expect(receipt->String.includes(`"resultType":"complete"`))->Expect.toBe(true)
  }
  let visibility = value =>
    mutate("wp_set_widget_visibility", `{"widget_id":"woocommerce_recently_viewed_products-2","visibility":"${value}"}`)
  let mode = value =>
    mutate("wc_update_catalog_display", `{"name":"woocommerce_shop_page_display","value":"${value}","confirm":true}`)
  let browser = await chromium->launch({headless: true})
  let verify = async () => {
    let page = await browser->newPage
    let visit = path => page->goto(base ++ path)
    let history = () => page->locator(".widget_recently_viewed_products")
    let capture = name => page->screenshot({path: `${evidence}/${name}.png`, fullPage: true})
    await visit("/?pagename=synthetic-cart")
    t->expect(await history()->count)->Expect.toBe(0)
    await capture("empty-cart")
    await visit("/?product=amber")
    await visit("/?product=indigo")
    await page->locator("button.single_add_to_cart_button")->click
    await visit("/?pagename=synthetic-cart")
    t->expect((await history()->textContent)->String.includes("Synthetic Amber product"))->Expect.toBe(true)
    t->expect((await history()->textContent)->String.includes("Synthetic Indigo product"))->Expect.toBe(true)
    await capture("cart-history")
    visibility("exclude_checkout")
    await visit("/?pagename=synthetic-checkout")
    t->expect(await page->locator("form.checkout")->count)->Expect.toBe(1)
    t->expect(await history()->count)->Expect.toBe(0)
    await capture("checkout-hidden")
    await visit("/?pagename=synthetic-cart")
    t->expect(await history()->count)->Expect.toBe(1)
    visibility("all")
    await visit("/?pagename=synthetic-checkout")
    t->expect(await history()->count)->Expect.toBe(1)
    await capture("checkout-reset")
    for index in 0 to 2 {
      let value = ["", "subcategories", "both"]->Array.get(index)->Option.getOrThrow
      mode(value)
      await visit("/?post_type=product")
      t->expect((await page->locator("body")->textContent)->String.includes("Synthetic shop introduction."))->Expect.toBe(true)
      t->expect(await page->locator("ul.products li.product:not(.product-category)")->count > 0)->Expect.toBe(value != "subcategories")
      t->expect(await page->locator("ul.products li.product-category")->count > 0)->Expect.toBe(value != "")
      await capture(`catalog-${index->Int.toString}`)
    }
    mode("")
    // This is a fixture variation, not a Frontman tool or a customer diagnosis.
    mutate("fixture_banner", "on")
    await visit("/?post_type=product")
    t->expect((await page->locator("body")->textContent)->String.includes("Synthetic shop introduction."))->Expect.toBe(false)
    t->expect(await page->locator("ul.products li.product:not(.product-category)")->count > 0)->Expect.toBe(true)
    await capture("astra-layout-1-intro-hidden")
    mutate("fixture_banner", "off")
    await visit("/?post_type=product")
    t->expect((await page->locator("body")->textContent)->String.includes("Synthetic shop introduction."))->Expect.toBe(true)
  }
  let cleanup = async () => {
    visibility("all")
    mode("")
    await browser->close
  }
  try {
    await verify()
    let adminPage = await browser->newPage
    // Safety boundary, not a mocked dependency: no hosted client/API traffic.
    await adminPage->route("**/*", async route => {
      switch route->request->requestUrl->String.startsWith(base ++ "/") {
      | true => await route->continueRequest
      | false => await route->abort
      }
    })
    let denied = await adminPage->gotoResponse(base ++ "/frontman/tools")
    t->expect(denied->responseStatus)->Expect.toBe(401)
    await adminPage->goto(base ++ "/frontman")
    t->expect(adminPage->pageUrl->String.includes("/wp-login.php?redirect_to="))->Expect.toBe(true)
    t->expect(await adminPage->locator("#loginform")->count)->Expect.toBe(1)
    let password = execFileSync(runtime, ["exec", container, "cat", "/tmp/frontman-fixture-admin-password"], {encoding: "utf8", stdio: ["ignore", "pipe", "inherit"]})
    await adminPage->locator("#user_login")->fill("admin")
    try {
      await adminPage->locator("#user_pass")->fill(password)
    } catch {
    | _ => failwith("Could not fill private WordPress credential; details redacted.")
    }
    await adminPage->locator("#wp-submit")->click
    let authorized = await adminPage->gotoResponse(base ++ "/frontman")
    t->expect(authorized->responseStatus)->Expect.toBe(200)
    t->expect(await adminPage->locator("#frontman-runtime-config")->count)->Expect.toBe(1)
    t->expect(await adminPage->locator("#root")->count)->Expect.toBe(1)
    let toolsResponse = await adminPage->gotoResponse(base ++ "/frontman/tools")
    t->expect(toolsResponse->responseStatus)->Expect.toBe(200)
    let discovery = await adminPage->locator("body")->textContent
    t->expect(discovery->String.includes("wc_get_catalog_display"))->Expect.toBe(true)
    t->expect(discovery->String.includes("wp_set_widget_visibility"))->Expect.toBe(true)
  } catch {
  | error => {
      await browser->close
      throw(error)
    }
  }
  await cleanup()
})
