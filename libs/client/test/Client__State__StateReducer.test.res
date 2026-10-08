open Vitest

module Reducer = Client__State__StateReducer
module StateTypes = Client__State__Types
module TaskReducer = Client__Task__Reducer
module Task = Client__State__Types.Task
module UserContentPart = Client__State__Types.UserContentPart
module AssistantContentPart = Client__State__Types.AssistantContentPart
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock
module UserMessageId = Client__Message.UserMessageId
let testUserMessageId = UserMessageId.make()
let secondTestUserMessageId = UserMessageId.make()

@schema
type pageRoutingMeta = {astro_client_routing: option<string>}

let setRuntime: JSON.t => unit = %raw(`function(value) { window.__frontmanRuntime = value }`)
let clearRuntime: unit => unit = %raw(`function() { delete window.__frontmanRuntime }`)

type acpModule
type promptSpy
type unsubscribe = unit => unit
@module("../../react-statestore/src/StateStore.res.mjs")
external subscribe: ('store, unit => unit) => unsubscribe = "subscribe"
@module
external acpModule: acpModule = "@frontman-ai/frontman-client/src/FrontmanClient__ACP.res.mjs"
@module("vitest") @scope("vi")
external spyOnPrompt: (acpModule, @as("sendPrompt") _) => promptSpy = "spyOn"
@send
external mockImplementation: (
  promptSpy,
  (
    Client__ConnectionReducer.ACP.session,
    string,
    ~additionalBlocks: array<ContentBlock.t>,
    ~_meta: option<JSON.t>,
  ) => promise<result<ACP.promptResult, Client__ConnectionReducer.ACP.requestError>>,
) => unit = "mockImplementation"
@module("vitest") @scope("vi") external restoreAllMocks: unit => unit = "restoreAllMocks"
let mockPrompt = handler => spyOnPrompt(acpModule)->mockImplementation(handler)
beforeEach(Client__ActivationTestHelpers.setup)
afterEach(() => {
  Client__ActivationTestHelpers.unstubAllGlobals()
  clearRuntime()
  restoreAllMocks()
})

module TestHelpers = {
  let makeLoadedTask = (
    ~id,
    ~title,
    ~previewUrl,
    ~createdAt as _,
    ~messages=[],
    ~isAgentRunning=false,
  ) =>
    Task.makeNew(~previewUrl)
    ->Task.newToLoaded(~id, ~title)
    ->Task.updateLoadedData(data => {...data, messages, isAgentRunning})

  let makeStateWithTasks = (~tasks, ~currentTask) => {
    ...Reducer.defaultState,
    tasks,
    currentTask,
    selectedModelValue: Some("test:model"),
  }

  let makeStateWithTask = (
    ~taskId="test-task-1",
    ~messages=[],
    ~previewUrl="http://localhost:3000",
    ~isAgentRunning=false,
  ) => {
    let task = makeLoadedTask(
      ~id=taskId,
      ~title="Test Task",
      ~previewUrl,
      ~createdAt=1000.0,
      ~messages,
      ~isAgentRunning,
    )

    let tasks = Dict.make()
    tasks->Dict.set(taskId, task)

    makeStateWithTasks(~tasks, ~currentTask=Task.Selected(taskId))
  }

  let getMessages = Reducer.Selectors.messages
  let getMessage = (state, index) => getMessages(state)->Array.get(index)
  let getTaskCount = (state: Client__State__Types.state) =>
    state.tasks->Dict.valuesToArray->Array.length

  let getCurrentTaskId = (state: Client__State__Types.state): option<string> => {
    Reducer.Selectors.currentTaskId(state)
  }

  let modelConfigOptions = (~models: array<string>) => {
    [
      ACP.SelectConfigOption({
        id: "model",
        name: "Model",
        description: None,
        category: Some(ACP.Model),
        options: ACP.Grouped([
          {
            group: "future_provider",
            name: "Future Provider",
            options: models->Array.map(value => {
              let option: ACP.sessionConfigSelectOption = {
                value,
                name: value,
                description: None,
                _meta: None,
              }
              option
            }),
            _meta: None,
          },
        ]),
        _meta: None,
      }),
    ]
  }

  let acceptUserMessage = (
    state,
    ~taskId,
    ~id,
    ~content=[UserContentPart.text("Hello")],
    ~annotations=[],
  ) => {
    Reducer.next(
      state,
      TaskAction({
        target: ForTask(taskId),
        action: UserMessageReceived({id, content, annotations, agentId: "executor-id"}),
      }),
    )->Pair.first
  }
}

describe("Client State Reducer - Integration Updates", () => {
  let wordpress = StateTypes.WordPressPlugin
  let npm = StateTypes.NpmPackage("@frontman-ai/nextjs")

  test("finds an outdated WordPress plugin", t => {
    let result = Reducer.updateInfoForVersions(
      ~target=wordpress,
      ~installedVersion="1.2.0",
      ~latestVersion="1.3.0",
    )

    t
    ->expect(result)
    ->Expect.toEqual(Some({target: wordpress, installedVersion: "1.2.0", latestVersion: "1.3.0"}))
  })

  test("ignores equal, newer, and invalid versions", t => {
    [
      ("1.3.0", "1.3.0"),
      ("1.4.0", "1.3.0"),
      ("invalid", "1.3.0"),
      ("1.2.0", "invalid"),
    ]->Array.forEach(
      ((installedVersion, latestVersion)) =>
        t
        ->expect(
          Reducer.updateInfoForVersions(~target=wordpress, ~installedVersion, ~latestVersion),
        )
        ->Expect.toEqual(None),
    )
  })

  test("preserves npm version comparison", t => {
    let result = Reducer.updateInfoForVersions(
      ~target=npm,
      ~installedVersion="1.2.0",
      ~latestVersion="1.3.0",
    )

    t
    ->expect(result)
    ->Expect.toEqual(Some({target: npm, installedVersion: "1.2.0", latestVersion: "1.3.0"}))
  })

  test("refreshes updates without an ACP session and clears stale notices", t => {
    let (_, effects) = Reducer.next(
      Reducer.defaultState,
      Reducer.CheckForUpdate({
        apiBaseUrl: "https://api.frontman.sh",
        installedVersion: "1.2.0",
        target: wordpress,
      }),
    )
    let staleInfo: StateTypes.updateInfo = {
      target: wordpress,
      installedVersion: "1.2.0",
      latestVersion: "1.3.0",
    }
    let state = {...Reducer.defaultState, updateInfo: Some(staleInfo)}
    let cleared = Reducer.next(
      state,
      Reducer.WordPressUpdatesChecked(
        Some({
          installedVersion: "1.3.0",
          latestVersion: "1.3.0",
          autoUpdateEnabled: true,
        }),
      ),
    )->Pair.first

    t->expect(effects->Array.length)->Expect.toEqual(1)
    t->expect(cleared.updateInfo)->Expect.toEqual(None)
    t
    ->expect(cleared.wordpressUpdates)
    ->Expect.toEqual(Client__WordPressUpdates.Available({autoUpdateEnabled: true}))
  })
})

describe("Client State Reducer - Custom Providers", () => {
  let provider = (~name, ~models): StateTypes.customProvider => {
    id: "provider-1",
    name,
    baseUrl: "https://api.example.com/v1",
    hasApiKey: false,
    models,
    lockVersion: 3,
  }

  let draft = (
    ~id=None,
    ~apiKeyChange=StateTypes.KeepCustomProviderApiKey,
  ): StateTypes.customProviderDraft => {
    id,
    name: "Provider",
    baseUrl: "https://api.example.com/v1",
    apiKeyChange,
    models: ["model-a", "model-b"],
    lockVersion: id->Option.map(_ => 3),
  }
  let updateBody = apiKeyChange =>
    `{"name":"Provider","base_url":"https://api.example.com/v1","models":["model-a","model-b"],"lock_version":3,"api_key_change":${apiKeyChange}}`
  let reduce = (state, action) => Reducer.next(state, action)->Pair.first

  test("save encodes requests and decodes successful responses", t => {
    let update = draft(
      ~id=Some("provider-1"),
      ~apiKeyChange=StateTypes.ReplaceCustomProviderApiKey("secret"),
    )
    [
      (
        draft(),
        `{"name":"Provider","base_url":"https://api.example.com/v1","models":["model-a","model-b"]}`,
      ),
      (update, updateBody(`{"action":"replace","value":"secret"}`)),
      (draft(~id=Some("provider-1")), updateBody(`{"action":"keep"}`)),
      (
        draft(~id=Some("provider-1"), ~apiKeyChange=StateTypes.ClearCustomProviderApiKey),
        updateBody(`{"action":"clear"}`),
      ),
    ]->Array.forEach(
      ((draft, body)) =>
        t->expect(Reducer.encodeCustomProviderSaveRequest(draft))->Expect.toEqual(body),
    )
    t
    ->expect(Reducer.customProviderSaveTarget(~apiBaseUrl="/api", draft()))
    ->Expect.toEqual(("/api/api/user/custom-providers", "POST"))
    t
    ->expect(Reducer.customProviderSaveTarget(~apiBaseUrl="/api", update))
    ->Expect.toEqual(("/api/api/user/custom-providers/provider-1", "PUT"))
    t
    ->expect(Reducer.customProviderDeleteUrl(~apiBaseUrl="/api", ~id="provider-1", ~lockVersion=3))
    ->Expect.toEqual("/api/api/user/custom-providers/provider-1?lock_version=3")

    let decoded =
      JSON.parseOrThrow(`{"data":{"id":"provider-1","name":"Updated","base_url":"https://api.example.com/v1","has_api_key":false,"models":["vision-model"],"lock_version":3}}`)->S.decodeOrThrow(
        ~from=S.json,
        ~to=StateTypes.customProviderResponseSchema,
      )
    t->expect(decoded.provider)->Expect.toEqual(provider(~name="Updated", ~models=["vision-model"]))
  })

  test("mutations serialize and accept only matching completions", t => {
    let state = {...Reducer.defaultState, connection: Client__ConnectionTestHelpers.ready()}
    let saveOperation = StateTypes.SavingCustomProvider(Some("provider-1"))
    let (saving, effects) = Reducer.next(
      state,
      Reducer.SaveCustomProvider(draft(~id=Some("provider-1"))),
    )
    t
    ->expect(saving.customProviderMutation)
    ->Expect.toEqual(StateTypes.CustomProviderMutationPending(saveOperation))
    t->expect(effects->Array.length)->Expect.toEqual(1)

    let (unchanged, blockedEffects) = Reducer.next(
      saving,
      Reducer.DeleteCustomProvider("provider-1", 3),
    )
    t->expect(unchanged)->Expect.toEqual(saving)
    t->expect(blockedEffects)->Expect.toEqual([])

    let updated = provider(~name="Updated", ~models=["vision-model"])
    let saved = reduce(
      saving,
      Reducer.CustomProviderMutationSucceeded({operation: saveOperation, provider: Some(updated)}),
    )
    t->expect(saved.customProviders)->Expect.toEqual(Some([updated]))
    t
    ->expect(saved.customProviderMutation)
    ->Expect.toEqual(StateTypes.CustomProviderMutationSucceeded(saveOperation))
    t
    ->expect(reduce(saved, Reducer.AcknowledgeCustomProviderMutation).customProviderMutation)
    ->Expect.toEqual(StateTypes.CustomProviderMutationIdle)

    let deleteOperation = StateTypes.DeletingCustomProvider("provider-1")
    let kept = {...updated, id: "provider-2"}
    let deleting = {
      ...saving,
      customProviders: Some([updated, kept]),
      selectedModelValue: Some("custom:provider-1:vision-model"),
      customProviderMutation: StateTypes.CustomProviderMutationPending(deleteOperation),
    }
    let deleted = reduce(
      deleting,
      Reducer.CustomProviderMutationSucceeded({operation: deleteOperation, provider: None}),
    )
    t->expect(deleted.customProviders)->Expect.toEqual(Some([kept]))
    t->expect(deleted.selectedModelValue)->Expect.toEqual(None)

    let error = StateTypes.CustomProviderNetworkError("offline")
    let failed = reduce(
      saving,
      Reducer.CustomProviderMutationFailed({operation: saveOperation, error}),
    )
    t
    ->expect(failed.customProviderMutation)
    ->Expect.toEqual(StateTypes.CustomProviderMutationFailed({operation: saveOperation, error}))
    t
    ->expect(reduce(failed, Reducer.AcknowledgeCustomProviderMutation).customProviderMutation)
    ->Expect.toEqual(StateTypes.CustomProviderMutationIdle)
    [
      Reducer.CustomProviderMutationSucceeded({operation: deleteOperation, provider: None}),
      Reducer.CustomProviderMutationFailed({operation: deleteOperation, error}),
    ]->Array.forEach(action => t->expect(reduce(saving, action))->Expect.toEqual(saving))
  })

  test("custom provider effects request shared authentication when token is missing", t => {
    WebAPI.Window.current
    ->WebAPI.Window.localStorage
    ->WebAPI.Storage.removeItem(Client__EmbeddedAuth.tokenStorageKey)

    let requireAuthenticationCalled = ref(false)
    let observeAuth = action =>
      switch action {
      | Reducer.ConnectionAction(RequireAuthentication) => requireAuthenticationCalled := true
      | _ => ()
      }
    let state = {...Reducer.defaultState, connection: Client__ConnectionTestHelpers.ready()}
    let (_fetchState, fetchEffects) = Reducer.next(state, Reducer.FetchCustomProviders)

    switch fetchEffects->Array.get(0) {
    | Some(effect) => Reducer.handleEffect(effect, state, observeAuth)
    | None => JsExn.throw("Expected FetchCustomProvidersEffect")
    }
    t->expect(requireAuthenticationCalled.contents)->Expect.toBe(true)

    requireAuthenticationCalled := false
    let (mutationState, mutationEffects) = Reducer.next(state, Reducer.SaveCustomProvider(draft()))
    let dispatched = ref([])
    switch mutationEffects->Array.get(0) {
    | Some(effect) =>
      Reducer.handleEffect(
        effect,
        mutationState,
        action => {
          observeAuth(action)
          dispatched := Array.concat(dispatched.contents, [action])
        },
      )
    | None => JsExn.throw("Expected CustomProviderMutationEffect")
    }
    t->expect(requireAuthenticationCalled.contents)->Expect.toBe(true)
    switch dispatched.contents {
    | [
        Reducer.ConnectionAction(RequireAuthentication),
        Reducer.CustomProviderMutationFailed({operation, error}),
      ] => {
        t->expect(operation)->Expect.toEqual(StateTypes.SavingCustomProvider(None))
        t
        ->expect(error)
        ->Expect.toEqual(
          StateTypes.CustomProviderNetworkError("Frontman authorization is required"),
        )
      }
    | _ => JsExn.throw("Expected custom provider auth-required failure")
    }
  })

  test("OAuth effects request shared authentication when token is missing", t => {
    WebAPI.Window.current
    ->WebAPI.Window.localStorage
    ->WebAPI.Storage.removeItem(Client__EmbeddedAuth.tokenStorageKey)

    let requireAuthenticationCount = ref(0)
    let observeAuth = action =>
      switch action {
      | Reducer.ConnectionAction(RequireAuthentication) =>
        requireAuthenticationCount := requireAuthenticationCount.contents + 1
      | _ => ()
      }
    let effects = [
      Reducer.FetchAnthropicOAuthStatusEffect({
        apiBaseUrl: "http://localhost:4000",
      }),
      Reducer.GetAnthropicOAuthUrlEffect({
        apiBaseUrl: "http://localhost:4000",
      }),
      Reducer.ExchangeAnthropicOAuthCodeEffect({
        apiBaseUrl: "http://localhost:4000",
        code: "code-123",
        verifier: "verifier-123",
      }),
      Reducer.DisconnectAnthropicOAuthEffect({
        apiBaseUrl: "http://localhost:4000",
      }),
      Reducer.FetchOpenAIOAuthStatusEffect({
        apiBaseUrl: "http://localhost:4000",
      }),
      Reducer.InitiateOpenAIDeviceAuthEffect({
        apiBaseUrl: "http://localhost:4000",
      }),
      Reducer.PollOpenAIDeviceAuthEffect({
        apiBaseUrl: "http://localhost:4000",
        deviceAuthId: "device-123",
        userCode: "user-code",
      }),
      Reducer.DisconnectOpenAIOAuthEffect({
        apiBaseUrl: "http://localhost:4000",
      }),
    ]

    effects->Array.forEach(
      effect => Reducer.handleEffect(effect, Reducer.defaultState, observeAuth),
    )

    t->expect(requireAuthenticationCount.contents)->Expect.toBe(effects->Array.length)
  })

  test("stale errors retain latest sanitized provider", t => {
    let current = provider(~name="Current", ~models=["model-a"])
    let error = Reducer.decodeCustomProviderMutationError(
      ~status=409,
      ~json=JSON.parseOrThrow(`{"status":"error","code":"stale","current_provider":{"id":"provider-1","name":"Current","base_url":"https://api.example.com/v1","has_api_key":false,"models":["model-a"],"lock_version":3}}`),
    )
    t->expect(error)->Expect.toEqual(StateTypes.CustomProviderConflict(current))
    let conflicted = {
      ...Reducer.defaultState,
      customProviderMutation: StateTypes.CustomProviderMutationFailed({
        operation: StateTypes.SavingCustomProvider(Some("provider-1")),
        error,
      }),
    }
    let resolved = reduce(conflicted, Reducer.AcknowledgeCustomProviderMutation)
    t->expect(resolved.customProviders)->Expect.toEqual(Some([current]))
    t
    ->expect(Reducer.decodeCustomProviderMutationError(~status=404, ~json=JSON.parseOrThrow(`{}`)))
    ->Expect.toEqual(StateTypes.CustomProviderNotFound)
    t
    ->expect(
      Reducer.decodeCustomProviderMutationError(
        ~status=422,
        ~json=JSON.parseOrThrow(`{"code":"validation_failed","errors":{"name":["is required"]}}`),
      ),
    )
    ->Expect.toEqual(
      StateTypes.CustomProviderValidationError(Dict.fromArray([("name", ["is required"])])),
    )
  })
})

let planner: ACP.agentCatalogEntry = {
  id: "planner-id",
  name: "planner",
  displayName: "Planner",
  description: "Plans work",
  color: "#F59E0B",
}

let executor: ACP.agentCatalogEntry = {
  id: "executor-id",
  name: "executor",
  displayName: "Executor",
  description: "Executes work",
  color: "#985DF7",
}

let plannerPlan = Reducer.Message.Assistant(
  Completed({
    id: "assistant-plan",
    content: [AssistantContentPart.text("1. Do X")],
    agentId: planner.id,
  }),
)

let withPlanHandoffContext = (state: Client__State__Types.state): Client__State__Types.state => {
  ...state,
  connection: Client__ConnectionTestHelpers.ready(),
  agentCatalog: Some([planner, executor]),
}

describe("Client State Reducer - Plan Handoff", () => {
  test("execute atomically consumes the handoff and sends through the executor", t => {
    let state = TestHelpers.makeStateWithTask(~messages=[plannerPlan])->withPlanHandoffContext
    let action = Reducer.ExecutePendingPlan({id: testUserMessageId})
    let (executing, effects) = Reducer.next(state, action)

    t->expect(executing.selectedAgentId)->Expect.toEqual(Some(executor.id))
    t->expect(Reducer.Selectors.isAgentRunning(executing))->Expect.toBe(true)

    switch effects->Array.get(0) {
    | Some(Reducer.SendMessage({taskId: "test-task-1", submission: {content, agentId}})) => {
        t
        ->expect(TaskReducer.extractTextFromUserContent(content))
        ->Expect.toBe(Reducer.executePlanPrompt)
        t->expect(agentId)->Expect.toBe(executor.id)
      }
    | _ => JsExn.throw("Expected executor SendMessage effect")
    }

    let (_, duplicateEffects) = Reducer.next(executing, action)
    t->expect(duplicateEffects)->Expect.toEqual([])
  })

  test("execute does nothing without a selected model", t => {
    let state = {
      ...TestHelpers.makeStateWithTask(~messages=[plannerPlan])->withPlanHandoffContext,
      selectedModelValue: None,
    }
    let (nextState, effects) = Reducer.next(
      state,
      Reducer.ExecutePendingPlan({id: testUserMessageId}),
    )

    t->expect(nextState)->Expect.toEqual(state)
    t->expect(effects)->Expect.toEqual([])
  })

  test("planner follow-up consumes the handoff before the server reports running", t => {
    let state = TestHelpers.makeStateWithTask(~messages=[plannerPlan])->withPlanHandoffContext
    let (submitting, _) = Reducer.addUserMessageToState(
      state,
      ~sessionId="test-task-1",
      {
        id: testUserMessageId,
        content: [UserContentPart.text("Revise step one")],
        annotations: [],
        agentId: planner.id,
        onComplete: _ => (),
      },
    )

    let (_, executeEffects) = Reducer.next(submitting, ExecutePendingPlan({id: testUserMessageId}))
    t->expect(executeEffects)->Expect.toEqual([])
  })

  test("cancelled partial planner output never becomes a pending handoff", t => {
    let partialPlan = Reducer.Message.Assistant(
      Streaming({id: "assistant-plan", textBuffer: "1. Part", agentId: planner.id}),
    )
    let running =
      TestHelpers.makeStateWithTask(
        ~messages=[partialPlan],
        ~isAgentRunning=true,
      )->withPlanHandoffContext
    let (cancelled, _) = Reducer.next(running, CancelTurn)

    t->expect(Reducer.Selectors.pendingPlanHandoff(cancelled))->Expect.toEqual(None)

    let (serverIdle, _) = Reducer.next(
      cancelled,
      TaskAction({target: ForTask("test-task-1"), action: ExecutionStateIdle}),
    )
    t->expect(Reducer.Selectors.pendingPlanHandoff(serverIdle))->Expect.toEqual(None)
  })

  test("pendingPlanHandoff is unavailable while task history is loading", t => {
    let unloaded = Task.makeUnloaded(
      ~id="test-task-1",
      ~title="Plan",
      ~createdAt=1000.0,
      ~updatedAt=1000.0,
    )
    let (loading, _) = TaskReducer.next(
      unloaded,
      LoadStarted({previewUrl: "http://localhost:3000"}),
    )
    let (loading, _) = TaskReducer.next(
      loading,
      TextDeltaReceived({
        messageId: "assistant-plan",
        text: "1. Do X",
        agentId: planner.id,
      }),
    )
    let (loading, _) = TaskReducer.next(loading, ExecutionStateIdle)
    let tasks = Dict.make()
    tasks->Dict.set("test-task-1", loading)
    let state =
      TestHelpers.makeStateWithTasks(
        ~tasks,
        ~currentTask=Task.Selected("test-task-1"),
      )->withPlanHandoffContext

    t->expect(Reducer.Selectors.pendingPlanHandoff(state))->Expect.toEqual(None)
  })
})

describe("Client State Reducer", () => {
  test("agent configuration selects advertised default and preserves valid selection", t => {
    let (state, _) = Reducer.next(
      Reducer.defaultState,
      AgentAttributionConfigured({agentCatalog: [executor, planner], defaultAgentId: "planner-id"}),
    )

    t->expect(state.selectedAgentId)->Expect.toEqual(Some("planner-id"))
    let (state, _) = Reducer.next(state, SetSelectedAgentId("executor-id"))
    let (state, _) = Reducer.next(
      state,
      AgentAttributionConfigured({agentCatalog: [planner, executor], defaultAgentId: "planner-id"}),
    )
    t->expect(state.selectedAgentId)->Expect.toEqual(Some("executor-id"))
  })

  test("agent configuration replaces stale selection with advertised default", t => {
    let state = {...Reducer.defaultState, selectedAgentId: Some("removed-id")}
    let (state, _) = Reducer.next(
      state,
      AgentAttributionConfigured({agentCatalog: [planner], defaultAgentId: "planner-id"}),
    )

    t->expect(state.agentCatalog)->Expect.toEqual(Some([planner]))
    t->expect(state.selectedAgentId)->Expect.toEqual(Some("planner-id"))
  })

  test("AddUserMessage creates task and sends without optimistic message", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}
    let (nextState, effects) = Reducer.addUserMessageToState(
      state,
      ~sessionId="session-1",
      {
        id: testUserMessageId,
        content: [UserContentPart.text("Hello")],
        annotations: [],
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )

    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(1)
    t->expect(TestHelpers.getCurrentTaskId(nextState)->Option.isSome)->Expect.toBe(true)

    let messages = Reducer.Selectors.messages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(0)

    switch effects->Array.get(0) {
    | Some(Reducer.SendMessage({submission: {agentId}})) =>
      t->expect(agentId)->Expect.toBe("executor-id")
    | _ => JsExn.throw("Expected SendMessage effect")
    }
  })

  test("messages maintain order", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}

    let (state, _) = Reducer.addUserMessageToState(
      state,
      ~sessionId="session-1",
      {
        id: testUserMessageId,
        content: [UserContentPart.text("Hi")],
        annotations: [],
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let state = TestHelpers.acceptUserMessage(
      state,
      ~taskId,
      ~id=testUserMessageId->UserMessageId.toString,
      ~content=[UserContentPart.text("Hi")],
    )

    let (state, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: ExecutionStateRunning}),
    )
    let (state, _) = Reducer.next(
      state,
      TaskAction({
        target: ForTask(taskId),
        action: TextDeltaReceived({
          messageId: "assistant-1",
          text: "Hello",
          agentId: "test-agent",
        }),
      }),
    )
    let (state, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: ExecutionStateIdle}),
    )

    let messages = TestHelpers.getMessages(state)
    t->expect(messages->Array.length)->Expect.toBe(2)
    let msg0 = messages->Array.get(0)->Option.getOrThrow
    let msg1 = messages->Array.get(1)->Option.getOrThrow

    switch (msg0, msg1) {
    | (User(_), Assistant(_)) => ()
    | _ => JsExn.throw("Expected User message first, then Assistant message")
    }
  })

  test("Selectors.isStreaming detects streaming messages", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "",
            agentId: "test-agent",
          }),
        ),
      ],
    )

    t->expect(Reducer.Selectors.isStreaming(state))->Expect.toBe(true)
  })

  test("Selectors.isStreaming false when no streaming", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.Assistant(
          Completed({
            id: "assistant-1",
            content: [AssistantContentPart.text("Done")],
            agentId: "test-agent",
          }),
        ),
      ],
    )

    t->expect(Reducer.Selectors.isStreaming(state))->Expect.toBe(false)
  })

  test("ToolCallReceived creates new ToolCall message", t => {
    let state = TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "Calling tool...",
            agentId: "test-agent",
          }),
        ),
        Reducer.Message.ToolCall({
          id: "call-123",
          toolName: "search",
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.Message.InputStreaming,
          parentAgentId: None,
          spawningToolName: None,
        }),
      ],
    )

    let toolCall: Reducer.Message.toolCall = {
      id: "call-123",
      toolName: "search",
      inputBuffer: "",
      input: Some(JSON.Encode.object({})),
      result: None,
      errorText: None,
      state: Reducer.Message.InputAvailable,
      parentAgentId: None,
      spawningToolName: None,
    }

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let action = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolCallReceived({toolCall: toolCall}),
    })
    let (nextState, _effects) = Reducer.next(state, action)

    let messages = TestHelpers.getMessages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(ToolCall({id, toolName, input, _})) => {
        t->expect(id)->Expect.toBe("call-123")
        t->expect(toolName)->Expect.toBe("search")
        t->expect(input)->Expect.toEqual(Some(JSON.Encode.object({})))
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })
})

