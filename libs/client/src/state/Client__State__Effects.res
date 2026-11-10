open Client__State__Protocol

module Types = Client__State__Types
module Sentry = FrontmanAiFrontmanClient.FrontmanClient__Sentry
module ConnectionEffects = Client__State__ConnectionEffects
module Selectors = Client__State__Selectors

let buildPrompt = Client__State__Prompt.buildPrompt
let validatePrompt = Client__State__Prompt.validatePrompt
let updateInfoForVersions = Client__State__UpdateInfo.updateInfoForVersions

module Log = FrontmanLogs.Logs.Make({
  let component = #StateReducer
})

let requireEmbeddedAuthentication = Client__State__RequestAuth.requireEmbeddedAuthentication

type billingRequestError = Unauthorized | Cancelled | RequestFailed(string)

let fetchBilling = async (
  ~request,
  ~apiBaseUrl,
  ~signal: WebAPI.EventTypes.abortSignal,
  ~schema,
  ~onResult,
) => {
  let token = Client__EmbeddedAuth.loadToken()
  let isCurrent = () => !signal.aborted && token === Client__EmbeddedAuth.loadToken()
  switch Client__EmbeddedAuth.jsonHeaders() {
  | None => Unauthorized->Error->onResult
  | Some(headers) =>
    try {
      let body = switch request {
      | Client__Billing.Checkout(interval) =>
        {Client__Billing.interval: interval}
        ->S.decodeOrThrow(
          ~from=Client__Billing.checkoutRequestSchema,
          ~to=S.json->S.noValidation(true),
        )
        ->JSON.stringify
        ->WebAPI.BodyInit.fromString
        ->Some
      | Status | CustomerPortal => None
      }
      let response = await `${apiBaseUrl}${Client__Billing.requestPath(
          request,
        )}`->WebAPI.Fetch.fetch(
        ~init={
          method: switch request {
          | Status => "GET"
          | _ => "POST"
          },
          headers,
          credentials: Omit,
          cache: NoStore,
          ?body,
          signal: [signal, WebAPI.AbortSignal.timeout(30000)]->WebAPI.AbortSignal.any->Null.make,
        },
      )
      let json = await response->WebAPI.Response.json
      switch (isCurrent(), response.status, response.ok) {
      | (false, _, _) => Error(Cancelled)
      | (true, 401, _) => Error(Unauthorized)
      | (true, _, false) =>
        let error = json->S.parseOrThrow(~to=Client__Billing.errorResponseSchema)
        switch error.requestId {
        | Some(id) => `${error.error} Request reference: ${id}`
        | None => error.error
        }
        ->RequestFailed
        ->Error
      | (true, _, true) => json->S.parseOrThrow(~to=schema)->Ok
      }->onResult
    } catch {
    | exn =>
      switch isCurrent() {
      | false => Cancelled
      | true =>
        Log.error(~error=JsExn.fromException(exn), "Billing request failed")
        RequestFailed("Could not contact billing. Please try again.")
      }
      ->Error
      ->onResult
    }
  }
}

let fetchUserProfileImpl = (dispatch, ~apiBaseUrl) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/me`

    try {
      switch Client__EmbeddedAuth.headers() {
      | Some(headers) =>
        let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
        Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
        switch response.ok {
        | true =>
          let json = await response->WebAPI.Response.json
          let userProfile =
            json->S.decodeOrThrow(~from=S.json, ~to=Client__State__Types.userProfileSchema)
          dispatch(UserProfileReceived({userProfile: userProfile}))
          Client__Heap.identify(userProfile.id)
        | false => ()
        }
      | None => ()
      }
    } catch {
    | exn => Log.error(~error=JsExn.fromException(exn), "FetchUserProfile failed")
    }
  }
  fetch()->ignore
}

let encodeUserApiKeySaveRequest = Client__State__ProviderCodec.encodeUserApiKeySaveRequest

let fetchApiKeySettingsImpl = (dispatch, ~apiBaseUrl) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/api-keys`

    try {
      switch Client__EmbeddedAuth.headers() {
      | Some(headers) =>
        let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
        Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
        switch response.ok {
        | true =>
          let json = await response->WebAPI.Response.json
          let apiKeysResponse =
            json->S.decodeOrThrow(~from=S.json, ~to=Client__State__Types.userApiKeysResponseSchema)
          apiKeyProviders->Array.forEach(provider => {
            let providerId = apiKeyProviderId(provider)
            let hasUserKey = apiKeysResponse.providers->Array.includes(providerId)
            let source = switch hasUserKey {
            | true => Client__State__Types.UserOverride
            | false => Client__State__Types.None
            }

            dispatch(ApiKeySettingsReceived({provider, source}))
          })
        | false => ()
        }
      | None => ()
      }
    } catch {
    | exn => Log.error(~error=JsExn.fromException(exn), "FetchApiKeySettings failed")
    }
  }
  fetch()->ignore
}

