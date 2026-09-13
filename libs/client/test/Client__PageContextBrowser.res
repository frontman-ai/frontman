module Reducer = Client__State__StateReducer
module Task = Client__Task__Types.Task
module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview
module MessageId = Client__Message.UserMessageId

let check = (condition, message) =>
  switch condition {
  | true => ()
  | false => JsError.throwWithMessage(message)
  }

@set
external setRuntimeConfig: (WebAPI.DomTypes.window, {"framework": string}) => unit =
  "__frontmanRuntime"

let checkGenericGetDom = async (framework, childOrigin) => {
  let input: Client__Tool__GetDom.input = {
    selector: "#page",
    mode: None,
    maxDepth: None,
    maxNodes: None,
    pierceShadowDom: None,
  }
  let execute = input => Test__GetDom.execute(framework, input, ~taskId="server-session")
  let response = await execute(input)
  check(response.isError == None, "Generic inspection must succeed through the bridge")
  let page = response.structuredContent->Option.getOrThrow
  check(page.url->String.startsWith(childOrigin), "DOM snapshots must include the child URL")
  check(
    !(page.html->String.includes("data-astro-transition-persist")),
    "Generic snapshots must not add Astro persistence attributes",
  )
  check(
    page.astro_client_routing == None &&
    page.astro_persistence == None &&
    page.astro_navigation == None,
    "Astro enrichment must stay out of non-Astro inspection",
  )
  let response = await execute({...input, selector: "#missing"})
  check(
    response.isError == Some(true) && response.structuredContent == None,
    "Failed snapshots must produce MCP errors",
  )
  check(
    (response.content->Array.get(0)->Option.getOrThrow).text->String.includes("No element found"),
    "Snapshot errors must explain the failure",
  )
}

let run = async (iframe: WebAPI.DomTypes.htmliFrameElement, childOrigin: string) => {
  let runtime = Client__PreviewRuntime.make(
    ~iframe,
    ~targetOrigin=childOrigin,
    ~channel="browser-test",
  )
  try {
    await Client__PreviewRuntime.whenOpen(runtime)
    let page = await Client__PreviewRuntime.getPageContext(runtime)
    check(page.title === "Cross-origin child", "Must inspect the child, not the parent")
    check(page.url->String.startsWith(childOrigin), "Must report the child's URL")
    check(page.colorScheme === #dark, "Must read child media query state")
    check(page.astroClientRouting == Enabled, "Must read routing markers from the child document")

    let sent = ref([])
    let promptSent = ref(() => JsError.throwWithMessage("Unexpected prompt submission"))
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
    let messageId = MessageId.make()
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
    check(clientId !== "server-session", "Test must exercise distinct client/session IDs")
    Client__PreviewRuntimeRegistry.register(~clientId, ~runtime)
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
    Client__PreviewRuntimeRegistry.register(~clientId="another-client", ~runtime)
    await pending
    switch sent.contents {
    | [("Inspect this", "server-session", [EmbeddedResource({_meta: Some(meta)})])] =>
      let metadata = S.parseOrThrow(meta, ~to=Client__Task__Types.pageMetadataSchema)
      check(
        metadata.title === Some("Cross-origin child"),
        "Must attach the captured child's context",
      )
    | _ => JsError.throwWithMessage("Expected one enriched prompt for the originating session")
    }

    await send()
    switch sent.contents {
    | [_, (_, "server-session", [])] => ()
    | _ => JsError.throwWithMessage("Other tasks' previews must not supply context")
    }
    Client__PreviewRuntimeRegistry.register(~clientId, ~runtime)
    StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
      Client__State__Store.store,
      state,
    )
    let frameworks = [Client__RuntimeConfig.Astro, Nextjs, Vite, Wordpress]
    for index in 0 to frameworks->Array.length - 1 {
      let framework = frameworks->Array.get(index)->Option.getOrThrow
      setRuntimeConfig(
        WebAPI.Window.current,
        {"framework": Client__RuntimeConfig.frameworkIdToString(framework)},
      )
      sent := []
      await send()
      switch sent.contents {
      | [(_, "server-session", [EmbeddedResource({_meta: Some(meta)})])] =>
        let metadata = S.parseOrThrow(meta, ~to=Client__Task__Types.pageMetadataSchema)
        check(
          metadata.astro_client_routing == (
              framework == Astro ? Some(page.astroClientRouting) : None
            ),
          "Only Astro prompts must include the child's routing metadata",
        )
      | _ => JsError.throwWithMessage("Expected bridged current-page metadata")
      }
      switch framework {
      | Astro | Vite | Wordpress => ()
      | Nextjs => await checkGenericGetDom(framework, childOrigin)
      }
    }
    sent := []
    Client__PreviewRuntime.close(runtime)
    await send()
    switch sent.contents {
    | [(_, "server-session", [])] => ()
    | _ => JsError.throwWithMessage("Closed previews must send without page context")
    }
    Client__PreviewRuntimeRegistry.unregister(~runtime)
    let unavailable = await Test__GetDom.execute(
      Nextjs,
      {selector: "#page", mode: None, maxDepth: None, maxNodes: None, pierceShadowDom: None},
      ~taskId="server-session",
    )
    check(
      unavailable.isError == Some(true) && unavailable.structuredContent == None,
      "Missing runtimes must produce MCP errors",
    )
    check(
      (unavailable.content->Array.get(0)->Option.getOrThrow).text->String.includes(
        "Preview bridge runtime not available",
      ),
      "Missing runtime errors must identify the bridge",
    )
  } catch {
  | exn =>
    Client__PreviewRuntimeRegistry.unregister(~runtime)
    Client__PreviewRuntime.close(runtime)
    throw(exn)
  }
}
