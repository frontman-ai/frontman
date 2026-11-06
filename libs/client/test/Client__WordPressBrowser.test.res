open Vitest
open FrontmanBindings
open FrontmanBindings.Bindings__Test__Playwright

let url = Process.env->Dict.get("FRONTMAN_ASTRA_URL")
testAsync(
  "synthetic Astra storefront and registry mutations in Chromium",
  ~skip=url->Option.isNone,
  ~timeout=120000,
  async t => {
    let base = url->Option.getOrThrow
    let container = Process.env->Dict.get("FRONTMAN_ASTRA_CONTAINER")->Option.getOrThrow
    let runtime = Process.env->Dict.get("CONTAINER_RUNTIME")->Option.getOr("docker")
    let evidence = Process.env->Dict.get("FRONTMAN_ASTRA_EVIDENCE_DIR")->Option.getOrThrow
    let _ = await Fs.Promises.mkdir(evidence, {recursive: true})
    let mutate = (name, input) => {
      let receipt = ChildProcess.execFileSync(
        runtime,
        [
          "exec",
          container,
          "php",
          "-d",
          "display_errors=stderr",
          "/tmp/AstraFixture.php",
          name,
          input,
        ],
        {encoding: "utf8", stdio: ["ignore", "pipe", "inherit"]},
      )
      t->expect(receipt->String.includes(`"resultType":"complete"`))->Expect.toBe(true)
    }
    let visibility = value =>
      mutate(
        "wp_set_widget_visibility",
        `{"widget_id":"woocommerce_recently_viewed_products-2","visibility":"${value}"}`,
      )
    let mode = value =>
      mutate(
        "wc_update_catalog_display",
        `{"name":"woocommerce_shop_page_display","value":"${value}","confirm":true}`,
      )
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
      t
      ->expect((await history()->textContent)->String.includes("Synthetic Amber product"))
      ->Expect.toBe(true)
      t
      ->expect((await history()->textContent)->String.includes("Synthetic Indigo product"))
      ->Expect.toBe(true)
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
        t
        ->expect(
          (await page->locator("body")->textContent)->String.includes(
            "Synthetic shop introduction.",
          ),
        )
        ->Expect.toBe(true)
        t
        ->expect((await page->locator("ul.products li.product:not(.product-category)")->count) > 0)
        ->Expect.toBe(value != "subcategories")
        t
        ->expect((await page->locator("ul.products li.product-category")->count) > 0)
        ->Expect.toBe(value != "")
        await capture(`catalog-${index->Int.toString}`)
      }
      mode("")
      mutate("fixture_banner", "on")
      await visit("/?post_type=product")
      t
      ->expect(
        (await page->locator("body")->textContent)->String.includes("Synthetic shop introduction."),
      )
      ->Expect.toBe(false)
      t
      ->expect((await page->locator("ul.products li.product:not(.product-category)")->count) > 0)
      ->Expect.toBe(true)
      await capture("astra-layout-1-intro-hidden")
      mutate("fixture_banner", "off")
      await visit("/?post_type=product")
      t
      ->expect(
        (await page->locator("body")->textContent)->String.includes("Synthetic shop introduction."),
      )
      ->Expect.toBe(true)
      let adminPage = await browser->newPage
      await adminPage->route("**/*", async route => {
        switch route->request->requestUrl->String.startsWith(base ++ "/") {
        | true => await route->continueRequest
        | false => await route->abort
        }
      })
      let denied = await adminPage->gotoResponse(base ++ "/frontman/tools")
      t->expect(denied->responseStatus)->Expect.toBe(401)
      await adminPage->goto(base ++ "/frontman")
      t
      ->expect(adminPage->pageUrl->String.includes("/wp-login.php?redirect_to="))
      ->Expect.toBe(true)
      t->expect(await adminPage->locator("#loginform")->count)->Expect.toBe(1)
      let password = ChildProcess.execFileSync(
        runtime,
        ["exec", container, "cat", "/tmp/frontman-fixture-admin-password"],
        {encoding: "utf8", stdio: ["ignore", "pipe", "inherit"]},
      )
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
      visibility("all")
      mode("")
    }
    await verify()->Bindings__Test__Promise.finallyAsync(() => browser->close)
  },
)

