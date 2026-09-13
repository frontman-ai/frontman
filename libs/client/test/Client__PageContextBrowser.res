module Reducer = Client__State__StateReducer
module Task = Client__Task__Types.Task
module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview
module MessageId = Client__Message.UserMessageId

let check = (condition, message) =>
  switch condition {
  | true => ()
  | false => JsError.throwWithMessage(message)
  }

@live
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

    let sent = ref([])
    let state = {
      ...Reducer.defaultState,
      selectedModelValue: Some("test:model"),
      acpSession: AcpSessionActive({
        sendPrompt: (text, ~sessionId, ~additionalBlocks, ~onComplete as _, ~_meta as _) =>
          sent := sent.contents->Array.concat([(text, sessionId, additionalBlocks)]),
        cancelPrompt: () => (),
        retryTurn: _ => (),
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
      Reducer.sendMessageToAPIImpl(
        state,
        _ => (),
        ~messageId,
        ~message="Inspect this",
        ~attachments=[],
        ~annotations=[],
        ~taskId="server-session",
        ~agentId="planner",
      )

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
    Client__PreviewRuntimeRegistry.register(~clientId, ~runtime)
    Client__PreviewRuntime.close(runtime)
    await send()
    switch sent.contents {
    | [_, (_, "server-session", []), (_, "server-session", [])] => ()
    | _ => JsError.throwWithMessage("Unavailable previews must send without page context")
    }
    Client__PreviewRuntimeRegistry.unregister(~runtime)
  } catch {
  | exn =>
    Client__PreviewRuntimeRegistry.unregister(~runtime)
    Client__PreviewRuntime.close(runtime)
    throw(exn)
  }
}
