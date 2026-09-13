module Reducer = Client__State__StateReducer
module Task = Client__Task__Types.Task

@get
external optionMarker: WebAPI.DomTypes.window => Nullable.t<int> = "BS_PRIVATE_NESTED_SOME_NONE"

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
  let iframe =
    doc
    ->WebAPI.Document.createElement("iframe")
    ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
    ->Option.getOrThrow
  let runtime = ref(None)
  let outcome = try {
    let childOrigin = "http://127.0.0.1:43002"
    let loaded = Promise.make((resolve, _) => {
      iframe->WebAPI.HTMLIFrameElement.addEventListener(WebAPI.EventTypes.Load, _ => resolve())
    })
    iframe.src = childOrigin
    body->WebAPI.Element.appendChild(iframe->WebAPI.HTMLIFrameElement.asNode)->ignore
    await loaded
    let blocked = try {
      iframe.contentWindow->Null.getOrThrow->optionMarker->ignore
      false
    } catch {
    | exn => exn->JsExn.fromException->Option.flatMap(JsExn.name) === Some("SecurityError")
    }
    check(blocked, "Firefox must reproduce the option-marker SecurityError")
    let bridge = Client__PreviewRuntime.make(
      ~iframe,
      ~targetOrigin=childOrigin,
      ~channel="browser-test",
    )
    runtime := Some(bridge)
    await Client__PreviewRuntime.whenOpen(bridge)
    let page = await Client__PreviewRuntime.getPageContext(bridge)
    check(page.title === "Cross-origin child", "Must read the child title")
    check(page.url->String.startsWith(childOrigin), "Must read the child URL")
    check(page.colorScheme === #dark, "Must read child matchMedia")
    check(page.astroClientRouting == Enabled, "Must read child Astro marker")
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
  iframe->WebAPI.HTMLIFrameElement.remove
  result.textContent = Null.make(outcome)
  body->WebAPI.Element.appendChild(result->WebAPI.Element.asNode)->ignore
}

main()->ignore