describe("Client State Reducer - Task Completion", () => {
  test("does not track failed turns as successful completions", t => {
    let state = TestHelpers.makeStateWithTask(~isAgentRunning=true)
    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let (failed, _) = Reducer.next(
      state,
      TaskAction({
        target: ForTask(taskId),
        action: AgentError({
          id: "failed-turn",
          error: "Provider rejected the request",
          category: #unknown,
        }),
      }),
    )
    let (_, effects) = Reducer.next(
      failed,
      TaskAction({target: ForTask(taskId), action: ExecutionStateIdle}),
    )
    t
    ->expect(effects->Array.includes(Reducer.TrackActivation("request_completed")))
    ->Expect.toBe(false)
  })

  test("completes the first task without promotional effects, including after history loads", t => {
    let state = {
      ...TestHelpers.makeStateWithTask(
        ~isAgentRunning=true,
        ~messages=[
          Reducer.Message.Assistant(
            Streaming({id: "assistant-1", textBuffer: "Done", agentId: "test-agent"}),
          ),
        ],
      ),
      sessionsLoadState: StateTypes.SessionsLoading,
    }
    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let (completedState, effects) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: ExecutionStateIdle}),
    )
    t->expect(Reducer.Selectors.isAgentRunning(completedState))->Expect.toBe(false)
    t->expect(effects)->Expect.toEqual([Reducer.TrackActivation("request_completed")])
    let (_, duplicateEffects) = Reducer.next(
      completedState,
      TaskAction({target: ForTask(taskId), action: ExecutionStateIdle}),
    )
    t->expect(duplicateEffects)->Expect.toEqual([])

    let (_, historyEffects) = Reducer.next(completedState, SessionsLoadSuccess({sessions: []}))
    t->expect(historyEffects)->Expect.toEqual([])
  })
})

