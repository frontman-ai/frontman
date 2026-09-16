module Reducer = Client__State__StateReducer
module Task = Client__Task__Types.Task

@get
external optionMarker: WebAPI.DomTypes.window => Nullable.t<int> = "BS_PRIVATE_NESTED_SOME_NONE"

@send external postMessage: (WebAPI.DomTypes.window, string, string) => unit = "postMessage"
external asReactElement: WebAPI.DomTypes.element => Dom.element = "%identity"

let rec waitForRegistration = async (~active=true, attempts: int): option<
  Client__PreviewRuntime.t,
> => {
  let runtime = Client__PreviewRuntimeRegistry.get(~clientId="browser-test")
  switch (runtime->Option.isSome == active, attempts > 0) {
  | (true, _) => runtime
  | (false, true) =>
    await Promise.make((resolve, _) => {
      FrontmanBindings.Process.setTimeout(() => resolve(), 20)->ignore
    })
    await waitForRegistration(~active, attempts - 1)
  | (false, false) => JsError.throwWithMessage("Preview runtime registration did not update")
  }
}

let check = (condition, message) =>
  switch condition {
  | true => ()
  | false => JsError.throwWithMessage(message)
  }

let main = async () => {
  let doc = WebAPI.Window.current->WebAPI.Window.document
  let body = doc->WebAPI.Document.body->Null.getOrThrow->WebAPI.HTMLElement.asElement
  let result = doc->WebAPI.Document.createElement("div")
  result->WebAPI.Element.setAttribute(~qualifiedName="id", ~value="test-result")
  let container = doc->WebAPI.Document.createElement("div")
  body->WebAPI.Element.appendChild(container->WebAPI.Element.asNode)->ignore
  let root = ReactDOM.Client.createRoot(container->asReactElement)
  let runtime = ref(None)
  let outcome = try {
    let childOrigin = "https://preview.test"
    root->ReactDOM.Client.Root.render(
      <Client__WebPreview__Body taskId="browser-test" url=childOrigin isActive=true />,
    )
    let bridge = (await waitForRegistration(250))->Option.getOrThrow
    runtime := Some(bridge)
    let iframe =
      container
      ->WebAPI.Element.querySelector("iframe")
      ->Null.getOrThrow
      ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
      ->Option.getOrThrow
    let blocked = try {
      iframe.contentWindow->Null.getOrThrow->optionMarker->ignore
      false
    } catch {
    | exn => exn->JsExn.fromException->Option.flatMap(JsExn.name) === Some("SecurityError")
    }
    check(blocked, "Cross-origin option-marker access must throw SecurityError")
    await Client__PreviewRuntime.whenOpen(bridge)
    let page = await Client__PreviewRuntime.getPageContext(bridge)
    check(page.title === "Cross-origin child", "Must read the child title")
    check(page.url->String.startsWith(childOrigin), "Must read the child URL")
    check(page.colorScheme === #dark, "Must read child matchMedia")
    check(page.astroClientRouting == Enabled, "Must read child Astro marker")
    let sibling =
      doc
      ->WebAPI.Document.createElement("iframe")
      ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
      ->Option.getOrThrow
    sibling.name = "frontman:https://parent.test/?channel=sibling&basePath=custom"
    let siblingLoaded = Promise.make((resolve, _) => {
      sibling->WebAPI.HTMLIFrameElement.addEventListener(WebAPI.EventTypes.Load, _ => resolve())
    })
    sibling.src = `${childOrigin}/sibling`
    body->WebAPI.Element.appendChild(sibling->WebAPI.HTMLIFrameElement.asNode)->ignore
    await siblingLoaded
    let siblingRuntime = Client__PreviewRuntime.make(
      ~iframe=sibling,
      ~targetOrigin=childOrigin,
      ~channel="sibling",
    )
    await Client__PreviewRuntime.whenOpen(siblingRuntime)
    let siblingPage = await Client__PreviewRuntime.getPageContext(siblingRuntime)
    check(siblingPage.url === `${childOrigin}/sibling`, "Sibling frame must use its own channel")
    Client__PreviewRuntime.close(siblingRuntime)
    sibling->WebAPI.HTMLIFrameElement.remove
    let navigationSteps = [
      ("navigate", `${childOrigin}/next?application=kept#section`),
      ("reload", `${childOrigin}/next?application=kept#section`),
      ("back", `${childOrigin}/`),
      ("forward", `${childOrigin}/next?application=kept#section`),
    ]
    for index in 0 to navigationSteps->Array.length - 1 {
      let (action, expectedUrl) = navigationSteps->Array.getUnsafe(index)
      let loaded = Promise.make((resolve, _) => {
        iframe->WebAPI.HTMLIFrameElement.addEventListener(WebAPI.EventTypes.Load, _ => resolve())
      })
      iframe.contentWindow->Null.getOrThrow->postMessage(action, childOrigin)
      await loaded
      await Client__PreviewRuntime.whenOpen(bridge)
      let navigated = await Client__PreviewRuntime.getPageContext(bridge)
      check(
        navigated.url === expectedUrl,
        `Must reconnect after ${action} without changing the URL`,
      )
    }
    root->ReactDOM.Client.Root.render(
      <Client__WebPreview__Body taskId="browser-test" url=childOrigin isActive=false />,
    )
    let inactive = await waitForRegistration(~active=false, 250)
    check(inactive == None, "Inactive previews must release their runtime")
    root->ReactDOM.Client.Root.render(
      <Client__WebPreview__Body taskId="browser-test" url=childOrigin isActive=true />,
    )
    let resumed = (await waitForRegistration(250))->Option.getOrThrow
    check(resumed !== bridge, "Reactivating a preview must establish a new runtime")
    let bridge = resumed
    runtime := Some(bridge)
    await Client__PreviewRuntime.whenOpen(bridge)
    let resumedPage = await Client__PreviewRuntime.getPageContext(bridge)
    check(
      resumedPage.url === `${childOrigin}/next?application=kept#section`,
      "Task reactivation must preserve the preview's current page",
    )
    let metadata = Client__Task__Types.currentPageToContentBlock(
      page,
      ~deviceMode=DevicePreset(Client__DeviceMode.presets->Array.get(0)->Option.getOrThrow),
      ~orientation=Landscape,
      ~isAstro=true,
    )
    switch metadata {
    | EmbeddedResource({_meta: Some(meta)}) =>
      let parsed = S.parseOrThrow(meta, ~to=Client__Task__Types.pageMetadataSchema)
      check(parsed.astro_client_routing == Some(Enabled), "Must retain Astro metadata")
      let device = parsed.device_emulation->Option.getOrThrow
      check(
        device.width == 667 && device.height == 375 && device.dpr == Some(2.0),
        "Must retain landscape device emulation independently of live viewport",
      )
    | _ => JsError.throwWithMessage("Expected metadata")
    }
    let sent = ref([])
    let promptSent = ref(() => JsError.throwWithMessage("Unexpected submission"))
    let state = {
      ...Reducer.defaultState,
      selectedModelValue: Some("test:model"),
      acpSession: AcpSessionActive({
        sendPrompt: (text, ~sessionId, ~additionalBlocks, ~onComplete as _, ~_meta as _) => {
          sent := sent.contents->Array.concat([(text, sessionId, additionalBlocks)])
          promptSent.contents()
        },
        sendSessionCommand: _ => (),
        loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
        deleteSession: (_, ~onComplete as _) => (),
        requireAuthentication: () => (),
        apiBaseUrl: "http://unused.invalid",
      }),
    }
    let messageId = Client__Message.UserMessageId.make()
    let (state, _) = Reducer.next(
      state,
      AddUserMessage({
        id: messageId,
        sessionId: "server-session",
        content: [Client__Message.UserContentPart.text("Inspect this")],
        annotations: [],
        agentId: "planner",
      }),
    )
    let clientId = state.tasks->Dict.get("server-session")->Option.getOrThrow->Task.getClientId
    check(clientId !== "server-session", "Client and server IDs must differ")
    Client__PreviewRuntimeRegistry.register(~clientId, ~runtime=bridge)
    let send = () =>
      Promise.make((resolve, _) => {
        promptSent := (() => resolve())
        Reducer.handleEffect(
          TaskEffect({
            target: ForTask("server-session"),
            effect: SendMessage({
              id: messageId,
              text: "Inspect this",
              attachments: [],
              annotations: [],
              agentId: "planner",
            }),
          }),
          state,
          _ => (),
        )
      })
    let pending = send()
    Client__PreviewRuntimeRegistry.register(~clientId="another-client", ~runtime=bridge)
    await pending
    switch sent.contents {
    | [("Inspect this", "server-session", [EmbeddedResource({_meta: Some(meta)})])] =>
      let metadata = S.parseOrThrow(meta, ~to=Client__Task__Types.pageMetadataSchema)
      check(metadata.title === Some("Cross-origin child"), "Must retain originating context")
      check(metadata.astro_client_routing == None, "Vite must omit Astro metadata")
    | _ => JsError.throwWithMessage("Expected originating prompt and context")
    }
    await send()
    switch sent.contents {
    | [_, (_, "server-session", [])] => ()
    | _ => JsError.throwWithMessage("Another task must not supply context")
    }
    Client__PreviewRuntimeRegistry.register(~clientId, ~runtime=bridge)
    Client__PreviewRuntime.close(bridge)
    await send()
    switch sent.contents {
    | [_, _, (_, "server-session", [])] => ()
    | _ => JsError.throwWithMessage("Closed runtime must fall back without context")
    }
    "passed"
  } catch {
  | exn =>
    exn
    ->JsExn.fromException
    ->Option.flatMap(JsExn.message)
    ->Option.getOr("Browser scenario failed")
  }
  runtime.contents->Option.forEach(runtime => {
    Client__PreviewRuntimeRegistry.unregister(~runtime)
    Client__PreviewRuntime.close(runtime)
  })
  root->ReactDOM.Client.Root.unmount()
  container->WebAPI.Element.remove
  result.textContent = Null.make(outcome)
  body->WebAPI.Element.appendChild(result->WebAPI.Element.asNode)->ignore
}

main()->ignore
