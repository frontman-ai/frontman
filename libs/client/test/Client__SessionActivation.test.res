open Vitest
module H = Client__ConnectionTestHelpers.Integration
module App = Client__State__StateReducer
module Task = Client__State__Types.Task
module ACP = Client__ConnectionReducer.ACPTypes
@schema type promptMeta = {@as("frontman.dev/messageId") @live id: string, model: option<string>}
@schema type prompt = {_meta: promptMeta}
@module("vitest") @scope("vi") external unstub: unit => unit = "unstubAllGlobals"
@set external runtime: (WebAPI.DomTypes.window, option<JSON.t>) => unit = "__frontmanRuntime"
let result = ref(None)
let active = ref(None)
let dispatch = (store: H.store, action: App.action) => store->StateStore.dispatch(action)
let state = StateStore.getState
let send = store => {
  result := None
  dispatch(
    store,
    AddUserMessage({
      content: [App.UserContentPart.text("draft")],
      annotationId: None,
      onComplete: value => result := Some(value),
    }),
  )
}
let wait = async predicate => await Vi.waitFor(() =>
    switch predicate() {
    | true => ()
    | false => failwith("Waiting for transport completion")
    }
  , ())
let config = (store, model) => dispatch(store, SetSelectedModelValue({value: model}))
let clear = store => dispatch(store, ClearCurrentTask)
beforeEach(() => {
  Vi.useFakeTimers()->ignore
  Client__TextDeltaBuffer.reset()
  result := None
})
afterEachAsync(async () => {
  active.contents->Option.forEach(store => dispatch(store, ConnectionAction(Dispose)))
  active := None
  for _ in 0 to 8 {
    await Promise.resolve()
  }
  Client__TextDeltaBuffer.reset()
  runtime(WebAPI.Window.current, None)
  Vi.useRealTimers()->ignore
  unstub()
})

testAsync(
  "client session-flow integration: explicit creation/retry and authoritative active config",
  async t => {
    let (store, wire, matches, last, created, configured, reject, _, _) = await H.start()
    active := Some(store)
    t->expect(state(store).draftModelPreference)->Expect.toEqual(Some(H.b))
    send(store)
    await wait(() => matches("session/new")->Array.length == 1)
    let first = last("session/new")
    t
    ->expect(S.parseOrThrow(H.request(first).params, ~to=ACP.sessionNewParamsSchema)._meta)
    ->Expect.toEqual(Some({model: H.b}))
    created(first, H.b)
    await wait(() => matches("session/prompt")->Array.length == 1)
    let prompt = S.parseOrThrow(H.request(last("session/prompt")).params, ~to=promptSchema)
    t->expect(prompt._meta.model)->Expect.toEqual(None)
    t
    ->expect((
      App.Selectors.selectedModelValue(state(store)),
      matches("session/set_config_option")->Array.length,
    ))
    ->Expect.toEqual((Some(H.b), 0))
    clear(store)
    send(store)
    await wait(() => matches("session/new")->Array.length == 2)
    let lost = last("session/new")
    let id = H.sessionId(lost)
    let _ = await Vi.advanceTimersByTimeAsync(120001)
    await wait(() => result.contents->Option.mapOr(false, Result.isError))
    config(store, H.a)
    send(store)
    await wait(() => matches("session/new")->Array.length == 3)
    t->expect(H.sessionId(last("session/new")))->Expect.toBe(id)
    created(last("session/new"), H.a)
    await wait(() => matches("session/prompt")->Array.length == 2)
    t->expect(matches("session/set_config_option")->Array.length)->Expect.toBe(0)
    t->expect(App.Selectors.selectedModelValue(state(store)))->Expect.toEqual(Some(H.a))
    for outcome in 0 to 3 {
      let before = matches("session/set_config_option")->Array.length
      config(store, H.b)
      await wait(() => matches("session/set_config_option")->Array.length == before + 1)
      let pending = last("session/set_config_option")
      t
      ->expect(S.parseOrThrow(H.request(pending).params, ~to=ACP.setConfigOptionParamsSchema))
      ->Expect.toEqual({sessionId: id, configId: "model", value: H.b})
      let count = matches("session/prompt")->Array.length
      let selected = App.Selectors.selectedModelValue(state(store))
      send(store)
      config(store, H.a)
      t
      ->expect((
        matches("session/prompt")->Array.length,
        matches("session/set_config_option")->Array.length,
        App.Selectors.isSubmitting(state(store)),
      ))
      ->Expect.toEqual((count, before + 1, true))
      t->expect(App.Selectors.selectedModelValue(state(store)))->Expect.toEqual(selected)
      switch outcome {
      | 0 => reject(pending)
      | 1 => configured(pending, H.b)
      | 2 =>
        wire.reply(
          pending,
          S.decodeOrThrow(
            {ACP.configOptions: []},
            ~from=ACP.configOptionsUpdatedSchema,
            ~to=S.json,
          ),
          None,
        )
      | _ =>
        clear(store)
        configured(pending, H.b)
      }
      await wait(() => !App.Selectors.isSubmitting(state(store)))
      t
      ->expect(App.Selectors.selectedModelValue(state(store)))
      ->Expect.toEqual(
        switch outcome {
        | 1 => Some(H.b)
        | 2 => None
        | _ => Some(H.a)
        },
      )
      t
      ->expect(App.Selectors.getSessionError(state(store)))
      ->Expect.toEqual(outcome == 0 ? Some("Unknown model") : None)
      switch outcome {
      | 1 =>
        StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
          store,
          {...state(store), pendingProviderAutoSelect: Some("test")},
        )
        for catalog in 0 to 1 {
          wire.emit("model_catalog_updated", H.catalog(Some(catalog == 0 ? H.a : H.b)))
          t
          ->expect((
            App.Selectors.selectedModelValue(state(store)),
            state(store).draftModelPreference,
            state(store).pendingProviderAutoSelect,
          ))
          ->Expect.toEqual((Some(H.b), Some(H.a), None))
        }
      | _ => ()
      }
      t->expect(state(store).draftModelPreference)->Expect.toEqual(Some(H.a))
      t
      ->expect(
        WebAPI.Window.current
        ->WebAPI.Window.localStorage
        ->WebAPI.Storage.getItem("frontman:selectedModelValue")
        ->Null.toOption,
      )
      ->Expect.toEqual(Some(H.a))
    }
    let before = matches("session/new")->Array.length
    send(store)
    await wait(() => matches("session/new")->Array.length == before + 1)
    reject(last("session/new"))
    await wait(() => result.contents->Option.mapOr(false, Result.isError))
    t->expect(App.Selectors.isNewTask(state(store)))->Expect.toBe(true)
    wire.emit("model_catalog_updated", H.catalog(None))
    t->expect(state(store).draftModelPreference)->Expect.toEqual(None)
    dispatch(store, ConnectionAction(Dispose))
    let disposed = state(store)
    wire.emit("model_catalog_updated", H.catalog(Some(H.b)))
    t->expect(state(store))->Expect.toBe(disposed)
  },
)