describe("Client State Reducer - Idle Content Conversion", () => {
  test("handles empty textBuffer correctly", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "msg-2",
            textBuffer: "",
            agentId: "test-agent",
          }),
        ),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let (nextState, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: ExecutionStateIdle}),
    )

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Reducer.Message.Assistant(Completed({content, _})) =>
      t->expect(content->Array.length)->Expect.toBe(0)
    | _ =>
      t
      ->expect("Expected Completed message with empty content")
      ->Expect.toBe("Got wrong message type")
    }
  })
})

describe("Client State Reducer - Selectors", () => {
  test("getMessageId selector works for all message types", t => {
    let userMsg = Reducer.Message.User({
      id: "user-1",
      content: [],
      annotations: [],
      agentId: "executor-id",
    })

    let streamingMsg = Reducer.Message.Assistant(
      Reducer.Message.Streaming({
        id: "streaming-1",
        textBuffer: "",
        agentId: "test-agent",
      }),
    )

    let completedMsg = Reducer.Message.Assistant(
      Reducer.Message.Completed({
        id: "completed-1",
        content: [],
        agentId: "test-agent",
      }),
    )

    let toolCallMsg = Reducer.Message.ToolCall({
      id: "tool-1",
      toolName: "search",
      state: Reducer.Message.InputAvailable,
      inputBuffer: "",
      input: None,
      result: None,
      errorText: None,
      parentAgentId: None,
      spawningToolName: None,
    })

    t->expect(Reducer.Selectors.getMessageId(userMsg))->Expect.toBe("user-1")
    t->expect(Reducer.Selectors.getMessageId(streamingMsg))->Expect.toBe("streaming-1")
    t->expect(Reducer.Selectors.getMessageId(completedMsg))->Expect.toBe("completed-1")
    t->expect(Reducer.Selectors.getMessageId(toolCallMsg))->Expect.toBe("tool-1")
  })
})

