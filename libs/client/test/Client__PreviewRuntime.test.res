open Vitest

@send
external createIframeElement: (
  WebAPI.DomTypes.document,
  @as(json`"iframe"`) _,
) => WebAPI.DomTypes.htmliFrameElement = "createElement"

afterEach(() => {
  Vi.useRealTimers()->ignore
})

let makeIframe = () => {
  let document = WebAPI.Window.current->WebAPI.Window.document
  let iframe = document->createIframeElement
  document
  ->WebAPI.Document.body
  ->Null.toOption
  ->Option.getOrThrow(~message="Test document requires a body")
  ->WebAPI.HTMLElement.appendChild(iframe->WebAPI.HTMLIFrameElement.asNode)
  ->ignore
  iframe
}

let removeIframe = iframe => iframe->WebAPI.HTMLIFrameElement.remove

describe("preview parent runtime", _t => {
  testAsync("close rejects readiness, notifies status, and prevents reconnecting", async t => {
    let iframe = makeIframe()
    let runtime = Client__PreviewRuntime.make(
      ~iframe,
      ~targetOrigin="http://localhost:3000",
      ~channel="preview-task-id",
    )
    let statuses = ref([])
    let removeStatusListener = Client__PreviewRuntime.onStatus(
      runtime,
      status => statuses := statuses.contents->Array.concat([status]),
    )
    let readiness = Client__PreviewRuntime.whenOpen(runtime)

    Client__PreviewRuntime.close(runtime)
    let readinessOutcome = await readiness
    ->Promise.then(_ => Promise.resolve("opened"))
    ->Promise.catch(_ => Promise.resolve("closed"))
    iframe
    ->WebAPI.HTMLIFrameElement.dispatchEvent(WebAPI.Event.make(~type_="load"))
    ->ignore
    t
    ->expect(Client__PreviewRuntime.status(runtime))
    ->Expect.toEqual(Runtime.Closed("Runtime closed"))
    t->expect(readinessOutcome)->Expect.toBe("closed")
    t->expect(statuses.contents)->Expect.toEqual([Runtime.Closed("Runtime closed")])
    removeStatusListener()
    removeIframe(iframe)
  })

  testAsync("timeout disconnects before deterministic close", async t => {
    Vi.useFakeTimers()->ignore
    let iframe = makeIframe()
    let runtime = Client__PreviewRuntime.make(
      ~iframe,
      ~targetOrigin="http://localhost:3000",
      ~channel="preview-task-id",
    )

    let _ = await Vi.advanceTimersByTimeAsync(5000)
    t
    ->expect(Client__PreviewRuntime.status(runtime))
    ->Expect.toEqual(Runtime.Disconnected("Window transport readiness timed out"))

    Client__PreviewRuntime.close(runtime)
    removeIframe(iframe)
  })

  test("rejects wildcard origins and empty channels", t => {
    let iframe = makeIframe()

    t
    ->expect(
      () =>
        Client__PreviewRuntime.make(~iframe, ~targetOrigin="*", ~channel="preview-task-id")->ignore,
    )
    ->Expect.toThrow
    t
    ->expect(
      () =>
        Client__PreviewRuntime.make(
          ~iframe,
          ~targetOrigin="http://localhost:3000",
          ~channel="",
        )->ignore,
    )
    ->Expect.toThrow
    removeIframe(iframe)
  })
})
