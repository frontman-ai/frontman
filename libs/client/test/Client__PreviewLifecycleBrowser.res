let check = Client__PageContextBrowser.check

let pause = () =>
  Promise.make((resolve, _) =>
    WebAPI.DomGlobal.setTimeout(~handler=() => resolve(), ~timeout=10)->ignore
  )
let rec waitFor = async (message, predicate, ~remaining=200) => {
  switch (predicate(), remaining) {
  | (true, _) => ()
  | (false, 0) => JsError.throwWithMessage(`Preview lifecycle condition timed out: ${message}`)
  | (false, _) =>
    await pause()
    await waitFor(message, predicate, ~remaining=remaining - 1)
  }
}

let run = async childOrigin => {
  let document = WebAPI.Window.current->WebAPI.Window.document
  let container = document->WebAPI.Document.createElement("div")
  document.body->WebAPI.HTMLElement.appendChild(container->WebAPI.Element.asNode)->ignore
  let root = Test__React.createRoot(container)
  let render = (~isActive) =>
    Test__React.render(
      root,
      <Client__WebPreview__Body taskId="browser-test" url=childOrigin isActive />,
    )
  let registered = () => Client__PreviewRuntimeRegistry.get(~clientId="browser-test")
  try {
    render(~isActive=true)
    await waitFor("initial registration", () => registered()->Option.isSome)
    let runtime = registered()->Option.getOrThrow
    await Client__PreviewRuntime.whenOpen(runtime)
    let iframe =
      container
      ->WebAPI.Element.querySelector("iframe")
      ->Null.getOrThrow
      ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
      ->Option.getOrThrow
    let statuses = ref([])
    let removeListener = Client__PreviewRuntime.onStatus(runtime, status =>
      statuses := statuses.contents->Array.concat([status])
    )

    iframe.src = iframe.src
    await waitFor("reload reconnect", () =>
      statuses.contents->Array.some(status => status == Runtime.Connecting)
    )
    await Client__PreviewRuntime.whenOpen(runtime)
    await pause()
    check(
      registered()->Option.getOrThrow === runtime,
      "Reload must retain the component's runtime identity",
    )
    check(
      statuses.contents->Array.filter(status => status == Runtime.Connecting)->Array.length == 1,
      "Reload must start exactly one reconnection",
    )
    check(
      !(
        statuses.contents->Array.some(status =>
          switch status {
          | Runtime.Closed(_) => true
          | _ => false
          }
        )
      ),
      "Reload must not close the component runtime",
    )
    let page = await Client__PreviewRuntime.getPageContext(runtime)
    check(page.title == "Cross-origin child", "Reloaded bridge must answer requests")
    removeListener()
    let pending =
      Client__PreviewRuntime.getPageContext(runtime)
      ->Promise.then(_ => Promise.resolve(false))
      ->Promise.catch(_ => Promise.resolve(true))
    iframe->WebAPI.HTMLIFrameElement.dispatchEvent(WebAPI.Event.make(~type_="load"))->ignore
    check(await pending, "Load must reject requests from the previous transport session")
    await Client__PreviewRuntime.whenOpen(runtime)
    render(~isActive=false)
    await waitFor("deactivation", () => registered()->Option.isNone)
    check(
      Client__PreviewRuntime.status(runtime) == Runtime.Closed("Runtime closed"),
      "Deactivate must close the runtime",
    )
    render(~isActive=true)
    await waitFor("reactivation", () => registered()->Option.isSome)
    let replacement = registered()->Option.getOrThrow
    check(replacement !== runtime, "Reactivation must make a new runtime")
    await Client__PreviewRuntime.whenOpen(replacement)
    Client__PreviewRuntimeRegistry.unregister(~runtime)
    check(
      registered()->Option.getOrThrow === replacement,
      "Old cleanup must not unregister its replacement",
    )
    Test__React.unmount(root)
    check(registered()->Option.isNone, "Unmount must unregister the runtime")
    check(
      Client__PreviewRuntime.status(replacement) == Runtime.Closed("Runtime closed"),
      "Unmount must close the runtime",
    )
    container->WebAPI.Element.remove
  } catch {
  | exn =>
    Test__React.unmount(root)
    container->WebAPI.Element.remove
    throw(exn)
  }
}
