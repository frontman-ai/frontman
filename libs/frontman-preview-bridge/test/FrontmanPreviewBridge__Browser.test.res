open Vitest
module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview

type browser
type page
type route
type launchOptions = {headless: bool}
type routeResponse = {contentType: string, body: string}

@module("playwright") @scope("chromium")
external launch: launchOptions => promise<browser> = "launch"
@send external newPage: browser => promise<page> = "newPage"
@send external close: browser => promise<unit> = "close"
@send external intercept: (page, string, route => promise<unit>) => promise<unit> = "route"
@send external fulfill: (route, routeResponse) => promise<unit> = "fulfill"
@send external goto: (page, string) => promise<unit> = "goto"
@send external on: (page, string, JsError.t => unit) => unit = "on"
@send external evaluate: (page, 'a => promise<'b>, 'a) => promise<'b> = "evaluate"
@module("node:fs/promises")
external readFile: (string, string) => promise<string> = "readFile"

@scope("FrontmanPreviewParent") @val
external requestPageContext: unit => promise<Preview.pageContext> = "requestPageContext"

describe("built bridge in Chromium", _ => {
  testAsync(
    "leaves legacy frames inert and answers page context in configured frames",
    ~timeout=15_000,
    async t => {
      let bundle = await readFile("dist/bridge.js", "utf8")
      let parentBundle = await readFile("test/dist/parent.js", "utf8")
      let browser = await launch({headless: true})
      try {
        let page = await newPage(browser)
        let errors = []
        on(page, "pageerror", error => errors->Array.push(error))
        await intercept(
          page,
          "https://site.test/child",
          route =>
            fulfill(
              route,
              {
                contentType: "text/html",
                body: `<title>Article</title><script>${bundle}</script>`,
              },
            ),
        )
        await intercept(
          page,
          "https://parent.test/",
          route =>
            fulfill(
              route,
              {
                contentType: "text/html",
                body: "<iframe src=\"https://site.test/child\"></iframe>",
              },
            ),
        )
        await goto(page, "https://parent.test/")
        t->expect(errors)->Expect.toEqual([])
        let name = ref("")
        await intercept(
          page,
          "https://site.test/",
          route =>
            fulfill(
              route,
              {
                contentType: "text/html",
                body: `<iframe name="${name.contents}" src="/child" style="width:800px;height:600px;border:0"></iframe><script>${parentBundle}</script>`,
              },
            ),
        )
        await goto(page, "https://site.test/")
        t->expect(errors)->Expect.toEqual([])
        name := "frontman:https://site.test/?channel=task"
        await goto(page, "https://site.test/")
        t->expect(errors)->Expect.toEqual([])
        let context = await evaluate(page, () => requestPageContext(), ())
        t->expect(context.url)->Expect.toBe("https://site.test/child")
        t->expect(context.title)->Expect.toBe("Article")
        t->expect(context.viewportWidth)->Expect.toBe(800)
        t->expect(context.viewportHeight)->Expect.toBe(600)
        t->expect(context.astroClientRouting)->Expect.toBe(Disabled)
        t->expect(errors)->Expect.toEqual([])
      } catch {
      | exn => {
          await close(browser)
          throw(exn)
        }
      }
      await close(browser)
    },
  )
})