@schema
type clientFixture = {origin: string, api: string, token: string, password: string}
@schema
type approval = {catalog_url: string, username: string, password: string}
let setToken: string => unit = %raw(`token => localStorage.setItem("frontman:embeddedClientToken", token)`)
let directory = Process.env->Dict.get("FRONTMAN_WP_RUNTIME_DIRECTORY")
testAsync(
  "real client approves, restores and changes WordPress access",
  ~skip=directory->Option.isNone,
  ~timeout=120000,
  async t => {
    let fixture = try {
      Fs.readFileSync(directory->Option.getOrThrow ++ "/client.json")
      ->JSON.parseOrThrow
      ->S.parseOrThrow(~to=clientFixtureSchema)
    } catch {
    | _ => failwith("Could not read private WordPress client fixture")
    }
    let browser = await chromium->launch({
      headless: true,
      args: [
        `--ignore-certificate-errors-spki-list=${Process.env
          ->Dict.get("FRONTMAN_WP_RUNTIME_SPKI")
          ->Option.getOrThrow}`,
      ],
    })
    let verify = async () => {
      let page = await browser->newPage(~options={serviceWorkers: "block"})
      let allowed = (url, origin) => url == origin || url->String.startsWith(origin ++ "/")
      await page->route("**/*", async route => {
        if (
          allowed(route->request->requestUrl, fixture.origin) ||
          allowed(route->request->requestUrl, fixture.api)
        ) {
          await route->continueRequest
        } else {
          await route->abort
        }
      })
      await page->routeWebSocket("**/*", socket => {
        if allowed(socket->socketUrl, fixture.api->String.replace("https:", "wss:")) {
          socket->connectToServer
        } else {
          socket->closeSocket
        }
      })
      await page->goto(fixture.origin ++ "/wp-login.php")
      await page->locator("#user_login")->fill("admin")
      try {
        await page->locator("#user_pass")->fill(fixture.password)
        await page->evaluate(setToken, fixture.token)
      } catch {
      | _ => failwith("Could not initialize private WordPress browser credentials")
      }
      await page->locator("#wp-submit")->click
      await page->goto(fixture.origin ++ "/index.php/frontman")
      await page->locator("#frontman-warning-dismiss")->click
      let settings = async () => {
        await page
        ->locator("fieldset.contents:not([disabled])")
        ->waitFor(~options={state: "attached"})
        let setup = page->locator("button:has-text('Connect AI provider')")
        if await setup->isVisible {
          await setup->click
        } else {
          await page->locator("[aria-label='Settings']")->click
        }
        await page->locator("button:has-text('General')")->click
      }
      await settings()
      let response = page->waitForResponse("**/frontman/mcp/connect")
      await page->locator("button:has-text('Enable MCP and connect')")->click
      let credential = try {
        (await (await response)->responseJson)->S.parseOrThrow(~to=approvalSchema)
      } catch {
      | _ => failwith("Invalid private WordPress approval response")
      }
      t->expect(WebAPI.URL.make(~url=credential.catalog_url).origin)->Expect.toBe(fixture.origin)
      let linked = page->locator("text=This site is linked to your Frontman account.")
      await linked->waitFor
      await page->reload
      await settings()
      await linked->waitFor
      for index in 0 to 2 {
        let enabled = index != 1
        if index > 0 {
          await page->locator("label:has-text('MCP access for this site') input")->click
        }
        await page->locator(enabled ? "text=MCP enabled" : "text=MCP disabled")->waitFor
        let response = await WebAPI.Fetch.fetch(
          credential.catalog_url,
          ~init={
            headers: WebAPI.HeadersInit.fromDict(
              dict{
                "Authorization": "Basic " ++
                WebAPI.DomGlobal.btoa(credential.username ++ ":" ++ credential.password),
              },
            ),
            credentials: Omit,
            redirect: Error,
            signal: Null.make(WebAPI.AbortSignal.timeout(30000)),
          },
        )
        t->expect(response.status)->Expect.toBe(enabled ? 200 : 403)
      }
      await page->context->clearCookies
      let denied = page->waitForResponse("**/frontman/mcp/disable")
      await page->locator("label:has-text('MCP access for this site') input")->click
      t->expect((await denied)->responseStatus)->Expect.toBe(401)
      let login = page->locator("a:has-text('Log in to WordPress (new tab)')")
      await login->waitFor
      let native = await page
      ->locator("#frontman-runtime-config")
      ->getAttribute("data-wordpress-login-url")
      t
      ->expect((await login->getAttribute("href"))->Null.toOption->Option.getOrThrow)
      ->Expect.toBe(native->Null.toOption->Option.getOrThrow)
    }
    await verify()->Bindings__Test__Promise.finallyAsync(() => browser->close)
  },
)