describe("Client State Reducer - Tool Lifecycle", () => {
  test("ToolResultReceived sets result and OutputAvailable state", t => {
    let state = TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
          result: None,
          errorText: None,
          state: Reducer.Message.InputAvailable,
          parentAgentId: None,
          spawningToolName: None,
        }),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let rawOutput = JSON.Encode.object(Dict.make())
    let rawOutputAction = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolResultReceived({
        id: "call-1",
        rawOutput: Some(rawOutput),
        content: None,
        complete: false,
      }),
    })
    let (partialState, _) = Reducer.next(state, rawOutputAction)
    switch TestHelpers.getMessage(partialState, 0)->Option.getOrThrow {
    | Reducer.Message.ToolCall({state, result: Some(result), _}) => {
        t->expect(state)->Expect.toBe(Reducer.Message.InputAvailable)
        t->expect(result.rawOutput)->Expect.toEqual(Some(rawOutput))
      }
    | _ => JsExn.throw("Expected partial ToolCall result")
    }
    let content: ACP.toolCallContentItem = Content({
      content: ContentBlock.TextContent({text: "done", _meta: None, annotations: None}),
      _meta: None,
    })
    let contentAction = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolResultReceived({
        id: "call-1",
        rawOutput: None,
        content: Some([content]),
        complete: false,
      }),
    })
    let (contentState, _) = Reducer.next(partialState, contentAction)
    let completedAction = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolResultReceived({
        id: "call-1",
        rawOutput: None,
        content: None,
        complete: true,
      }),
    })
    let (nextState, _) = Reducer.next(contentState, completedAction)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Reducer.Message.ToolCall({state, result: Some(result), _}) => {
        t->expect(state)->Expect.toBe(Reducer.Message.OutputAvailable)
        t->expect(result.rawOutput)->Expect.toEqual(Some(rawOutput))
        t->expect(result.content->Array.length)->Expect.toBe(1)
      }
    | _ => JsExn.throw("Expected ToolCall message")
    }
  })

  test("ToolErrorReceived sets error and OutputError state", t => {
    let state = TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
          result: None,
          errorText: None,
          state: Reducer.Message.InputAvailable,
          parentAgentId: None,
          spawningToolName: None,
        }),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let action = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolErrorReceived({
        id: "call-1",
        error: "File not found",
      }),
    })
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Reducer.Message.ToolCall({state, errorText, _}) => {
        t->expect(state)->Expect.toBe(Reducer.Message.OutputError)
        t->expect(errorText)->Expect.toBe(Some("File not found"))
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })

  test("ToolInputReceived makes streaming input available", t => {
    let state = TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "",
            agentId: "test-agent",
          }),
        ),
        Reducer.Message.ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.Message.InputStreaming,
          parentAgentId: None,
          spawningToolName: None,
        }),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let expectedInput = JSON.parseOrThrow(`{"path":"test.res","range":{"start":12}}`)
    let action = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolInputReceived({id: "call-1", input: expectedInput}),
    })
    let (nextState, _) = Reducer.next(state, action)

    let messages = TestHelpers.getMessages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(Reducer.Message.ToolCall({state, input, _})) => {
        t->expect(state)->Expect.toBe(Reducer.Message.InputAvailable)
        t->expect(input)->Expect.toEqual(Some(expectedInput))
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })
})

describe("Client State Reducer - Task ID Continuity", () => {
  test("multiple user messages in same conversation use same task ID in state", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}

    let (state1, _effects1) = Reducer.addUserMessageToState(
      state,
      ~sessionId="sessionId",
      {
        id: testUserMessageId,
        content: [UserContentPart.text("First message")],
        annotations: [],
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )

    let taskId1 = TestHelpers.getCurrentTaskId(state1)

    let (state2, _effects2) = Reducer.addUserMessageToState(
      state1,
      ~sessionId="sessionId",
      {
        id: secondTestUserMessageId,
        content: [UserContentPart.text("Second message")],
        annotations: [],
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )

    let taskId2 = TestHelpers.getCurrentTaskId(state2)

    t->expect(taskId1->Option.isSome)->Expect.toBe(true)
    t->expect(taskId2->Option.isSome)->Expect.toBe(true)
    t->expect(taskId1)->Expect.toEqual(taskId2)
  })

  test("effect contains same task ID as state", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}

    let (state1, effects1) = Reducer.addUserMessageToState(
      state,
      ~sessionId="sessionId",
      {
        id: testUserMessageId,
        content: [UserContentPart.text("First message")],
        annotations: [],
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )

    let taskIdInState = TestHelpers.getCurrentTaskId(state1)

    switch (effects1->Array.get(0), taskIdInState) {
    | (Some(Reducer.SendMessage({taskId: effectTaskId})), Some(stateTaskId)) =>
      t->expect(effectTaskId)->Expect.toBe(stateTaskId)
    | _ => t->expect("Effect and state should both have task ID")->Expect.toBe("Missing task IDs")
    }
  })
})

describe("Client State Reducer - Task Management Actions", () => {
  test("SwitchTask restores task messages", t => {
    let task1 = TestHelpers.makeLoadedTask(
      ~id="task-1",
      ~title="Task 1",
      ~previewUrl="http://localhost:3000",
      ~createdAt=1000.0,
      ~messages=[
        Reducer.Message.User({
          id: "user-1",
          content: [UserContentPart.Text({text: "Hello from task 1"})],
          annotations: [],
          agentId: "executor-id",
        }),
      ],
    )

    let task2 = TestHelpers.makeLoadedTask(
      ~id="task-2",
      ~title="Task 2",
      ~previewUrl="http://localhost:3000",
      ~createdAt=2000.0,
      ~messages=[
        Reducer.Message.User({
          id: "user-2",
          content: [UserContentPart.Text({text: "Hello from task 2"})],
          annotations: [],
          agentId: "executor-id",
        }),
      ],
    )

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)
    tasks->Dict.set("task-2", task2)

    let state = TestHelpers.makeStateWithTasks(~tasks, ~currentTask=Task.Selected("task-1"))

    let (nextState, _) = Reducer.next(state, SwitchTask({taskId: "task-2"}))

    let messages = Reducer.Selectors.messages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(1)

    let message = messages->Array.get(0)->Option.getOrThrow

    switch message {
    | User({content, _}) => {
        let contentPart = content->Array.get(0)->Option.getOrThrow
        switch contentPart {
        | UserContentPart.Text({text}) => t->expect(text)->Expect.toBe("Hello from task 2")
        | _ => JsExn.throw("Expected Text content part")
        }
      }
    | _ => JsExn.throw("Expected User message")
    }
  })

  test("ClearCurrentTask preserves current preview URL", t => {
    let previewUrl = "http://localhost:3000/products/42?tab=details"
    let state = TestHelpers.makeStateWithTask(~previewUrl)

    let (nextState, _effects) = Reducer.next(state, ClearCurrentTask)

    t->expect(Reducer.Selectors.previewUrl(nextState))->Expect.toBe(previewUrl)
    switch nextState.currentTask {
    | Task.New(_) => t->expect(true)->Expect.toBe(true)
    | Task.Selected(_) => t->expect(false)->Expect.toBe(true)
    }
  })

  test("SetPreviewUrl synchronizes the selected task browser URL", t => {
    let state = TestHelpers.makeStateWithTask()
    let previewUrl = "http://localhost:3000/products/42"
    let (nextState, effects) = Reducer.next(
      state,
      TaskAction({target: CurrentTask, action: SetPreviewUrl({url: previewUrl})}),
    )

    t->expect(Reducer.Selectors.previewUrl(nextState))->Expect.toBe(previewUrl)
    switch effects->Array.get(0) {
    | Some(Reducer.TaskEffect({
        target: ForTask("test-task-1"),
        effect: SyncBrowserUrl(syncedUrl),
      })) =>
      t->expect(syncedUrl)->Expect.toBe(previewUrl)
    | _ => JsExn.throw("Expected browser URL synchronization effect")
    }
  })

  test("DeleteTask removes the task and its session", t => {
    let deletedTaskId = ref(None)
    let state = {
      ...TestHelpers.makeStateWithTask(~taskId="task-1"),
      connection: Client__ConnectionTestHelpers.ready(),
    }
    let store = Client__ConnectionTestHelpers.makeStore(
      state,
      (effect, state, dispatch) =>
        switch effect {
        | ConnectionEffect(DeleteSessionEffect({taskId})) => deletedTaskId := Some(taskId)
        | _ => Reducer.handleEffect(effect, state, dispatch)
        },
    )

    store->StateStore.dispatch(DeleteTask({taskId: "task-1"}))
    let state = store->StateStore.getState

    t->expect(TestHelpers.getTaskCount(state))->Expect.toBe(0)
    t->expect(Reducer.Selectors.currentTaskId(state))->Expect.toEqual(None)
    t->expect(deletedTaskId.contents)->Expect.toEqual(Some("task-1"))
  })

  test("AddUserMessage after deleting last task creates new task", t => {
    let task1 = TestHelpers.makeLoadedTask(
      ~id="task-1",
      ~title="Task 1",
      ~previewUrl="http://localhost:3000",
      ~createdAt=1000.0,
      ~messages=[
        Reducer.Message.User({
          id: "user-1",
          content: [UserContentPart.Text({text: "Old message"})],
          annotations: [],
          agentId: "executor-id",
        }),
      ],
    )

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)

    let state = TestHelpers.makeStateWithTasks(~tasks, ~currentTask=Task.Selected("task-1"))

    let (stateAfterDelete, _) = Reducer.next(state, DeleteTask({taskId: "task-1"}))
    t->expect(TestHelpers.getTaskCount(stateAfterDelete))->Expect.toBe(0)
    switch stateAfterDelete.currentTask {
    | Task.New(_) => ()
    | _ => JsExn.throw("Expected New task after deleting last task")
    }

    let (stateAfterMsg, effects) = Reducer.addUserMessageToState(
      stateAfterDelete,
      ~sessionId="session-new",
      {
        id: secondTestUserMessageId,
        content: [UserContentPart.text("Hello after delete")],
        annotations: [],
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )

    t->expect(TestHelpers.getTaskCount(stateAfterMsg))->Expect.toBe(1)
    let newTaskId = TestHelpers.getCurrentTaskId(stateAfterMsg)->Option.getOrThrow
    t->expect(newTaskId)->Expect.not->Expect.toBe("task-1")

    let messages = Reducer.Selectors.messages(stateAfterMsg)
    t->expect(messages->Array.length)->Expect.toBe(0)

    switch effects->Array.get(0) {
    | Some(Reducer.SendMessage({taskId: effectTaskId})) =>
      t->expect(effectTaskId)->Expect.toBe(newTaskId)
    | _ => JsExn.throw("Expected SendMessage effect for new task")
    }
  })

  test("Tasks maintain independent state across switches", t => {
    let task1 = TestHelpers.makeLoadedTask(
      ~id="task-1",
      ~title="Task 1",
      ~previewUrl="http://localhost:3000",
      ~createdAt=1000.0,
    )
    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)

    let state = TestHelpers.makeStateWithTasks(~tasks, ~currentTask=Task.Selected("task-1"))

    let (state1, effects1) = Reducer.addUserMessageToState(
      state,
      ~sessionId="session",
      {
        id: testUserMessageId,
        content: [UserContentPart.Text({text: "Message in task 1"})],
        annotations: [],
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )

    let (_state2, effects2) = Reducer.addUserMessageToState(
      state1,
      ~sessionId="session",
      {
        id: secondTestUserMessageId,
        content: [UserContentPart.Text({text: "Second message"})],
        annotations: [],
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )

    switch (effects1->Array.get(0), effects2->Array.get(0)) {
    | (
        Some(Reducer.SendMessage({taskId: taskId1})),
        Some(Reducer.SendMessage({taskId: taskId2})),
      ) =>
      t->expect(taskId1)->Expect.toBe(taskId2)
    | _ => t->expect("Both effects should have task IDs")->Expect.toBe("Missing task IDs")
    }
  })
})