let saveApiKeyImpl = (dispatch, ~apiBaseUrl, ~provider: apiKeyProvider, ~key) => {
  let save = async () => {
    dispatch(ApiKeySaveStarted({provider: provider}))
    let url = `${apiBaseUrl}/api/user/api-keys`

    try {
      switch Client__EmbeddedAuth.jsonHeaders() {
      | Some(headers) =>
        let response = await WebAPI.Fetch.fetch(
          url,
          ~init={
            method: "POST",
            headers,
            body: WebAPI.BodyInit.fromString(
              encodeUserApiKeySaveRequest(~provider=apiKeyProviderId(provider), ~key),
            ),
          },
        )
        Client__EmbeddedAuth.clearTokenOnUnauthorized(response)

        switch response.ok {
        | false =>
          dispatch(
            ApiKeySaveError({
              provider,
              error: `HTTP ${response.status->Int.toString}: ${response.statusText}`,
            }),
          )
        | true => dispatch(ApiKeySaved({provider: provider}))
        }
      | None => dispatch(ApiKeySaveError({provider, error: embeddedAuthRequiredError}))
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      dispatch(ApiKeySaveError({provider, error: `Failed to save API key: ${msg}`}))
    }
  }
  save()->ignore
}

let fetchCustomProvidersImpl = (dispatch, ~apiBaseUrl) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/custom-providers`

    try {
      switch Client__EmbeddedAuth.headers() {
      | Some(headers) =>
        let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
        Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
        switch response.ok {
        | true =>
          let json = await response->WebAPI.Response.json
          let providersResponse =
            json->S.decodeOrThrow(
              ~from=S.json,
              ~to=Client__State__Types.customProvidersResponseSchema,
            )
          dispatch(CustomProvidersReceived({providers: providersResponse.providers}))
        | false =>
          switch response.status {
          | 401 => dispatch(ConnectionAction(RequireAuthentication))
          | _ =>
            Log.error(
              `Custom Provider request failed: HTTP ${response.status->Int.toString}: ${response.statusText}`,
            )
          }
        }
      | None => dispatch(ConnectionAction(RequireAuthentication))
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Log.error(`Failed to fetch custom providers: ${msg}`)
    }
  }
  fetch()->ignore
}

let encodeCustomProviderSaveRequest = Client__State__ProviderCodec.encodeCustomProviderSaveRequest
let decodeCustomProviderMutationError = Client__State__ProviderCodec.decodeCustomProviderMutationError
let customProviderSaveTarget = Client__State__ProviderCodec.customProviderSaveTarget
let customProviderDeleteUrl = Client__State__ProviderCodec.customProviderDeleteUrl

let dispatchCustomProviderAuthRequired = (dispatch, ~operation) => {
  dispatch(ConnectionAction(RequireAuthentication))
  dispatch(
    CustomProviderMutationFailed({
      operation,
      error: Client__State__Types.CustomProviderNetworkError(embeddedAuthRequiredError),
    }),
  )
}

let handleCustomProviderMutationError = async (dispatch, response, ~operation) =>
  switch response.WebAPI.Response.status {
  | 401 => dispatchCustomProviderAuthRequired(dispatch, ~operation)
  | _ =>
    let json = await response->WebAPI.Response.json
    dispatch(
      CustomProviderMutationFailed({
        operation,
        error: decodeCustomProviderMutationError(~status=response.status, ~json),
      }),
    )
  }

let customProviderMutationImpl = (dispatch, ~apiBaseUrl, ~request) => {
  let run = async () => {
    let operation = customProviderMutationOperation(request)
    try {
      switch request {
      | SaveCustomProviderRequest(draft) =>
        switch Client__EmbeddedAuth.jsonHeaders() {
        | Some(headers) =>
          let (url, method) = customProviderSaveTarget(~apiBaseUrl, draft)
          let response = await WebAPI.Fetch.fetch(
            url,
            ~init={
              method,
              headers,
              body: WebAPI.BodyInit.fromString(encodeCustomProviderSaveRequest(draft)),
            },
          )
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {provider} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.customProviderResponseSchema,
              )
            dispatch(CustomProviderMutationSucceeded({operation, provider: Some(provider)}))
          | false => await handleCustomProviderMutationError(dispatch, response, ~operation)
          }
        | None => dispatchCustomProviderAuthRequired(dispatch, ~operation)
        }
      | DeleteCustomProviderRequest({id, lockVersion}) =>
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(
            customProviderDeleteUrl(~apiBaseUrl, ~id, ~lockVersion),
            ~init={headers, method: "DELETE"},
          )
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true => dispatch(CustomProviderMutationSucceeded({operation, provider: None}))
          | false => await handleCustomProviderMutationError(dispatch, response, ~operation)
          }
        | None => dispatchCustomProviderAuthRequired(dispatch, ~operation)
        }
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      let action = switch request {
      | SaveCustomProviderRequest(_) => "save"
      | DeleteCustomProviderRequest(_) => "delete"
      }
      dispatch(
        CustomProviderMutationFailed({
          operation,
          error: Client__State__Types.CustomProviderNetworkError(
            `Failed to ${action} custom provider: ${msg}`,
          ),
        }),
      )
    }
  }
  run()->ignore
}

let getSessionTextBuffer = Client__State__SessionBuffer.getSessionTextBuffer

let runWordPressRequest = Client__State__WordPressEffects.runWordPressRequest

let fetchOAuthStatus = async (~url, ~dispatch, ~onSuccess, ~onError) => {
  try {
    switch Client__EmbeddedAuth.headers() {
    | Some(headers) =>
      let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
      switch (response.ok, response.status) {
      | (true, _) =>
        let json = await response->WebAPI.Response.json
        let status = json->S.decodeOrThrow(~from=S.json, ~to=Types.oauthStatusResponseSchema)
        dispatch(onSuccess(status))
      | (false, 401) => requireEmbeddedAuthentication(dispatch)
      | (false, _) => ()
      }
    | None => requireEmbeddedAuthentication(dispatch)
    }
  } catch {
  | _ => dispatch(onError)
  }
}

let targetIsCurrent = (state: state, target: taskTarget): bool =>
  switch target {
  | CurrentTask => true
  | ForTask(taskId) => Selectors.currentTaskId(state) == Some(taskId)
  }

let handleEffect = (effect, state: state, dispatch: action => unit) => {
  switch effect {
  | ReloadFrontman => WebAPI.Window.current->WebAPI.Window.location->WebAPI.Location.reload
  | PersistSelectedModel(value) => Client__State__ModelPreference.syncSelectedModelValueToStorage(value)
  | BufferAssistantText({taskId, messageId, text, agentId}) =>
    getSessionTextBuffer(dispatch).add(~taskId, ~messageId, ~text, ~agentId)
  | BufferUserBlock({taskId, messageId, block, agentId}) =>
    getSessionTextBuffer(dispatch).addUserBlock(~taskId, ~messageId, ~block, ~agentId)
  | FlushSessionActions(actions) =>
    Client__TextDeltaBuffer.flush()
    actions->Array.forEach(action => dispatch(action))
  | AbortBillingRequest(controller) =>
    controller->Option.forEach(controller => WebAPI.AbortController.abort(controller))
  | FetchBillingStatus({apiBaseUrl, signal}) =>
    fetchBilling(
      ~request=Status,
      ~apiBaseUrl,
      ~signal,
      ~schema=Client__Billing.statusSchema,
      ~onResult=result => {
        switch result {
        | Ok(status) => dispatch(BillingStatusReceived(status))
        | Error(RequestFailed(error)) => dispatch(BillingStatusError({error: error}))
        | Error(Unauthorized) => dispatch(BillingAuthRequired({tab: None}))
        | Error(Cancelled) => ()
        }
      },
    )->ignore
  | OpenBillingTabAndFetchUrl({request, apiBaseUrl, signal}) =>
    switch Client__EmbeddedAuth.loadToken() {
    | None => dispatch(BillingAuthRequired({tab: None}))
    | Some(_) =>
      switch Client__HostNavigation.openManagedTab(~url="about:blank") {
      | None => dispatch(BillingLaunchFailed({tab: None, error: "Allow popups, then try again."}))
      | Some(tab) =>
        fetchBilling(
          ~request,
          ~apiBaseUrl,
          ~signal,
          ~schema=Client__Billing.urlResponseSchema,
          ~onResult=result => {
            switch result {
            | Ok({url}) =>
              switch WebAPI.URL.make(~url).protocol {
              | "https:" => dispatch(BillingUrlReceived({tab, url, request}))
              | _ => failwith("Invalid Stripe URL")
              }
            | Error(RequestFailed(error)) => dispatch(BillingLaunchFailed({tab: Some(tab), error}))
            | Error(Unauthorized) => dispatch(BillingAuthRequired({tab: Some(tab)}))
            | Error(Cancelled) => dispatch(BillingRequestCancelled({tab: Some(tab)}))
            }
          },
        )->ignore
      }
    }
  | CloseBillingTab(tab) => tab->Option.forEach(WebAPI.Window.close)
  | RequireBillingAuthentication => requireEmbeddedAuthentication(dispatch)
  | NavigateBillingTab({tab, url}) =>
    try {
      switch WebAPI.Window.closed(tab) {
      | true =>
        dispatch(
          BillingLaunchFailed({tab: Some(tab), error: "Stripe tab was closed. Please try again."}),
        )
      | false => tab->WebAPI.Window.location->WebAPI.Location.assign(url)
      }
    } catch {
    | exn =>
      Log.error(~error=JsExn.fromException(exn), "Billing navigation failed")
      dispatch(
        BillingLaunchFailed({tab: Some(tab), error: "Could not open Stripe. Please try again."}),
      )
    }
  | FetchUserProfileEffect({apiBaseUrl}) => fetchUserProfileImpl(dispatch, ~apiBaseUrl)
  | SubmissionCompleted({onComplete, result}) => onComplete(result)
  | ConnectionEffect(effect) =>
    ConnectionEffects.handleEffect(
      effect,
      state.connection->Option.getOrThrow,
      action => dispatch(ConnectionAction(action)),
      ~dispatchApp=dispatch,
    )
  | CreateSession({taskId, input}) =>
    dispatch(
      ConnectionAction(
        CreateSession({
          sessionId: taskId,
          onComplete: result =>
            switch result {
            | Ok(_) => dispatch(AddUserMessage(input))
            | Error(error) => input.onComplete(Error(error))
            },
        }),
      ),
    )
  | SendMessage({taskId, submission: {id, content, annotations, agentId, onComplete}}) =>
    let text = TaskReducer.extractTextFromUserContent(content)
    let attachments = TaskReducer.extractAttachmentsFromUserContent(content)
    let (additionalBlocks, _meta) = buildPrompt(
      state,
      ~messageId=id,
      ~attachments,
      ~annotations,
      ~task=state.tasks->Dict.get(taskId)->Option.getOrThrow,
      ~agentId,
    )
    let result = switch validatePrompt(~text, ~additionalBlocks, ~_meta) {
    | Error(error) => Error(error)
    | Ok() =>
      switch state.connection {
      | Some(
          {
            connection: Ok(Some({phase: Ready({session: SessionActive({session, requestId})})})),
          } as connection,
        )
        if session.sessionId == taskId &&
          Connection.isCurrentSessionRequest(connection, requestId) =>
        let fail = error => dispatch(PromptFailed({requestId, taskId, id, error}))
        let send = async () => {
          try {
            switch await Connection.ACP.sendPrompt(session, text, ~additionalBlocks, ~_meta) {
            | Ok(_) => ()
            | Error(error) => fail(error)
            }
          } catch {
          | exn =>
            fail(Connection.ACP.requestErrorFromMessage("sendPrompt exception"))
            throw(exn)
          }
        }
        send()->ignore
        Ok()
      | _ => Error("Cannot send message: no active ACP session")
      }
    }
    switch result {
    | Error(error) =>
      dispatch(TaskAction({target: ForTask(taskId), action: UserMessageSendFailed({id, error})}))
    | Ok() => ()
    }
    onComplete(result)
  | TaskEffect({target, effect: taskEffect}) => {
      let taskDispatch = (taskAction: TaskReducer.action) => {
        dispatch(TaskAction({target, action: taskAction}))
      }

      let delegate = (delegated: TaskReducer.delegated) => {
        switch delegated {
        | NeedSessionCommand(command) => dispatch(ConnectionAction(SessionCommand(command)))
        | NeedSyncBrowserUrl(url) =>
          switch targetIsCurrent(state, target) {
          | true => Client__BrowserUrl.syncBrowserUrl(~previewUrl=url)
          | false => ()
          }
        }
      }

      TaskReducer.handleEffect(taskEffect, ~dispatch=taskDispatch, ~delegate)
    }
  | FetchApiKeySettingsEffect({apiBaseUrl}) => fetchApiKeySettingsImpl(dispatch, ~apiBaseUrl)
  | WordPressConnectionEffect({apiBaseUrl, requestId, operation}) =>
    runWordPressRequest(dispatch, apiBaseUrl, requestId, operation)->ignore
  | SaveApiKeyEffect({apiBaseUrl, provider, key}) =>
    saveApiKeyImpl(dispatch, ~apiBaseUrl, ~provider, ~key)
  | FetchAnthropicOAuthStatusEffect({apiBaseUrl}) =>
    fetchOAuthStatus(
      ~url=`${apiBaseUrl}/api/oauth/anthropic/status`,
      ~dispatch,
      ~onSuccess=({connected, expiresAt}) => AnthropicOAuthStatusReceived({connected, expiresAt}),
      ~onError=AnthropicOAuthError({error: "Failed to fetch OAuth status"}),
    )->ignore

  | GetAnthropicOAuthUrlEffect({apiBaseUrl}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/oauth/anthropic/authorize-url`

      try {
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {authorizeUrl, verifier} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.anthropicOAuthAuthorizeUrlResponseSchema,
              )
            dispatch(AnthropicOAuthUrlReceived({authorizeUrl, verifier}))
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ => dispatch(AnthropicOAuthError({error: "Failed to get authorization URL"}))
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to get authorization URL"}))
      }
    }
    fetch()->ignore

  | ExchangeAnthropicOAuthCodeEffect({apiBaseUrl, code, verifier}) =>
    let exchange = async () => {
      let url = `${apiBaseUrl}/api/oauth/anthropic/exchange`

      try {
        let body = JSON.Encode.object(
          Dict.fromArray([
            ("code", JSON.Encode.string(code)),
            ("verifier", JSON.Encode.string(verifier)),
          ]),
        )
        switch Client__EmbeddedAuth.jsonHeaders() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(
            url,
            ~init={
              method: "POST",
              headers,
              body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
            },
          )
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {expiresAt} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.anthropicOAuthExchangeResponseSchema,
              )
            dispatch(AnthropicOAuthConnected({expiresAt: expiresAt}))
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ =>
              let json = await response->WebAPI.Response.json
              let {error} =
                json->S.decodeOrThrow(
                  ~from=S.json,
                  ~to=Client__State__Types.anthropicOAuthErrorResponseSchema,
                )
              dispatch(AnthropicOAuthError({error: error}))
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to exchange authorization code"}))
      }
    }
    exchange()->ignore

  | DisconnectAnthropicOAuthEffect({apiBaseUrl}) =>
    let disconnect = async () => {
      let url = `${apiBaseUrl}/api/oauth/anthropic/disconnect`

      try {
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={method: "DELETE", headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true => dispatch(AnthropicOAuthDisconnected)
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ => dispatch(AnthropicOAuthError({error: "Failed to disconnect"}))
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to disconnect"}))
      }
    }
    disconnect()->ignore

  | FetchOpenAIOAuthStatusEffect({apiBaseUrl}) =>
    fetchOAuthStatus(
      ~url=`${apiBaseUrl}/api/oauth/openai/status`,
      ~dispatch,
      ~onSuccess=({connected, expiresAt}) => OpenAIOAuthStatusReceived({connected, expiresAt}),
      ~onError=OpenAIOAuthError({deviceAuthId: None, error: "Failed to fetch OpenAI OAuth status"}),
    )->ignore

  | InitiateOpenAIDeviceAuthEffect({apiBaseUrl}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/oauth/openai/initiate`

      try {
        switch Client__EmbeddedAuth.jsonHeaders() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={method: "POST", headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {deviceAuthId, userCode, verificationUrl} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.openAIDeviceAuthResponseSchema,
              )
            dispatch(OpenAIDeviceCodeReceived({deviceAuthId, userCode, verificationUrl}))
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ =>
              dispatch(
                OpenAIOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}),
              )
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ =>
        dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}))
      }
    }
    fetch()->ignore

  | PollOpenAIDeviceAuthEffect({apiBaseUrl, deviceAuthId, userCode}) =>
    let poll = async () => {
      let maxAttempts = 180
      let intervalMs = 5000
      let body = JSON.stringifyAny(
        dict{
          "device_auth_id": deviceAuthId,
          "user_code": userCode,
        },
      )->Option.getOr("{}")
      let waitForNextPoll = () =>
        Promise.make((resolve, _) => {
          let _ = setTimeout(() => resolve(), intervalMs)
        })
      let rec pollLoop = async attempt => {
        switch attempt < maxAttempts {
        | false =>
          dispatch(
            OpenAIOAuthError({
              deviceAuthId: Some(deviceAuthId),
              error: "Authorization timed out. Please try again.",
            }),
          )
        | true =>
          try {
            let url = `${apiBaseUrl}/api/oauth/openai/poll`
            switch Client__EmbeddedAuth.jsonHeaders() {
            | Some(headers) =>
              let response = await WebAPI.Fetch.fetch(
                url,
                ~init={
                  method: "POST",
                  headers,
                  body: WebAPI.BodyInit.fromString(body),
                },
              )
              Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
              switch (response.ok, response.status) {
              | (true, _) =>
                let json = await response->WebAPI.Response.json
                let {status, expiresAt} =
                  json->S.decodeOrThrow(
                    ~from=S.json,
                    ~to=Client__State__Types.openAIDeviceAuthPollResponseSchema,
                  )
                switch status {
                | Client__State__Types.DeviceAuthConnected =>
                  let expiresAt = expiresAt->Option.getOrThrow
                  dispatch(OpenAIOAuthConnected({deviceAuthId, expiresAt}))
                | Client__State__Types.DeviceAuthPending =>
                  await waitForNextPoll()
                  await pollLoop(attempt + 1)
                }
              | (false, 401) => requireEmbeddedAuthentication(dispatch)
              | (false, 403) =>
                dispatch(
                  OpenAIOAuthError({
                    deviceAuthId: Some(deviceAuthId),
                    error: "Authorization was declined.",
                  }),
                )
              | (false, _) =>
                await waitForNextPoll()
                await pollLoop(attempt + 1)
              }
            | None => requireEmbeddedAuthentication(dispatch)
            }
          } catch {
          | _ =>
            await waitForNextPoll()
            await pollLoop(attempt + 1)
          }
        }
      }
      await pollLoop(0)
    }
    poll()->ignore

  | DisconnectOpenAIOAuthEffect({apiBaseUrl}) =>
    let disconnect = async () => {
      let url = `${apiBaseUrl}/api/oauth/openai/disconnect`

      try {
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={method: "DELETE", headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true => dispatch(OpenAIOAuthDisconnected)
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ => dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ => dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
      }
    }
    disconnect()->ignore

  | CheckForUpdateEffect({apiBaseUrl, installedVersion, target}) =>
    let fetch = async () => {
      try {
        let url = switch target {
        | NpmPackage(_) => `${apiBaseUrl}/api/integrations/latest-versions`
        | WordPressPlugin => `${Client__RelayBaseUrl.current()}/frontman/plugin-update`
        }
        let response = await WebAPI.Fetch.fetch(url)
        switch (target, response.status, response.ok) {
        | (WordPressPlugin, 404, _) => dispatch(WordPressUpdatesChecked(None))
        | (_, _, false) =>
          Sentry.captureConnectionError(
            `CheckForUpdate: HTTP ${response.status->Int.toString} ${response.statusText}`,
            ~endpoint=url,
          )
        | (_, _, true) =>
          let json = await response->WebAPI.Response.json
          switch target {
          | WordPressPlugin =>
            let data =
              json->S.decodeOrThrow(~from=S.json, ~to=Client__WordPressUpdates.responseSchema)
            dispatch(WordPressUpdatesChecked(Some(data)))
          | NpmPackage(npmPackage) =>
            let {versions} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.latestVersionsResponseSchema,
              )
            switch versions->Dict.get(npmPackage)->Option.flatMap(version => version) {
            | Some(latestVersion) =>
              dispatch(
                UpdateInfoChecked(
                  updateInfoForVersions(~target, ~installedVersion, ~latestVersion),
                ),
              )
            | None =>
              Sentry.captureConnectionError(
                `CheckForUpdate: package "${npmPackage}" not found or null in registry response`,
                ~endpoint=url,
              )
            }
          }
        }
      } catch {
      | exn => Sentry.captureException(exn, ~operation="CheckForUpdate")
      }
    }
    fetch()->ignore
  | FetchCustomProvidersEffect({apiBaseUrl}) => fetchCustomProvidersImpl(dispatch, ~apiBaseUrl)
  | CustomProviderMutationEffect({apiBaseUrl, request}) =>
    customProviderMutationImpl(dispatch, ~apiBaseUrl, ~request)
  }
}
