open Vitest
module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview

type browser
type page
type route
type port
type frame
type channel = {port1: port, port2: port}
type reply = {@as("TAG") tag: string, value: Preview.pageContext, message: string}
type portEvent = {data: {kind: string, payload: reply}}
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

@val external document: WebAPI.DomTypes.document = "document"
@send external querySelector: (WebAPI.DomTypes.document, string) => frame = "querySelector"
@get external contentWindow: frame => WebAPI.DomTypes.window = "contentWindow"
@new external makeChannel: unit => channel = "MessageChannel"
@new external makePromise: (('a => unit, JsError.t => unit) => unit) => promise<'a> = "Promise"
@new external error: string => JsError.t = "Error"
@set external onMessage: (port, portEvent => unit) => unit = "onmessage"
@send external closePort: port => unit = "close"
@send external postPort: (port, 'a) => unit = "postMessage"
@send external postWindow: (WebAPI.DomTypes.window, 'a, string, array<port>) => unit = "postMessage"
@val external setTimer: (unit => unit, int) => int = "setTimeout"
@val external clearTimer: int => unit = "clearTimeout"

let requestPageContext = message =>
  makePromise((resolve, reject) => {
    let channel = makeChannel()
    let stage = ref("handshake")
    let timeout = setTimer(() => {
      closePort(channel.port1)
      reject(error(`Bridge ${stage.contents} timed out`))
    }, 2000)
    onMessage(channel.port1, event => {
      switch event.data.kind {
      | "ready" =>
        stage := "page-context request"
        postPort(
          channel.port1,
          {
            "kind": "data",
            "payload": {"TAG": "Request", "id": "page-context", "message": message},
          },
        )
      | "data" =>
        clearTimer(timeout)
        closePort(channel.port1)
        switch event.data.payload.tag {
        | "Success" => resolve(event.data.payload.value)
        | _ => reject(error(event.data.payload.message))
        }
      | _ =>
        clearTimer(timeout)
        closePort(channel.port1)
        reject(error("Unexpected bridge transport response"))
      }
    })
    postWindow(
      contentWindow(querySelector(document, "iframe")),
      {"marker": "@bluehotdog/reworker/window/v2", "kind": "connect", "channel": "task"},
      "http://site.test",
      [channel.port2],
    )
  })

describe("built bridge in Chromium", _ => {
  testAsync(
    "leaves legacy frames inert and answers page context in configured frames",
    ~timeout=15_000,
    async t => {
      let bundle = await readFile("dist/bridge.js", "utf8")
      let browser = await launch({headless: true})
      try {
        let page = await newPage(browser)
        let errors = []
        on(page, "pageerror", error => errors->Array.push(error))
        await intercept(
          page,
          "http://site.test/child",
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
          "http://parent.test/",
          route =>
            fulfill(
              route,
              {
                contentType: "text/html",
                body: "<iframe src=\"http://site.test/child\"></iframe>",
              },
            ),
        )
        await goto(page, "http://parent.test/")
        t->expect(errors)->Expect.toEqual([])
        let name = ref("")
        await intercept(
          page,
          "http://site.test/",
          route =>
            fulfill(
              route,
              {
                contentType: "text/html",
                body: `<iframe name="${name.contents}" src="/child" style="width:800px;height:600px;border:0"></iframe>`,
              },
            ),
        )
        await goto(page, "http://site.test/")
        t->expect(errors)->Expect.toEqual([])
        name := "frontman:http://site.test/?channel=task"
        await goto(page, "http://site.test/")
        t->expect(errors)->Expect.toEqual([])
        let context = await evaluate(page, requestPageContext, Preview.GetPageContext)
        t->expect(context.url)->Expect.toBe("http://site.test/child")
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