describe("Client State Reducer - Billing Settings", () => {
  let parseBillingStatus = json =>
    JSON.parseOrThrow(json)->S.decodeOrThrow(~from=S.json, ~to=Client__Billing.statusSchema)

  test(
    "keeps the draft through reconnect, canceled checkout, activation and provider setup without sending",
    t => {
      let reduce = (state, action) => Reducer.next(state, action)->Pair.first
      let drafted = reduce(Reducer.defaultState, SetComposerDraft("Fix mobile signup"))
      let gated = reduce(reduce(drafted, ConnectionAction(Dispose)), ContinueActivation)
      t->expect(gated.settingsModalTab)->Expect.toEqual(Some(Activation))
      let canceled = reduce(gated, BillingRequestCancelled({tab: None}))
      let status = parseBillingStatus(`{"status":"active","access_allowed":true,"has_billing_customer":true,"interval":"monthly","current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`)
      let (active, effects) = Reducer.next(canceled, BillingStatusReceived(status))
      t->expect(effects)->Expect.toEqual([Reducer.TrackActivation("access_activated")])
      t->expect(active.settingsModalTab)->Expect.toEqual(Some(Activation))
      t
      ->expect(reduce(active, ContinueActivation).settingsModalTab)
      ->Expect.toEqual(Some(ProviderSetup))
      let ready = {
        ...active,
        selectedModelValue: Some("model"),
        configOptions: Some(TestHelpers.modelConfigOptions(~models=["model"])),
      }
      let (finished, effects) = Reducer.next(ready, ContinueActivation)
      t->expect(finished.composerDraft)->Expect.toBe("Fix mobile signup")
      t->expect(finished.settingsModalTab)->Expect.toBeNone
      t
      ->expect(effects)
      ->Expect.toEqual([Reducer.TrackActivation("setup_completed"), Reducer.FocusComposer])
      let (_, duplicateEffects) = Reducer.next(finished, BillingStatusReceived(status))
      t->expect(duplicateEffects)->Expect.toEqual([])
    },
  )

  test("SetSettingsModalTab(Billing) only opens the tab", t => {
    let state: Reducer.state = {
      ...Reducer.defaultState,
      billingStatus: Client__Billing.NotLoaded,
    }

    let (nextState, effects) = Reducer.next(
      state,
      SetSettingsModalTab({tab: Some(Client__State__Types.Billing)}),
    )

    t->expect(nextState.settingsModalTab)->Expect.toEqual(Some(Client__State__Types.Billing))
    t->expect(nextState.billingStatus)->Expect.toEqual(Client__Billing.NotLoaded)
    t->expect(effects->Array.length)->Expect.toBe(0)
  })

  test("billing launch results schedule navigation and cleanup without executing them", t => {
    let tab = WebAPI.Window.current
    let state: Reducer.state = {
      ...Reducer.defaultState,
      billingFlow: Opening,
      connection: Client__ConnectionTestHelpers.ready(),
    }
    let url = "https://billing.stripe.test/session"
    let cases: array<(Reducer.action, Client__Billing.flow, array<Reducer.effect>)> = [
      (
        BillingUrlReceived({tab, url, request: CustomerPortal}),
        Idle,
        [NavigateBillingTab({tab, url})],
      ),
      (
        BillingLaunchFailed({tab: Some(tab), error: "Unavailable"}),
        Failed("Unavailable"),
        [CloseBillingTab(Some(tab))],
      ),
      (
        BillingAuthRequired({tab: Some(tab)}),
        Idle,
        [CloseBillingTab(Some(tab)), RequireBillingAuthentication],
      ),
      (BillingRequestCancelled({tab: Some(tab)}), Opening, [CloseBillingTab(Some(tab))]),
    ]
    cases->Array.forEach(
      ((action, flow, expectedEffects)) => {
        let (updated, effects) = Reducer.next(state, action)
        t->expect(updated.billingFlow)->Expect.toEqual(flow)
        t->expect(effects)->Expect.toEqual(expectedEffects)
      },
    )
  })

  test("BillingStatusReceived stores global billing status", t => {
    let billingStatus = parseBillingStatus(`{
      "status": "active",
      "access_allowed": true,
      "has_billing_customer": true,
      "interval": "monthly",
      "current_period_end": null,
      "trial_end": null,
      "cancel_at": null,
      "canceled_at": null
    }`)

    let (nextState, effects) = Reducer.next(
      Reducer.defaultState,
      BillingStatusReceived(billingStatus),
    )

    t
    ->expect(nextState.billingStatus)
    ->Expect.toEqual(Client__Billing.Loaded(billingStatus))
    t->expect(effects->Array.length)->Expect.toBe(0)
  })

  test("BillingStatusReceived updates inactive billing to active", t => {
    let inactiveStatus = parseBillingStatus(`{
      "status": "none",
      "access_allowed": false,
      "has_billing_customer": false,
      "interval": null,
      "current_period_end": null,
      "trial_end": null,
      "cancel_at": null,
      "canceled_at": null
    }`)
    let activeStatus = parseBillingStatus(`{
      "status": "active",
      "access_allowed": true,
      "has_billing_customer": true,
      "interval": "monthly",
      "current_period_end": null,
      "trial_end": null,
      "cancel_at": null,
      "canceled_at": null
    }`)

    let (inactiveState, inactiveEffects) = Reducer.next(
      Reducer.defaultState,
      BillingStatusReceived(inactiveStatus),
    )
    let (activeState, activeEffects) = Reducer.next(
      inactiveState,
      BillingStatusReceived(activeStatus),
    )

    t->expect(Reducer.Selectors.billingAccessAllowed(inactiveState))->Expect.toBe(false)
    t->expect(Reducer.Selectors.billingAccessAllowed(activeState))->Expect.toBe(true)
    t->expect(inactiveEffects->Array.length)->Expect.toBe(0)
    t->expect(activeEffects->Array.length)->Expect.toBe(0)
  })

  test("billingAccessAllowed selector returns derived billing access", t => {
    let activeStatus = parseBillingStatus(`{
      "status": "active",
      "access_allowed": true,
      "has_billing_customer": true,
      "interval": null,
      "current_period_end": null,
      "trial_end": null,
      "cancel_at": null,
      "canceled_at": null
    }`)
    let inactiveStatus = parseBillingStatus(`{
      "status": "none",
      "access_allowed": false,
      "has_billing_customer": false,
      "interval": null,
      "current_period_end": null,
      "trial_end": null,
      "cancel_at": null,
      "canceled_at": null
    }`)

    t
    ->expect(
      Reducer.Selectors.billingAccessAllowed({
        ...Reducer.defaultState,
        billingStatus: Client__Billing.Loaded(activeStatus),
      }),
    )
    ->Expect.toBe(true)

    t
    ->expect(
      Reducer.Selectors.billingAccessAllowed({
        ...Reducer.defaultState,
        billingStatus: Client__Billing.Loaded(inactiveStatus),
      }),
    )
    ->Expect.toBe(false)

    t
    ->expect(
      Reducer.Selectors.billingAccessAllowed({
        ...Reducer.defaultState,
        billingStatus: Client__Billing.NotLoaded,
      }),
    )
    ->Expect.toBe(false)

    t
    ->expect(
      Reducer.Selectors.billingAccessAllowed({
        ...Reducer.defaultState,
        billingStatus: Client__Billing.Error("boom"),
      }),
    )
    ->Expect.toBe(false)
  })

  test("clearing the session clears billing state and settings", t => {
    let state = {
      ...Reducer.defaultState,
      settingsModalTab: Some(StateTypes.Billing),
      billingStatus: Client__Billing.Error("old account"),
    }
    let (nextState, _) = Reducer.next(state, ConnectionAction(Dispose))
    t->expect(nextState.settingsModalTab)->Expect.toEqual(None)
    t->expect(nextState.billingStatus)->Expect.toEqual(Client__Billing.NotLoaded)
  })
})

