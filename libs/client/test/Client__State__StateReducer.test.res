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

let setRuntime: JSON.t => unit = %raw(`function(value) { window.__frontmanRuntime = value }`)
let clearRuntime: unit => unit = %raw(`function() { delete window.__frontmanRuntime }`)

afterEach(() => clearRuntime())

module TestHelpers = {
  let activeAcpSession = (
    ~deleteSession=(_, ~onComplete as _) => (),
    ~requireAuthentication=() => (),
  ): Client__State__Types.acpSession => AcpSessionActive({
    sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _, ~_meta as _) => (),
    sendSessionCommand: _ => (),
    loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
    deleteSession,
    requireAuthentication,
    apiBaseUrl: "http://localhost:4000",
  })

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
    let state = {...Reducer.defaultState, acpSession: TestHelpers.activeAcpSession()}
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
    let state = {
      ...Reducer.defaultState,
      acpSession: TestHelpers.activeAcpSession(
        ~requireAuthentication=() => {
          requireAuthenticationCalled := true
        },
      ),
    }
    let (_fetchState, fetchEffects) = Reducer.next(state, Reducer.FetchCustomProviders)

    switch fetchEffects->Array.get(0) {
    | Some(effect) => Reducer.handleEffect(effect, state, _ => ())
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
        action => dispatched := Array.concat(dispatched.contents, [action]),
      )
    | None => JsExn.throw("Expected CustomProviderMutationEffect")
    }
    t->expect(requireAuthenticationCalled.contents)->Expect.toBe(true)
    switch dispatched.contents {
    | [Reducer.CustomProviderMutationFailed({operation, error})] => {
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
    let requireAuthentication = () => {
      requireAuthenticationCount := requireAuthenticationCount.contents + 1
    }
    let effects = [
      Reducer.FetchAnthropicOAuthStatusEffect({
        apiBaseUrl: "http://localhost:4000",
        requireAuthentication,
      }),
      Reducer.GetAnthropicOAuthUrlEffect({
        apiBaseUrl: "http://localhost:4000",
        requireAuthentication,
      }),
      Reducer.ExchangeAnthropicOAuthCodeEffect({
        apiBaseUrl: "http://localhost:4000",
        code: "code-123",
        verifier: "verifier-123",
        requireAuthentication,
      }),
      Reducer.DisconnectAnthropicOAuthEffect({
        apiBaseUrl: "http://localhost:4000",
        requireAuthentication,
      }),
      Reducer.FetchOpenAIOAuthStatusEffect({
        apiBaseUrl: "http://localhost:4000",
        requireAuthentication,
      }),
      Reducer.InitiateOpenAIDeviceAuthEffect({
        apiBaseUrl: "http://localhost:4000",
        requireAuthentication,
      }),
      Reducer.PollOpenAIDeviceAuthEffect({
        apiBaseUrl: "http://localhost:4000",
        deviceAuthId: "device-123",
        userCode: "user-code",
        requireAuthentication,
      }),
      Reducer.DisconnectOpenAIOAuthEffect({
        apiBaseUrl: "http://localhost:4000",
        requireAuthentication,
      }),
    ]

    effects->Array.forEach(effect => Reducer.handleEffect(effect, Reducer.defaultState, _ => ()))

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
  acpSession: TestHelpers.activeAcpSession(),
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
    | Some(Reducer.TaskEffect({
        target: ForTask("test-task-1"),
        effect: SendMessage({text, agentId, _}),
      })) => {
        t->expect(text)->Expect.toBe(Reducer.executePlanPrompt)
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
    let (submitting, _) = Reducer.next(
      state,
      AddUserMessage({
        id: testUserMessageId,
        sessionId: "test-task-1",
        content: [UserContentPart.text("Revise step one")],
        annotations: [],
        agentId: planner.id,
      }),
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
    let action = Reducer.AddUserMessage({
      id: testUserMessageId,
      sessionId: "session-1",
      content: [UserContentPart.text("Hello")],
      annotations: [],
      agentId: "executor-id",
    })

    let (nextState, effects) = Reducer.next(state, action)

    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(1)
    t->expect(TestHelpers.getCurrentTaskId(nextState)->Option.isSome)->Expect.toBe(true)

    let messages = Reducer.Selectors.messages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(0)

    switch effects->Array.get(0) {
    | Some(Reducer.TaskEffect({effect: SendMessage({agentId})})) =>
      t->expect(agentId)->Expect.toBe("executor-id")
    | _ => JsExn.throw("Expected SendMessage effect")
    }
  })

  test("messages maintain order", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}

    let (state, _) = Reducer.next(
      state,
      AddUserMessage({
        id: testUserMessageId,
        sessionId: "session-1",
        content: [UserContentPart.text("Hi")],
        annotations: [],
        agentId: "executor-id",
      }),
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

describe("Client State Reducer - First Task Feedback Dialog", () => {
  let firstTurnState = (~agentId="test-agent", ~sessionsLoadState=StateTypes.SessionsLoaded) => {
    ...TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.User({
          id: "user-1",
          content: [UserContentPart.text("Build something")],
          annotations: [],
          agentId,
        }),
        Reducer.Message.Assistant(Streaming({id: "assistant-1", textBuffer: "Done", agentId})),
      ],
    ),
    sessionsLoadState,
  }

  let reduce = (state, action) => Reducer.next(state, action)->Pair.first
  let stopTurnResult = (state, stopReason) => {
    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    Reducer.next(state, TaskExecutionStopped({taskId, stopReason}))
  }
  let stopTurn = (state, stopReason) => stopTurnResult(state, stopReason)->Pair.first
  let completeSuccessfulTurn = state => stopTurn(state, Some(ACP.EndTurn))
  let loadHistoryResult = state => Reducer.next(state, SessionsLoadSuccess({sessions: []}))
  let loadHistory = state => state->loadHistoryResult->Pair.first
  let expectOpen = (t, state, expected) =>
    t->expect(Reducer.Selectors.showFirstTaskFeedbackDialog(state))->Expect.toBe(expected)

  test("opens only after the first task's first successful turn", t => {
    expectOpen(t, firstTurnState()->stopTurn(Some(ACP.Refusal)), false)

    let (completedState, effects) = firstTurnState()->stopTurnResult(Some(ACP.EndTurn))
    expectOpen(t, completedState, true)
    t->expect(effects)->Expect.toEqual([TrackAnalyticsEffect(FirstTaskFeedbackDialogShown)])
  })

  test("waits for session history and only celebrates a new user", t => {
    let pendingState =
      firstTurnState(~sessionsLoadState=StateTypes.SessionsLoading)->completeSuccessfulTurn
    expectOpen(t, pendingState, false)

    let (loadedState, effects) = pendingState->loadHistoryResult
    expectOpen(t, loadedState, true)
    t->expect(effects)->Expect.toEqual([TrackAnalyticsEffect(FirstTaskFeedbackDialogShown)])

    let returningUserState = {...pendingState, tasks: pendingState.tasks->Dict.copy}
    returningUserState.tasks->Dict.set("previous-task", Task.makeNew(~previewUrl=""))
    expectOpen(t, returningUserState->loadHistory, false)

    let failedState = pendingState->reduce(SessionsLoadError({error: "unavailable"}))
    t->expect(failedState.firstTaskFeedbackDialogState)->Expect.toEqual(Dismissed)
  })

  test("rechecks queued prompts when session history arrives", t => {
    let queuedState =
      firstTurnState(~sessionsLoadState=StateTypes.SessionsLoading)->completeSuccessfulTurn
    let taskId = TestHelpers.getCurrentTaskId(queuedState)->Option.getOrThrow
    let (queuedState, _) = Reducer.next(
      queuedState,
      AddUserMessage({
        id: secondTestUserMessageId,
        sessionId: taskId,
        content: [UserContentPart.text("Second message")],
        annotations: [],
        agentId: "test-agent",
      }),
    )
    expectOpen(t, queuedState->loadHistory, false)
  })

  test("waits for planner execution before celebrating", t => {
    let plannedState =
      firstTurnState(~agentId=planner.id)->withPlanHandoffContext->completeSuccessfulTurn
    t->expect(Reducer.Selectors.showFirstTaskFeedbackDialog(plannedState))->Expect.toBe(false)

    let taskId = TestHelpers.getCurrentTaskId(plannedState)->Option.getOrThrow
    let executingState = plannedState->reduce(ExecutePendingPlan({id: secondTestUserMessageId}))
    let executingState = TestHelpers.acceptUserMessage(
      executingState,
      ~taskId,
      ~id=secondTestUserMessageId->UserMessageId.toString,
      ~content=[UserContentPart.text(Reducer.executePlanPrompt)],
    )
    let executingState =
      executingState->reduce(TaskAction({target: ForTask(taskId), action: ExecutionStateRunning}))
    let executingState = executingState->reduce(
      TaskAction({
        target: ForTask(taskId),
        action: TextDeltaReceived({
          messageId: "assistant-executor",
          text: "Done",
          agentId: executor.id,
        }),
      }),
    )
    expectOpen(t, executingState->completeSuccessfulTurn, true)
  })

  test("tracks close through the reducer", t => {
    let visibleState = firstTurnState()->completeSuccessfulTurn
    let (closedState, effects) = Reducer.next(visibleState, CloseFirstTaskFeedbackDialog)

    t->expect(closedState.firstTaskFeedbackDialogState)->Expect.toEqual(Dismissed)
    t->expect(effects)->Expect.toEqual([TrackAnalyticsEffect(FirstTaskFeedbackDialogClosed)])
  })

  test("keeps failed sharing visible and retryable", t => {
    let visibleState = firstTurnState()->completeSuccessfulTurn
    let failedState = visibleState->reduce(ShareFrontmanFailed)
    let (_, retryEffects) = Reducer.next(failedState, ShareFrontman)

    expectOpen(t, failedState, true)
    t->expect(Reducer.Selectors.firstTaskFeedbackShareFailed(failedState))->Expect.toBe(true)
    t
    ->expect(retryEffects)
    ->Expect.toEqual([TrackAnalyticsEffect(FirstTaskFeedbackShareClicked), ShareFrontmanEffect])

    let copiedState = failedState->reduce(ShareFrontmanLinkCopied)
    t->expect(copiedState.firstTaskFeedbackDialogState)->Expect.toEqual(LinkCopied)
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

    let (state1, _effects1) = Reducer.next(
      state,
      AddUserMessage({
        id: testUserMessageId,
        sessionId: "sessionId",
        content: [UserContentPart.text("First message")],
        annotations: [],
        agentId: "executor-id",
      }),
    )

    let taskId1 = TestHelpers.getCurrentTaskId(state1)

    let (state2, _effects2) = Reducer.next(
      state1,
      AddUserMessage({
        id: secondTestUserMessageId,
        sessionId: "sessionId",
        content: [UserContentPart.text("Second message")],
        annotations: [],
        agentId: "executor-id",
      }),
    )

    let taskId2 = TestHelpers.getCurrentTaskId(state2)

    t->expect(taskId1->Option.isSome)->Expect.toBe(true)
    t->expect(taskId2->Option.isSome)->Expect.toBe(true)
    t->expect(taskId1)->Expect.toEqual(taskId2)
  })

  test("effect contains same task ID as state", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}

    let (state1, effects1) = Reducer.next(
      state,
      AddUserMessage({
        id: testUserMessageId,
        sessionId: "sessionId",
        content: [UserContentPart.text("First message")],
        annotations: [],
        agentId: "executor-id",
      }),
    )

    let taskIdInState = TestHelpers.getCurrentTaskId(state1)

    switch (effects1->Array.get(0), taskIdInState) {
    | (
        Some(Reducer.TaskEffect({target: ForTask(effectTaskId), effect: SendMessage(_)})),
        Some(stateTaskId),
      ) =>
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
      acpSession: TestHelpers.activeAcpSession(
        ~deleteSession=(taskId, ~onComplete as _) => deletedTaskId := Some(taskId),
      ),
    }
    let store = StateStore.make(module(Reducer), state)

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

    let (stateAfterMsg, effects) = Reducer.next(
      stateAfterDelete,
      AddUserMessage({
        id: secondTestUserMessageId,
        sessionId: "session-new",
        content: [UserContentPart.text("Hello after delete")],
        annotations: [],
        agentId: "executor-id",
      }),
    )

    t->expect(TestHelpers.getTaskCount(stateAfterMsg))->Expect.toBe(1)
    let newTaskId = TestHelpers.getCurrentTaskId(stateAfterMsg)->Option.getOrThrow
    t->expect(newTaskId)->Expect.not->Expect.toBe("task-1")

    let messages = Reducer.Selectors.messages(stateAfterMsg)
    t->expect(messages->Array.length)->Expect.toBe(0)

    switch effects->Array.get(0) {
    | Some(Reducer.TaskEffect({target: ForTask(effectTaskId), effect: SendMessage(_)})) =>
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

    let (state1, effects1) = Reducer.next(
      state,
      AddUserMessage({
        id: testUserMessageId,
        sessionId: "session",
        content: [UserContentPart.Text({text: "Message in task 1"})],
        annotations: [],
        agentId: "executor-id",
      }),
    )

    let (_state2, effects2) = Reducer.next(
      state1,
      AddUserMessage({
        id: secondTestUserMessageId,
        sessionId: "session",
        content: [UserContentPart.Text({text: "Second message"})],
        annotations: [],
        agentId: "executor-id",
      }),
    )

    switch (effects1->Array.get(0), effects2->Array.get(0)) {
    | (
        Some(Reducer.TaskEffect({target: ForTask(taskId1), effect: SendMessage(_)})),
        Some(Reducer.TaskEffect({target: ForTask(taskId2), effect: SendMessage(_)})),
      ) =>
      t->expect(taskId1)->Expect.toBe(taskId2)
    | _ => t->expect("Both effects should have task IDs")->Expect.toBe("Missing task IDs")
    }
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
    let (state, _) = Reducer.next(
      state,
      Reducer.AddUserMessage({
        id: testUserMessageId,
        sessionId: "session-1",
        content: [UserContentPart.text("Fix this")],
        annotations: _sampleAnnotations,
        agentId: "executor-id",
      }),
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
    let (state, _) = Reducer.next(
      state,
      Reducer.AddUserMessage({
        id: testUserMessageId,
        sessionId: "session-1",
        content: [],
        annotations: _sampleAnnotations,
        agentId: "executor-id",
      }),
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
    let (state, _) = Reducer.next(
      state,
      Reducer.AddUserMessage({
        id: testUserMessageId,
        sessionId: "session-1",
        content: [UserContentPart.text("Hello")],
        annotations: [],
        agentId: "executor-id",
      }),
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

  test("SendMessage effect carries annotations from AddUserMessage", t => {
    let state = {...Reducer.defaultState, selectedModelValue: Some("test:model")}
    let action = Reducer.AddUserMessage({
      id: testUserMessageId,
      sessionId: "session-1",
      content: [UserContentPart.text("Fix this")],
      annotations: _sampleAnnotations,
      agentId: "executor-id",
    })

    let (_nextState, effects) = Reducer.next(state, action)

    let sendEffect = effects->Array.find(
      eff =>
        switch eff {
        | Reducer.TaskEffect({effect: SendMessage(_)}) => true
        | _ => false
        },
    )

    switch sendEffect {
    | Some(Reducer.TaskEffect({effect: SendMessage({annotations})})) =>
      t->expect(annotations->Array.length)->Expect.toBe(2)
      t->expect((annotations->Array.getUnsafe(0)).id)->Expect.toBe("ann-1")
    | _ => JsExn.throw("Expected TaskEffect(SendMessage) with annotations")
    }
  })

  test("AddUserMessage does nothing without a selected model", t => {
    let state = {
      ...Reducer.defaultState,
      acpSession: TestHelpers.activeAcpSession(),
      selectedModelValue: None,
    }
    let (nextState, effects) = Reducer.next(
      state,
      Reducer.AddUserMessage({
        id: UserMessageId.make(),
        sessionId: "session-1",
        content: [UserContentPart.text("Fix this")],
        annotations: [],
        agentId: "planner-id",
      }),
    )

    t->expect(nextState)->Expect.toEqual(state)
    t->expect(effects)->Expect.toEqual([])
  })

  test("SendMessage metadata carries message ID, submission agent, and selected model", t => {
    setRuntime(JSON.parseOrThrow(`{"framework":"nextjs","basePath":"frontman"}`))
    let messageId = UserMessageId.make()
    let sentMetadata = ref(None)
    let state = {
      ...Reducer.defaultState,
      selectedModelValue: Some("anthropic:claude-opus-4-6"),
      acpSession: AcpSessionActive({
        sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _, ~_meta) => sentMetadata := _meta,
        sendSessionCommand: _ => (),
        loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
        deleteSession: (_, ~onComplete as _) => (),
        requireAuthentication: () => (),
        apiBaseUrl: "http://localhost:4000",
      }),
    }
    let (state, effects) = Reducer.next(
      state,
      Reducer.AddUserMessage({
        id: messageId,
        sessionId: "session-1",
        content: [UserContentPart.text("Fix this")],
        annotations: [],
        agentId: "planner-id",
      }),
    )

    effects->Array.forEach(effect => Reducer.handleEffect(effect, state, _ => ()))
    let metadata =
      sentMetadata.contents
      ->Option.getOrThrow
      ->JSON.Decode.object
      ->Option.getOrThrow

    t
    ->expect(metadata->Dict.get("frontman.dev/messageId")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some(messageId->UserMessageId.toString))
    t
    ->expect(metadata->Dict.get("agent")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("planner-id"))
    t
    ->expect(metadata->Dict.get("model")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("anthropic:claude-opus-4-6"))
  })

  test("SendMessage dispatches task cleanup when sendPrompt fails", t => {
    setRuntime(JSON.parseOrThrow(`{"framework":"nextjs","basePath":"frontman"}`))
    let messageId = UserMessageId.make()
    let completion = ref(None)
    let dispatched = ref([])
    let state = {
      ...Reducer.defaultState,
      selectedModelValue: Some("test:model"),
      acpSession: AcpSessionActive({
        sendPrompt: (_, ~additionalBlocks as _, ~onComplete, ~_meta as _) =>
          completion := Some(onComplete),
        sendSessionCommand: _ => (),
        loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
        deleteSession: (_, ~onComplete as _) => (),
        requireAuthentication: () => (),
        apiBaseUrl: "http://localhost:4000",
      }),
    }
    let (state, effects) = Reducer.next(
      state,
      Reducer.AddUserMessage({
        id: messageId,
        sessionId: "session-1",
        content: [UserContentPart.text("Fix this")],
        annotations: [],
        agentId: "executor-id",
      }),
    )

    effects->Array.forEach(
      effect =>
        Reducer.handleEffect(
          effect,
          state,
          action => dispatched := Array.concat(dispatched.contents, [action]),
        ),
    )
    let onComplete = completion.contents->Option.getOrThrow
    onComplete(Error("Connection lost"))

    switch dispatched.contents {
    | [
        Reducer.TaskAction({
          target: ForTask("session-1"),
          action: UserMessageSendFailed({id, error}),
        }),
      ] => {
        t->expect(id)->Expect.toEqual(messageId)
        t->expect(error)->Expect.toBe("Connection lost")
      }
    | _ => JsExn.throw("Expected targeted UserMessageSendFailed action")
    }
  })

  describe("API key provider actions", () => {
    let _makeStateWithSession = () => {
      {
        ...Reducer.defaultState,
        acpSession: TestHelpers.activeAcpSession(),
        selectedModelValue: None,
      }
    }

    let _setAcpSessionAction = (): Reducer.action => SetAcpSession({
      sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _, ~_meta as _) => (),
      sendSessionCommand: _ => (),
      loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
      deleteSession: (_, ~onComplete as _) => (),
      requireAuthentication: () => (),
      apiBaseUrl: "http://localhost:4000",
    })

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
        let (nextState, effects) = Reducer.next(state, _setAcpSessionAction())

        t->expect(nextState.anthropicOAuthStatus)->Expect.toEqual(authorizing)
        t->expect(nextState.openaiOAuthStatus)->Expect.toEqual(showingCode)
        t->expect(effects->Array.length)->Expect.toBe(0)
      },
    )

    test(
      "initializing a new ACP session does not fetch provider settings",
      t => {
        let (nextState, effects) = Reducer.next(Reducer.defaultState, _setAcpSessionAction())

        t->expect(nextState.anthropicOAuthStatus)->Expect.toEqual(NotConnected)
        t->expect(nextState.openaiOAuthStatus)->Expect.toEqual(OpenAINotConnected)
        t->expect(effects->Array.length)->Expect.toBe(0)
      },
    )

    test(
      "clearing the ACP session invalidates loaded provider settings",
      t => {
        let state = _makeStateWithSession()
        let (nextState, _effects) = Reducer.next(state, ClearAcpSession)

        t->expect(Reducer.Selectors.hasActiveACPSession(nextState))->Expect.toBe(false)
      },
    )
  })
})
