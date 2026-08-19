open Vitest

type bootstrapMessage = {
  marker: string,
  kind: string,
  channel: string,
}

afterEach(() => {
  Vi.useRealTimers()->ignore
})

let makeIframe = (~onPostMessage) => {
  let targetWindow: Dict.t<Obj.t> = Dict.make()
  targetWindow->Dict.set("postMessage", Obj.magic(onPostMessage))

  let iframe = WebAPI.EventTarget.make()
  (Obj.magic(iframe): Dict.t<Obj.t>)->Dict.set("contentWindow", Obj.magic(targetWindow))
  (Obj.magic(iframe): WebAPI.DomTypes.element)
}

describe("preview parent runtime", _t => {
  testAsync("opens only with the expected origin and channel", async t => {
    let iframe = makeIframe(
      ~onPostMessage=(
        message: bootstrapMessage,
        targetOrigin: string,
        ports: array<MessagePort.t>,
      ) => {
        switch (message.marker, message.kind, message.channel, targetOrigin, ports->Array.get(0)) {
        | (
            "@bluehotdog/reworker/window/v2",
            "connect",
            "preview-task-id",
            "https://preview.example.com",
            Some(port),
          ) =>
          let ready: Dict.t<string> = Dict.make()
          ready->Dict.set("kind", "ready")
          MessagePort.postMessage(port, ready)
        | _ => ()
        }
      },
    )
    let runtime = Client__PreviewRuntime.make(
      ~iframe,
      ~targetOrigin="https://preview.example.com",
      ~channel="preview-task-id",
    )
    let statuses = ref([])
    let removeStatusListener = Client__PreviewRuntime.onStatus(
      runtime,
      status => statuses := statuses.contents->Array.concat([status]),
    )

    t->expect(Client__PreviewRuntime.status(runtime))->Expect.toEqual(Runtime.Connecting)
    await Client__PreviewRuntime.whenOpen(runtime)
    t->expect(Client__PreviewRuntime.status(runtime))->Expect.toEqual(Runtime.Open)
    t->expect(statuses.contents)->Expect.toContain(Runtime.Open)

    removeStatusListener()
    Client__PreviewRuntime.close(runtime)
  })

  test("close removes the iframe load subscription", t => {
    let postCount = ref(0)
    let iframe = makeIframe(
      ~onPostMessage=(_message, _targetOrigin, _ports) => postCount := postCount.contents + 1,
    )
    let runtime = Client__PreviewRuntime.make(
      ~iframe,
      ~targetOrigin="https://preview.example.com",
      ~channel="preview-task-id",
    )

    t->expect(postCount.contents)->Expect.toBe(1)
    Client__PreviewRuntime.close(runtime)
    iframe
    ->Obj.magic
    ->WebAPI.EventTarget.dispatchEvent(WebAPI.Event.make(~type_="load"))
    ->ignore
    t->expect(postCount.contents)->Expect.toBe(1)
  })

  testAsync("timeout disconnects and close removes the load subscription", async t => {
    Vi.useFakeTimers()->ignore
    let postCount = ref(0)
    let iframe = makeIframe(
      ~onPostMessage=(_message, _targetOrigin, _ports) => postCount := postCount.contents + 1,
    )
    let runtime = Client__PreviewRuntime.make(
      ~iframe,
      ~targetOrigin="https://preview.example.com",
      ~channel="preview-task-id",
    )

    let _ = await Vi.advanceTimersByTimeAsync(5000)
    t
    ->expect(Client__PreviewRuntime.status(runtime))
    ->Expect.toEqual(Runtime.Disconnected("Window transport readiness timed out"))

    Client__PreviewRuntime.close(runtime)
    iframe
    ->Obj.magic
    ->WebAPI.EventTarget.dispatchEvent(WebAPI.Event.make(~type_="load"))
    ->ignore
    t->expect(postCount.contents)->Expect.toBe(1)
  })

  test("rejects wildcard origins and empty channels", t => {
    let iframe = makeIframe(~onPostMessage=(_message, _targetOrigin, _ports) => ())

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
          ~targetOrigin="https://preview.example.com",
          ~channel="",
        )->ignore,
    )
    ->Expect.toThrow
  })
})