describe("Client State Reducer - Session Loading Actions", () => {
  test("SessionsLoadStarted transitions to Loading state", t => {
    let state = Reducer.defaultState

    let (nextState, _effects) = Reducer.next(state, SessionsLoadStarted)

    t->expect(nextState.sessionsLoadState)->Expect.toEqual(Client__State__Types.SessionsLoading)
  })

  test("SessionsLoadSuccess adds sessions to tasks dict", t => {
    let state = Reducer.defaultState

    let sessions: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionSummary> = [
      {
        sessionId: "session-1",
        title: "First Session",
        createdAt: "2024-01-15T10:00:00Z",
        updatedAt: "2024-01-15T10:30:00Z",
      },
      {
        sessionId: "session-2",
        title: "Second Session",
        createdAt: "2024-01-15T11:00:00Z",
        updatedAt: "2024-01-15T11:30:00Z",
      },
    ]

    let (nextState, _effects) = Reducer.next(state, SessionsLoadSuccess({sessions: sessions}))

    t->expect(nextState.sessionsLoadState)->Expect.toEqual(Client__State__Types.SessionsLoaded)

    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(2)

    t->expect(nextState.tasks->Dict.has("session-1"))->Expect.toBe(true)
    t->expect(nextState.tasks->Dict.has("session-2"))->Expect.toBe(true)

    let task1 = nextState.tasks->Dict.get("session-1")->Option.getOrThrow
    t->expect(Task.getTitle(task1))->Expect.toEqual(Some("First Session"))

    let task2 = nextState.tasks->Dict.get("session-2")->Option.getOrThrow
    t->expect(Task.getTitle(task2))->Expect.toEqual(Some("Second Session"))
  })

  test("SessionsLoadSuccess does not overwrite existing tasks", t => {
    let existingTask = TestHelpers.makeLoadedTask(
      ~id="session-1",
      ~title="Existing Task",
      ~previewUrl="http://localhost:3000",
      ~createdAt=1000.0,
      ~messages=[
        Reducer.Message.User({
          id: "user-1",
          content: [UserContentPart.Text({text: "Existing message"})],
          annotations: [],
          agentId: "executor-id",
        }),
      ],
    )

    let tasks = Dict.make()
    tasks->Dict.set("session-1", existingTask)

    let state = TestHelpers.makeStateWithTasks(~tasks, ~currentTask=Task.Selected("task-1"))

    let sessions: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionSummary> = [
      {
        sessionId: "session-1",
        title: "Should Not Overwrite",
        createdAt: "2024-01-15T10:00:00Z",
        updatedAt: "2024-01-15T10:30:00Z",
      },
      {
        sessionId: "session-2",
        title: "New Session",
        createdAt: "2024-01-15T11:00:00Z",
        updatedAt: "2024-01-15T11:30:00Z",
      },
    ]

    let (nextState, _effects) = Reducer.next(state, SessionsLoadSuccess({sessions: sessions}))

    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(2)

    let task1 = nextState.tasks->Dict.get("session-1")->Option.getOrThrow
    t->expect(Task.getTitle(task1))->Expect.toEqual(Some("Existing Task"))
    let task1Messages = Task.getMessages(task1)
    t
    ->expect(task1Messages->Array.some(msg => Reducer.Message.getId(msg) == "user-1"))
    ->Expect.toBe(true)

    let task2 = nextState.tasks->Dict.get("session-2")->Option.getOrThrow
    t->expect(Task.getTitle(task2))->Expect.toEqual(Some("New Session"))
  })

  test("SessionsLoadError transitions to error state with message", t => {
    let state: Reducer.state = {
      ...Reducer.defaultState,
      sessionsLoadState: Client__State__Types.SessionsLoading,
    }

    let (nextState, _effects) = Reducer.next(
      state,
      SessionsLoadError({error: "Network request failed"}),
    )

    t
    ->expect(nextState.sessionsLoadState)
    ->Expect.toEqual(Client__State__Types.SessionsLoadError("Network request failed"))
  })

  test("SessionsLoadSuccess handles empty sessions array", t => {
    let state = Reducer.defaultState

    let (nextState, _effects) = Reducer.next(state, SessionsLoadSuccess({sessions: []}))

    t->expect(nextState.sessionsLoadState)->Expect.toEqual(Client__State__Types.SessionsLoaded)
    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(0)
  })
})

describe("Client State Reducer - UpdateTaskTitle safety", () => {
  test("UpdateTaskTitle updates title for existing task", t => {
    let state = TestHelpers.makeStateWithTask(~taskId="task-1", ~messages=[])
    let (nextState, _) = Reducer.next(
      state,
      UpdateTaskTitle({taskId: "task-1", title: "New Title"}),
    )

    let task = nextState.tasks->Dict.get("task-1")->Option.getOrThrow
    t->expect(Task.getTitle(task))->Expect.toEqual(Some("New Title"))
  })

  test("UpdateTaskTitle on deleted task does not throw", t => {
    let state = TestHelpers.makeStateWithTask(~taskId="task-1", ~messages=[])

    let (stateAfterDelete, _) = Reducer.next(state, DeleteTask({taskId: "task-1"}))
    t->expect(TestHelpers.getTaskCount(stateAfterDelete))->Expect.toBe(0)

    let (nextState, _) = Reducer.next(
      stateAfterDelete,
      UpdateTaskTitle({taskId: "task-1", title: "Ghost Title"}),
    )

    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(0)
    t->expect(nextState.tasks->Dict.get("task-1")->Option.isNone)->Expect.toBe(true)
  })

  test("UpdateTaskTitle on non-existent task is a no-op", t => {
    let state = TestHelpers.makeStateWithTask(~taskId="task-1", ~messages=[])

    let (nextState, _) = Reducer.next(
      state,
      UpdateTaskTitle({taskId: "non-existent-task", title: "Should Not Crash"}),
    )

    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(1)
    let task = nextState.tasks->Dict.get("task-1")->Option.getOrThrow
    t->expect(Task.getTitle(task))->Expect.toEqual(Some("Test Task"))
  })
})

module MessageAnnotation = Client__Message.MessageAnnotation

