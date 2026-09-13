open Vitest

module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview
module TaskTypes = Client__Task__Types

let page: Preview.pageContext = {
  url: "https://preview.example/actual-page",
  title: "Child title",
  viewportWidth: 844,
  viewportHeight: 390,
  devicePixelRatio: 2.0,
  scrollY: 72,
  colorScheme: #dark,
  astroClientRouting: Enabled,
}

let metadata = block =>
  switch block {
  | TaskTypes.ContentBlock.EmbeddedResource({_meta: Some(meta)}) =>
    S.parseOrThrow(meta, ~to=TaskTypes.pageMetadataSchema)
  | _ => JsError.throwWithMessage("Expected page metadata")
  }

test("rejects a send effect without a session before collecting context", t => {
  module Reducer = Client__State__StateReducer
  let id = Client__Message.UserMessageId.make()
  let actions = ref([])
  Reducer.handleEffect(
    TaskEffect({
      target: ForTask("originating-session"),
      effect: SendMessage({
        id,
        text: "Inspect this",
        attachments: [],
        annotations: [],
        agentId: "planner",
      }),
    }),
    Reducer.defaultState,
    action => actions := actions.contents->Array.concat([action]),
  )
  t
  ->expect(actions.contents)
  ->Expect.toEqual([
    Reducer.TaskAction({
      target: ForTask("originating-session"),
      action: UserMessageSendFailed({id, error: "Cannot send message: no active ACP session"}),
    }),
  ])
})

test("submits synchronously using caller-supplied page context", t => {
  module Reducer = Client__State__StateReducer
  let blocks = [
    TaskTypes.currentPageToContentBlock(
      page,
      ~deviceMode=Responsive,
      ~orientation=Portrait,
      ~isAstro=true,
    ),
  ]
  let sent = ref([])
  let () = Reducer.sendMessageToAPIImpl(
    Reducer.defaultState,
    _ => JsError.throwWithMessage("Unexpected send failure"),
    ~sendPrompt=(text, ~sessionId, ~additionalBlocks, ~onComplete as _, ~_meta as _) => {
      sent := [(text, sessionId, additionalBlocks)]
    },
    ~runtimeConfig={
      framework: Astro,
      basePath: "frontman",
      relayBaseUrl: None,
      wpNonce: None,
      wordpressPluginsUrl: None,
      projectRoot: None,
      traits: None,
    },
    ~pageContextBlocks=blocks,
    ~messageId=Client__Message.UserMessageId.make(),
    ~message="Inspect this",
    ~attachments=[],
    ~annotations=[],
    ~taskId="originating-session",
    ~agentId="planner",
  )
  t->expect(sent.contents)->Expect.toEqual([("Inspect this", "originating-session", blocks)])
})

describe("pure page context formatting", _ => {
  test("preserves child metadata and parent device emulation", t => {
    let block = TaskTypes.currentPageToContentBlock(
      page,
      ~deviceMode=DevicePreset({
        name: "Test phone",
        category: "Phones",
        width: 390,
        height: 844,
        dpr: 2.0,
      }),
      ~orientation=Landscape,
      ~isAstro=true,
    )
    let meta = metadata(block)
    t->expect(meta.url)->Expect.toBe(page.url)
    t->expect(meta.title)->Expect.toEqual(Some("Child title"))
    t->expect(meta.scroll_y)->Expect.toBe(72)
    t->expect(meta.astro_client_routing)->Expect.toEqual(Some(Enabled))
    t->expect(meta.color_scheme)->Expect.toEqual(Some(#dark))
    t->expect(meta.viewport_width)->Expect.toBe(844)
    t
    ->expect(meta.device_emulation)
    ->Expect.toEqual(
      Some({
        active: true,
        width: Some(844),
        height: Some(390),
        name: "Test phone",
        orientation: "landscape",
        dpr: Some(2.0),
      }),
    )
    switch block {
    | EmbeddedResource({resource: TextResourceContents({uri, text})}) =>
      t->expect(uri)->Expect.toBe(`page://${page.url}`)
      t->expect(text->String.includes("Title: Child title"))->Expect.toBe(true)
    | _ => JsError.throwWithMessage("Expected page text resource")
    }
  })

  test("omits unsupported color scheme, empty title, and inactive emulation", t => {
    let meta =
      TaskTypes.currentPageToContentBlock(
        {...page, title: "", colorScheme: #unsupported},
        ~deviceMode=Responsive,
        ~orientation=Portrait,
        ~isAstro=false,
      )->metadata
    t->expect(meta.title)->Expect.toEqual(None)
    t->expect(meta.color_scheme)->Expect.toEqual(None)
    t->expect(meta.device_emulation)->Expect.toEqual(None)
    t->expect(meta.astro_client_routing)->Expect.toEqual(None)
  })
})