testAsync(
  "client session-flow integration: cached/channel reconnect replay preserves model, identity and local data",
  async t => {
    let (store, wire, matches, last, created, _, reject, notify, loaded) = await H.start()
    active := Some(store)
    let newSession = async model => {
      config(store, model)
      let before = matches("session/new")->Array.length
      send(store)
      await wait(() => matches("session/new")->Array.length == before + 1)
      let frame = last("session/new")
      created(frame, model)
      await wait(() => App.Selectors.getSession(state(store))->Option.isSome)
      H.sessionId(frame)
    }
    let a = await newSession(H.a)
    await wait(() => matches("session/prompt")->Array.length == 1)
    let prompt = last("session/prompt")
    dispatch(
      store,
      TaskAction({target: ForTask(a), action: LoadStarted({previewUrl: "about:blank"})}),
    )
    StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
      store,
      App.Lens.updateTask(state(store), a, task =>
        switch task {
        | Loading(data) =>
          Loading({
            ...data,
            pendingUserMessageIds: Array.concat(data.pendingUserMessageIds, ["other-unacked"]),
          })
        | _ => failwith("Expected owned loading task")
        }
      ),
    )
    reject(prompt)
    await wait(() =>
      switch App.Selectors.currentTask(state(store)) {
      | Loading({
          pendingUserMessageIds: ["other-unacked"],
          turnError: Some({message: "Unknown model"}),
        }) => true
      | _ => false
      }
    )
    t->expect(Task.isLoading(App.Selectors.currentTask(state(store))))->Expect.toBe(true)
    dispatch(store, TaskAction({target: ForTask(a), action: LoadComplete}))
    let annotation = Client__Annotation__Types.make(
      ~element=WebAPI.DomGlobal.document->WebAPI.Document.createElement("div"),
      ~tagName="div",
    )
    StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
      store,
      App.Lens.updateTask(state(store), a, task =>
        task->Task.updateLoadedData(
          data => {
            ...data,
            annotations: [annotation],
            annotationMode: Selecting,
            isAgentRunning: true,
            imageAttachments: Dict.fromArray([
              (
                "image",
                {
                  Client__Message.id: "image",
                  filename: "image.png",
                  mediaType: "image/png",
                  dataUrl: "data:image/png;base64,AAAA",
                },
              ),
            ]),
            queuedUserMessages: [
              App.Message.User({
                id: "queued",
                content: [App.UserContentPart.text("queued draft")],
                annotations: [],
                agentId: "agent-1",
              }),
            ],
            pendingUserMessageIds: ["queued"],
            previewFrame: {...data.previewFrame, contentDocument: Some(WebAPI.DomGlobal.document)},
          },
        )
      ),
    )
    let local = App.Selectors.currentTask(state(store))
    clear(store)
    let _ = await newSession(H.b)
    let replay = async () => {
      let before = matches("session/load")->Array.length
      dispatch(store, SwitchTask({taskId: a}))
      await wait(() => matches("session/load")->Array.length == before + 1)
      t->expect(App.Selectors.isSubmitting(state(store)))->Expect.toBe(true)
      let frame = last("session/load")
      notify(
        frame,
        AgentMessageChunk({
          messageId: "history",
          content: TextContent({text: "History", _meta: None, annotations: None}),
          _meta: {agentId: "agent-1", timestamp: "2026-01-01T00:00:00Z"},
        }),
      )
      loaded(frame, H.a)
      await wait(() =>
        !App.Selectors.isSubmitting(state(store)) &&
        Task.isLoaded(App.Selectors.currentTask(state(store)))
      )
      frame
    }
    let old = await replay()
    t
    ->expect(
      Client__Task__Reducer.Selectors.isAgentRunning(App.Selectors.currentTask(state(store))),
    )
    ->Expect.toEqual(Some(true))
    let count = matches("session/load")->Array.length
    dispatch(store, SwitchTask({taskId: a}))
    t->expect(matches("session/load")->Array.length)->Expect.toBe(count)
    wire.lose(false)
    let _ = await Vi.advanceTimersByTimeAsync(1000)
    await wait(() => matches("session/load")->Array.length == count + 1)
    notify(
      last("session/load"),
      AgentMessageChunk({
        messageId: "history",
        content: TextContent({text: "History", _meta: None, annotations: None}),
        _meta: {agentId: "agent-1", timestamp: "2026-01-01T00:00:00Z"},
      }),
    )
    notify(
      last("session/load"),
      Error({
        _meta: Some(
          S.decodeOrThrow(
            {Client__ACP__MessageCodec.agentErrorId: "replay-error"},
            ~from=Client__ACP__MessageCodec.frontmanErrorMetaSchema,
            ~to=S.json,
          ),
        ),
        message: "quota",
        timestamp: "2026-01-01T00:00:00Z",
        category: Some("quota"),
        retryAt: None,
        attempt: None,
        maxAttempts: None,
      }),
    )
    loaded(last("session/load"), H.a)
    await wait(() => !App.Selectors.isSubmitting(state(store)))
    loaded(old, H.b)
    let restored = App.Selectors.currentTask(state(store))
    t
    ->expect((
      App.Selectors.selectedModelValue(state(store)),
      state(store).draftModelPreference,
      Task.getClientId(restored),
      Task.getAnnotations(restored),
    ))
    ->Expect.toEqual((Some(H.a), Some(H.b), Task.getClientId(local), [annotation]))
    switch (local, restored) {
    | (Loaded(before), Loaded(after)) =>
      t
      ->expect((
        after.title,
        after.createdAt,
        after.updatedAt,
        after.imageAttachments,
        after.queuedUserMessages,
        after.pendingUserMessageIds,
        after.previewFrame.contentDocument,
        after.annotationMode,
      ))
      ->Expect.toEqual((
        before.title,
        before.createdAt,
        before.updatedAt,
        before.imageAttachments,
        before.queuedUserMessages,
        before.pendingUserMessageIds,
        before.previewFrame.contentDocument,
        before.annotationMode,
      ))
      t
      ->expect((
        after.isAgentRunning,
        after.turnError->Option.map(error => (error.message, error.retryErrorId)),
      ))
      ->Expect.toEqual((false, Some(("quota", Some("replay-error")))))
    | _ => failwith("Replay must retain loaded metadata")
    }
    t
    ->expect(
      Task.getMessages(restored)->Array.map(message =>
        switch message {
        | Assistant(Completed({id, content: [Text({text})]})) => (id, text)
        | Error(error) => (
            App.Message.ErrorMessage.id(error),
            App.Message.ErrorMessage.error(error),
          )
        | _ => failwith("Unexpected replay transcript")
        }
      ),
    )
    ->Expect.toEqual([("history", "History"), ("replay-error", "quota")])
  },
)