describe("Client State Reducer - Annotations on Messages", () => {
  let _sampleAnnotations: array<MessageAnnotation.t> = [
    {
      id: "ann-1",
      selector: Ok(Some(".btn-submit")),
      elementContext: Ok(None),
      tagName: "button",
      cssClasses: Some("btn-submit primary"),
      comment: Some("This button is broken"),
      screenshot: Ok(None),
      sourceLocation: Ok(None),
      boundingBox: None,
      nearbyText: Some("Submit"),
      elementorContext: None,
    },
    {
      id: "ann-2",
      selector: Ok(Some("div.header")),
      elementContext: Ok(None),
      tagName: "div",
      cssClasses: Some("header"),
      comment: None,
      screenshot: Ok(None),
      sourceLocation: Ok(None),
      boundingBox: None,
      nearbyText: Some("Welcome"),
      elementorContext: None,
    },
  ]

  test("UserMessageReceived with annotations stores them on the message", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}
    let (state, _) = Reducer.addUserMessageToState(
      state,
      ~sessionId="session-1",
      {
        id: testUserMessageId,
        content: [UserContentPart.text("Fix this")],
        annotations: _sampleAnnotations,
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )
    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow

    let nextState = TestHelpers.acceptUserMessage(
      state,
      ~taskId,
      ~id=testUserMessageId->UserMessageId.toString,
      ~content=[UserContentPart.text("Fix this")],
      ~annotations=_sampleAnnotations,
    )

    let messages = Reducer.Selectors.queuedUserMessages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(1)

    switch messages->Array.get(0)->Option.getOrThrow {
    | Reducer.Message.User({annotations, _}) =>
      t->expect(annotations->Array.length)->Expect.toBe(2)
      t->expect((annotations->Array.getUnsafe(0)).id)->Expect.toBe("ann-1")
      t->expect((annotations->Array.getUnsafe(0)).tagName)->Expect.toBe("button")
      t
      ->expect((annotations->Array.getUnsafe(0)).comment)
      ->Expect.toEqual(Some("This button is broken"))
      t->expect((annotations->Array.getUnsafe(1)).id)->Expect.toBe("ann-2")
    | _ => JsExn.throw("Expected User message")
    }
  })

  test("UserMessageReceived with only annotations creates valid message", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}
    let (state, _) = Reducer.addUserMessageToState(
      state,
      ~sessionId="session-1",
      {
        id: testUserMessageId,
        content: [],
        annotations: _sampleAnnotations,
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )
    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow

    let nextState = TestHelpers.acceptUserMessage(
      state,
      ~taskId,
      ~id=testUserMessageId->UserMessageId.toString,
      ~content=[],
      ~annotations=_sampleAnnotations,
    )

    let messages = Reducer.Selectors.queuedUserMessages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(1)

    switch messages->Array.get(0)->Option.getOrThrow {
    | Reducer.Message.User({content, annotations, _}) =>
      t->expect(content->Array.length)->Expect.toBe(0)
      t->expect(annotations->Array.length)->Expect.toBe(2)
    | _ => JsExn.throw("Expected User message")
    }
  })

  test("UserMessageReceived without annotations stores empty array", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}
    let (state, _) = Reducer.addUserMessageToState(
      state,
      ~sessionId="session-1",
      {
        id: testUserMessageId,
        content: [UserContentPart.text("Hello")],
        annotations: [],
        agentId: "executor-id",
        onComplete: _ => (),
      },
    )
    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow

    let nextState = TestHelpers.acceptUserMessage(
      state,
      ~taskId,
      ~id=testUserMessageId->UserMessageId.toString,
    )

    let messages = Reducer.Selectors.queuedUserMessages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(1)
    switch messages->Array.get(0)->Option.getOrThrow {
    | Reducer.Message.User({annotations, _}) => t->expect(annotations->Array.length)->Expect.toBe(0)
    | _ => JsExn.throw("Expected User message")
    }
  })

  test("active sessions send chatbox and annotation drafts directly without preparation", t => {
    setRuntime(JSON.parseOrThrow(`{"framework":"nextjs"}`))
    let annotation = {
      ...Client__Annotation__Types.make(
        ~element=WebAPI.DomGlobal.document->WebAPI.Document.createElement("button"),
        ~tagName="button",
      ),
      id: "ann-1",
      enrichmentStatus: Enriched,
    }
    let state = {
      ...TestHelpers.makeStateWithTask(),
      selectedAgentId: Some("executor-id"),
      connection: Client__ConnectionTestHelpers.ready(~sessionId=Some("test-task-1")),
    }->Reducer.Lens.updateTask(
      "test-task-1",
      task => TaskReducer.Lens.setAnnotations(task, [annotation, {...annotation, id: "ann-2"}]),
    )
    [None, Some("ann-1")]->Array.forEach(
      annotationId => {
        let (nextState, effects) = Reducer.next(
          state,
          AddUserMessage({
            content: [UserContentPart.text("Fix this")],
            annotationId,
            onComplete: _ => (),
          }),
        )
        t->expect(Reducer.Selectors.isSubmitting(nextState))->Expect.toBe(false)
        t->expect(Reducer.Selectors.annotations(nextState))->Expect.toEqual([])
        switch effects {
        | [Reducer.SendMessage({taskId, submission: {annotations, agentId}})] =>
          t->expect(taskId)->Expect.toBe("test-task-1")
          t->expect(agentId)->Expect.toBe("executor-id")
          t->expect(annotations->Array.length)->Expect.toBe(annotationId->Option.isSome ? 1 : 2)
          t->expect((annotations->Array.getUnsafe(0)).id)->Expect.toBe("ann-1")
        | _ => failwith("Expected only a direct SendMessage effect")
        }
      },
    )
  })

  test("AddUserMessage rejects without a selected model and leaves the draft unchanged", t => {
    setRuntime(JSON.parseOrThrow(`{"framework":"nextjs"}`))
    let result = ref(None)
    let state = {
      ...Reducer.defaultState,
      connection: Client__ConnectionTestHelpers.ready(),
      selectedAgentId: Some("executor-id"),
      selectedModelValue: None,
    }
    let (nextState, effects) = Reducer.next(
      state,
      Reducer.AddUserMessage({
        content: [UserContentPart.text("Fix this")],
        annotationId: None,
        onComplete: value => result := Some(value),
      }),
    )
    effects->Array.forEach(effect => Reducer.handleEffect(effect, nextState, _ => ()))
    t->expect(nextState)->Expect.toEqual(state)
    t->expect(result.contents->Option.getOrThrow->Result.isError)->Expect.toBe(true)
  })

  test(
    "session creation revalidates the model, locks the draft and rejects stale completion",
    t => {
      setRuntime(JSON.parseOrThrow(`{"framework":"nextjs","basePath":"frontman"}`))
      let created = ref(0)
      let completion = ref(None)
      let configOptions = ref(None)
      let sent = []
      mockPrompt(
        (_, text, ~additionalBlocks as _, ~_meta as _) => {
          sent->Array.push(text)
          Promise.make((_, _) => ())
        },
      )
      let result = ref(None)
      let handleEffect = (effect: Reducer.effect, state, dispatch) =>
        switch effect {
        | ConnectionEffect(ActivateSessionEffect({requestId, operation: #create(sessionId)})) =>
          created := created.contents + 1
          completion :=
            Some(
              () =>
                dispatch(
                  Reducer.ConnectionAction(
                    SessionResultReceived({
                      requestId,
                      sessionId,
                      result: Ok((
                        Client__ConnectionTestHelpers.session(sessionId),
                        configOptions.contents,
                      )),
                    }),
                  ),
                ),
            )
        | _ => Reducer.handleEffect(effect, state, dispatch)
        }
      let store = Client__ConnectionTestHelpers.makeStore(
        {
          ...Reducer.defaultState,
          selectedAgentId: Some("executor-id"),
          selectedModelValue: Some("test:model"),
          connection: Client__ConnectionTestHelpers.ready(),
        },
        handleEffect,
      )
      let submit = content =>
        store->StateStore.dispatch(
          AddUserMessage({content, annotationId: None, onComplete: value => result := Some(value)}),
        )
      let text = [UserContentPart.text("draft")]
      submit(text)
      let creating = store->StateStore.getState
      let draft = Reducer.Selectors.currentTask(creating)
      let deletionIds = ["unrelated-task", Reducer.Selectors.currentTaskClientId(creating)]
      deletionIds->Array.forEach(
        taskId => {
          let (deleted, deletionEffects) = Reducer.next(
            creating,
            Reducer.DeleteTask({taskId: taskId}),
          )
          t
          ->expect(Reducer.Selectors.isSubmitting(deleted))
          ->Expect.toBe(taskId == "unrelated-task")
          t
          ->expect(
            deletionEffects->Array.some(
              effect =>
                switch effect {
                | ConnectionEffect(NotifyRequestRejected(_)) => true
                | _ => false
                },
            ),
          )
          ->Expect.toBe(taskId != "unrelated-task")
        },
      )
      store->StateStore.dispatch(TaskAction({target: CurrentTask, action: ToggleAnnotationMode}))
      t->expect(store->StateStore.getState->Reducer.Selectors.currentTask)->Expect.toEqual(draft)
      submit(text)
      t->expect(created.contents)->Expect.toBe(1)
      configOptions := Some(TestHelpers.modelConfigOptions(~models=[]))
      result := None
      (completion.contents->Option.getOrThrow)()
      t->expect(result.contents)->Expect.toEqual(Some(Error("Select a model before sending.")))
      t->expect(store->StateStore.getState->Reducer.Selectors.isNewTask)->Expect.toBe(true)
      configOptions := None
      store->StateStore.dispatch(SetSelectedModelValue({value: "test:model"}))
      store->StateStore.dispatch(ClearCurrentTask)
      submit(text)
      let staleCompletion = completion.contents->Option.getOrThrow
      store->StateStore.dispatch(ClearCurrentTask)
      t->expect(result.contents->Option.getOrThrow->Result.isError)->Expect.toBe(true)
      submit([
        UserContentPart.Image({
          id: Some("image"),
          image: "data:image/png;base64,AAAA",
          mediaType: Some("image/png"),
          name: Some("image.png"),
        }),
      ])
      let taskId = store->StateStore.getState->Reducer.Selectors.currentTaskClientId
      staleCompletion()
      t->expect(store->StateStore.getState->Reducer.Selectors.isSubmitting)->Expect.toBe(true)
      t->expect(sent)->Expect.toEqual([])
      (completion.contents->Option.getOrThrow)()
      t->expect(result.contents)->Expect.toEqual(Some(Ok()))
      t->expect(sent)->Expect.toEqual([""])
      t
      ->expect(store->StateStore.getState->Reducer.Selectors.currentTaskId)
      ->Expect.toEqual(Some(taskId))
      submit(text)
      t->expect(result.contents)->Expect.toEqual(Some(Ok()))
      t->expect(sent)->Expect.toEqual(["", "draft"])
      t
      ->expect(store->StateStore.getState->Reducer.Selectors.queuedUserMessages->Array.length)
      ->Expect.toBe(2)
      t->expect(created.contents)->Expect.toBe(3)
      store->StateStore.dispatch(ClearCurrentTask)
      submit(text)
      configOptions := Some(TestHelpers.modelConfigOptions(~models=["replacement:model"]))
      let unsubscribe = subscribe(
        store,
        () => {
          let state = store->StateStore.getState
          switch Reducer.Selectors.getSession(state) {
          | Some(_) if state.selectedModelValue == Some("replacement:model") =>
            store->StateStore.dispatch(ClearCurrentTask)
          | _ => ()
          }
        },
      )
      (completion.contents->Option.getOrThrow)()
      unsubscribe()
      t->expect(result.contents->Option.getOrThrow->Result.isError)->Expect.toBe(true)
      t->expect(sent)->Expect.toEqual(["", "draft"])
    },
  )

  test("buildPrompt includes fresh routing metadata only for Astro previews", t => {
    let enabledDocument =
      WebAPI.DomGlobal.document.implementation->WebAPI.DOMImplementation.createHTMLDocument(
        ~title="",
      )
    enabledDocument.head.innerHTML = "<meta name=\"astro-view-transitions-enabled\" content=\"true\">"
    let disabledDocument =
      WebAPI.DomGlobal.document.implementation->WebAPI.DOMImplementation.createHTMLDocument(
        ~title="",
      )
    [
      ("astro", Some(enabledDocument), Some("enabled")),
      ("astro", Some(disabledDocument), Some("disabled")),
      ("astro", None, Some("unavailable")),
      ("nextjs", Some(enabledDocument), None),
      ("vite", Some(enabledDocument), None),
      ("wordpress", Some(enabledDocument), None),
    ]->Array.forEach(
      ((framework, contentDocument, expected)) => {
        setRuntime(
          {"framework": framework}->S.decodeOrThrow(
            ~from=S.object(s => {"framework": s.field("framework", S.string)}),
            ~to=S.json,
          ),
        )
        let state = TestHelpers.makeStateWithTask()
        let task =
          Reducer.Selectors.currentTask(state)->TaskReducer.Lens.setPreviewFrame(
            ~contentDocument,
            ~contentWindow=None,
          )
        let (blocks, _) = Reducer.buildPrompt(
          state,
          ~task,
          ~messageId=UserMessageId.make(),
          ~attachments=[],
          ~annotations=[],
          ~agentId="planner-id",
        )
        switch blocks->Array.get(0) {
        | Some(ContentBlock.EmbeddedResource({_meta: Some(meta)})) =>
          let metadata = S.parseOrThrow(meta, ~to=pageRoutingMetaSchema)
          t->expect(metadata.astro_client_routing)->Expect.toEqual(expected)
        | _ => JsExn.throw("Expected current-page metadata in the submitted prompt")
        }
      },
    )
  })

  testAsync("SendMessage forwards the prompt and settles only its owner's failed send", async t => {
    setRuntime(JSON.parseOrThrow(`{"framework":"nextjs","basePath":"frontman"}`))
    let messageId = UserMessageId.make()
    let completion = Promise.withResolvers()
    let dispatched = []
    let state = {
      ...Reducer.defaultState,
      selectedModelValue: Some("test:model"),
      connection: Client__ConnectionTestHelpers.ready(~sessionId=Some("session-1")),
    }
    let (state, effects) = Reducer.addUserMessageToState(
      state,
      ~sessionId="session-1",
      {
        id: messageId,
        content: [UserContentPart.text("Fix this")],
        annotations: [],
        agentId: "planner-id",
        onComplete: _ => (),
      },
    )
    mockPrompt(
      (session, text, ~additionalBlocks, ~_meta) => {
        t->expect((session.sessionId, text))->Expect.toEqual(("session-1", "Fix this"))
        let metadata = S.parseOrThrow(
          _meta->Option.getOrThrow,
          ~to=S.object(
            s => (
              s.field("frontman.dev/messageId", S.string),
              s.field("agent", S.string),
              s.field("model", S.string),
            ),
          ),
        )
        t
        ->expect(metadata)
        ->Expect.toEqual((UserMessageId.toString(messageId), "planner-id", "test:model"))
        t
        ->expect(additionalBlocks)
        ->Expect.toEqual(
          StateTypes.taskToPageContextBlocks(Reducer.Selectors.currentTask(state), ~isAstro=false),
        )
        completion.promise
      },
    )
    t->expect(Reducer.Selectors.queuedUserMessages(state)->Array.length)->Expect.toBe(1)
    effects->Array.forEach(
      effect => Reducer.handleEffect(effect, state, action => dispatched->Array.push(action)),
    )
    completion.resolve(
      Error(Client__ConnectionReducer.ACP.requestErrorFromMessage("Connection lost")),
    )
    let _ = await completion.promise

    switch dispatched {
    | [Reducer.PromptFailed({taskId: "session-1", id, error}) as failure] => {
        t->expect(id)->Expect.toEqual(messageId)
        t
        ->expect(Client__ConnectionReducer.ACP.requestErrorMessage(error))
        ->Expect.toBe("Connection lost")
        let fail = state => Reducer.next(state, failure)->Pair.first
        t->expect(fail(state)->Reducer.Selectors.queuedUserMessages)->Expect.toEqual([])
        let connection = state.connection->Option.getOrThrow
        let runtime = connection.connection->Result.getOrThrow->Option.getOrThrow
        let lost =
          Reducer.next(
            state,
            ConnectionAction(ACPReconnecting({signal: runtime.lifetimeAbortController.signal})),
          )->Pair.first
        t->expect(fail(lost)->Reducer.Selectors.queuedUserMessages)->Expect.toEqual([])
        let newer = {
          ...state,
          connection: Client__ConnectionTestHelpers.ready(~sessionId=Some("session-1")),
        }
        t->expect(fail(newer))->Expect.toBe(newer)
      }
    | _ => JsExn.throw("Expected targeted PromptFailed action")
    }
  })

  describe("API key provider actions", () => {
    let _makeStateWithSession = () => {
      {
        ...Reducer.defaultState,
        connection: Client__ConnectionTestHelpers.ready(),
        selectedModelValue: None,
      }
    }

    let _providerCases: array<(Reducer.apiKeyProvider, string)> = [
      (OpenRouter, "openrouter"),
      (Anthropic, "anthropic"),
      (Fireworks, "fireworks_ai"),
      (Nvidia, "nvidia"),
    ]

    let _settingsForProvider = (
      state: Client__State__Types.state,
      provider: Reducer.apiKeyProvider,
    ) =>
      switch provider {
      | OpenRouter => state.openrouterKeySettings
      | Anthropic => state.anthropicKeySettings
      | Fireworks => state.fireworksKeySettings
      | Nvidia => state.nvidiaKeySettings
      }

    test(
      "FetchApiKeySettings queues the key metadata effect",
      t => {
        let (_nextState, effects) = Reducer.next(_makeStateWithSession(), FetchApiKeySettings)

        t->expect(effects->Array.length)->Expect.toBe(1)
        switch effects->Array.get(0) {
        | Some(FetchApiKeySettingsEffect({apiBaseUrl})) =>
          t->expect(apiBaseUrl)->Expect.toBe("http://localhost:4000")
        | _ => JsExn.throw("Expected FetchApiKeySettingsEffect")
        }
      },
    )

    test(
      "SaveApiKey queues the save effect and pending auto-select for each provider",
      t => {
        _providerCases->Array.forEach(
          ((provider, expectedProviderId)) => {
            let (nextState, effects) = Reducer.next(
              _makeStateWithSession(),
              SaveApiKey({provider, key: "sk-test-key"}),
            )

            t
            ->expect(nextState.pendingProviderAutoSelect)
            ->Expect.toEqual(Some(expectedProviderId))
            t->expect(effects->Array.length)->Expect.toBe(1)

            switch effects->Array.get(0) {
            | Some(SaveApiKeyEffect({apiBaseUrl, provider: effectProvider, key})) => {
                t->expect(apiBaseUrl)->Expect.toBe("http://localhost:4000")
                t->expect(effectProvider)->Expect.toEqual(provider)
                t->expect(key)->Expect.toBe("sk-test-key")
              }
            | _ => JsExn.throw("Expected SaveApiKeyEffect")
            }
          },
        )
      },
    )

    test(
      "API key save lifecycle updates only the targeted provider",
      t => {
        _providerCases->Array.forEach(
          ((provider, expectedProviderId)) => {
            let state = _makeStateWithSession()
            let (savingState, _effects) = Reducer.next(
              state,
              ApiKeySaveStarted({provider: provider}),
            )

            t
            ->expect(_settingsForProvider(savingState, provider).saveStatus)
            ->Expect.toEqual(Saving)

            let (savedState, effects) = Reducer.next(savingState, ApiKeySaved({provider: provider}))

            t
            ->expect(_settingsForProvider(savedState, provider).source)
            ->Expect.toEqual(UserOverride)
            t->expect(_settingsForProvider(savedState, provider).saveStatus)->Expect.toEqual(Saved)
            t->expect(effects->Array.length)->Expect.toBe(0)

            let (failedState, _effects) = Reducer.next(
              {...savingState, pendingProviderAutoSelect: Some(expectedProviderId)},
              ApiKeySaveError({provider, error: "boom"}),
            )

            t->expect(failedState.pendingProviderAutoSelect)->Expect.toEqual(None)
            t
            ->expect(_settingsForProvider(failedState, provider).saveStatus)
            ->Expect.toEqual(SaveError("boom"))

            let (resetState, _effects) = Reducer.next(
              failedState,
              ResetApiKeySaveStatus({provider: provider}),
            )
            t->expect(_settingsForProvider(resetState, provider).saveStatus)->Expect.toEqual(Idle)
          },
        )
      },
    )

    test(
      "SaveApiKey without ACP session sets provider-specific error",
      t => {
        _providerCases->Array.forEach(
          ((provider, _expectedProviderId)) => {
            let (nextState, effects) = Reducer.next(
              Reducer.defaultState,
              SaveApiKey({provider, key: "sk-test-key"}),
            )

            t->expect(effects->Array.length)->Expect.toBe(0)
            t
            ->expect(_settingsForProvider(nextState, provider).saveStatus)
            ->Expect.toEqual(SaveError("No active ACP session"))
          },
        )
      },
    )

    test(
      "ApiKeySettingsReceived updates only the targeted provider",
      t => {
        let (nextState, _effects) = Reducer.next(
          Reducer.defaultState,
          ApiKeySettingsReceived({provider: Anthropic, source: UserOverride}),
        )

        t->expect(nextState.openrouterKeySettings.source)->Expect.toEqual(Client__State__Types.None)
        t->expect(nextState.anthropicKeySettings.source)->Expect.toEqual(UserOverride)
        t->expect(nextState.fireworksKeySettings.source)->Expect.toEqual(Client__State__Types.None)
        t->expect(nextState.nvidiaKeySettings.source)->Expect.toEqual(Client__State__Types.None)
      },
    )

    test(
      "provider setup follows ACP model availability",
      t => {
        let sessionState = _makeStateWithSession()
        let emptyState = {
          ...sessionState,
          configOptions: Some(TestHelpers.modelConfigOptions(~models=[])),
        }
        let futureProviderState = {
          ...sessionState,
          configOptions: Some(TestHelpers.modelConfigOptions(~models=["future_provider:model"])),
        }

        t->expect(Reducer.Selectors.providerSetupRequired(Reducer.defaultState))->Expect.toBe(false)
        t->expect(Reducer.Selectors.providerSetupRequired(sessionState))->Expect.toBe(false)
        t->expect(Reducer.Selectors.providerSetupRequired(emptyState))->Expect.toBe(true)
        t->expect(Reducer.Selectors.providerSetupRequired(futureProviderState))->Expect.toBe(false)
      },
    )

    test(
      "updating an initialized ACP session preserves OAuth progress",
      t => {
        let authorizing: Client__State__Types.anthropicOAuthStatus = Authorizing({
          authorizeUrl: "https://example.com",
          verifier: "verifier",
        })
        let showingCode: Client__State__Types.openaiOAuthStatus = OpenAIShowingCode({
          deviceAuthId: "device-auth-id",
          userCode: "ABCD-EFGH",
          verificationUrl: "https://example.com/device",
        })
        let state = {
          ..._makeStateWithSession(),
          anthropicOAuthStatus: authorizing,
          openaiOAuthStatus: showingCode,
        }
        let (nextState, effects) = Reducer.next(state, ConnectionAction(ClearSession))

        t->expect(nextState.anthropicOAuthStatus)->Expect.toEqual(authorizing)
        t->expect(nextState.openaiOAuthStatus)->Expect.toEqual(showingCode)
        t->expect(effects->Array.length)->Expect.toBe(0)
      },
    )

    test(
      "initializing a new ACP session does not fetch provider settings",
      t => {
        let (nextState, effects) = Reducer.next(
          Reducer.defaultState,
          InitializeConnection(Client__ConnectionTestHelpers.config()),
        )
        t->expect(nextState.anthropicOAuthStatus)->Expect.toEqual(NotConnected)
        t->expect(nextState.openaiOAuthStatus)->Expect.toEqual(OpenAINotConnected)
        switch effects {
        | [ConnectionEffect(ConnectRuntime(_))] => ()
        | _ => failwith("Expected only connection initialization")
        }
      },
    )

    test(
      "clearing the ACP session invalidates loaded provider settings",
      t => {
        let state = _makeStateWithSession()
        let (nextState, _effects) = Reducer.next(state, ConnectionAction(Dispose))

        t->expect(Reducer.Selectors.hasActiveACPSession(nextState))->Expect.toBe(false)
      },
    )
  })
})
