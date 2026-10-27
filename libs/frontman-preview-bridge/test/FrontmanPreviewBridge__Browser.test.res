open Vitest
module Reply = Response
open WebAPI
module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview

let cleanups = ref([])
afterEach(() => {
  cleanups.contents->Array.forEach(cleanup => cleanup())
  cleanups := []
})

let openFrame = async (t, ~crossOrigin=false, ~configured=false) => {
  let window = Window.current
  let document = window->Window.document
  let url = URL.make(~url="/test/child.html", ~base=(window->Window.location).origin)
  switch crossOrigin {
  | true => url.hostname = url.hostname == "localhost" ? "127.0.0.1" : "localhost"
  | false => ()
  }
  let frame =
    document
    ->Document.createElement("iframe")
    ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
    ->Option.getOrThrow
  frame.src = url.href
  frame.name = configured ? `frontman:${url.origin}/?channel=task` : ""
  frame.style.cssText = "width:800px;height:600px;border:0"
  cleanups.contents->Array.push(() => frame->HTMLIFrameElement.remove)
  let loaded = Promise.make((resolve, _) => {
    let onMessage = (event: MessageEvent.t<bool>) => {
      switch event.source === Obj.magic(frame.contentWindow->Null.getOrThrow) {
      | true => resolve(event.data)
      | false => ()
      }
    }
    window->Window.addEventListener(Message, onMessage)
    cleanups.contents->Array.push(() => window->Window.removeEventListener(Message, onMessage))
  })
  document.body->HTMLElement.appendChild(frame)->ignore
  t->expect(await loaded)->Expect.toBe(true)
  let transport = WindowTransport.Parent.make({
    targetWindow: frame.contentWindow->Null.getOrThrow,
    targetOrigin: url.origin,
    channel: "task",
    subscribeLoad: _ => () => (),
    connectionTimeoutMs: 500,
    maxChunkBytes: 1_000_000,
  })
  let runtime = Runtime.make(
    transport,
    ~limits={requestTimeoutMs: 2000, maxMessageBytes: 32_000_000, maxPendingRequests: 100},
    ~handler=(_message, _sender, _context) => Reply.none,
  )
  cleanups.contents->Array.push(() => Runtime.close(runtime))
  (runtime, url)
}

[false, true]->Array.forEach(crossOrigin => {
  testAsync(
    `unnamed ${crossOrigin ? "cross-origin" : "same-origin"} frame stays inert`,
    async t => {
      let (runtime, _) = await openFrame(t, ~crossOrigin)
      let status = await Promise.make(
        (resolve, _) => {
          cleanups.contents->Array.push(Runtime.onStatus(runtime, resolve))
        },
      )
      t
      ->expect(status)
      ->Expect.toEqual(Runtime.Disconnected("Window transport readiness timed out"))
    },
  )
})

testAsync("configured frame answers page context through the public runtime", async t => {
  let (runtime, url) = await openFrame(t, ~configured=true)
  await Runtime.whenOpen(runtime)
  let context = await Runtime.sendMessage(runtime, Preview.GetPageContext)
  t->expect(context.url)->Expect.toBe(url.href)
  t->expect(context.title)->Expect.toBe("Article")
  t->expect(context.viewportWidth)->Expect.toBe(800)
  t->expect(context.viewportHeight)->Expect.toBe(600)
  t->expect(context.astroClientRouting)->Expect.toBe(Disabled)
})
