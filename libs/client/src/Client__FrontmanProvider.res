module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanAiFrontmanClient.FrontmanClient__MCP__Server
module Reducer = Client__ConnectionReducer
module RuntimeConfig = Client__RuntimeConfig

type contextValue = {
  state: Reducer.state,
  dispatch: Reducer.action => unit,
  createSession: (~onComplete: result<string, string> => unit) => unit,
}

let context: React.Context.t<option<contextValue>> = React.createContext(None)

module ContextProvider = {
  let make = React.Context.provider(context)
}

let useFrontman = () =>
  React.useContext(context)->Option.getOrThrow(~message="useFrontman requires FrontmanProvider")

module Provider = {
  @react.component
  let make = (
    ~endpoint: string,
    ~loginUrl: string,
    ~clientName: string="frontman-client",
    ~clientVersion: string="1.0.0",
    ~children: React.element,
  ) => {
    let (initialState, _) = React.useState(() => {
      let baseUrl = Client__RelayBaseUrl.current()
      let runtimeConfig = RuntimeConfig.read()
      let relay = switch runtimeConfig.framework {
      | Wordpress => Client__WordPressRelay.makeConfig(~baseUrl, ~nonce=runtimeConfig.wpNonce)
      | Nextjs | Vite | Astro => Relay.makeConfig(~baseUrl)
      }
      let acp = ACP.makeConfig(
        ~endpoint,
        ~loginUrl,
        ~getAuthToken=Client__EmbeddedAuth.loadToken,
        ~name=clientName,
        ~version=clientVersion,
        ~_meta=RuntimeConfig.toMeta(runtimeConfig),
        ~onConfigOptionsUpdated=configOptions => {
          Client__State__Store.dispatch(ConfigOptionsReceived({configOptions: configOptions}))
        },
        ~onBillingStatusUpdated=payload => {
          switch FrontmanAiFrontmanClient.FrontmanClient__Decoders.parseSchema(
            payload,
            Client__Billing.statusSchema,
          ) {
          | Ok(status) => Client__State__Store.dispatch(BillingStatusReceived(status))
          | Error(_) =>
            Client__State__Store.dispatch(
              BillingStatusError({error: "Failed to parse billing status"}),
            )
          }
        },
      )
      let mcp = MCPServer.makeConfig(
        ~tools=Client__ToolRegistry.forFramework(runtimeConfig.framework).tools,
        ~serverName=clientName,
        ~serverVersion=clientVersion,
        ~resolveImageRef=(uri, ~taskId) => {
          let state = StateStore.getState(Client__State__Store.store)
          Client__State.Selectors.resolveImageRef(state, ~taskId, ~uri)->Option.map(
            ({base64, mediaType}) => {MCPServer.base64, mediaType},
          )
        },
      )
      Reducer.initialState({acp, relay, mcp})
    })
    let (state, dispatch) = StateReducer.useReducer(module(Reducer), initialState)
    let connectionStateRef = React.useRef(state)

    React.useEffect(() => {
      connectionStateRef.current = state
      None
    }, [state])

    React.useEffect0(() => {
      dispatch(Initialize)

      Some(
        () => {
          Reducer.cleanup(connectionStateRef.current)
          dispatch(Dispose)
        },
      )
    })

    let createSession = React.useCallback1((~onComplete: result<string, string> => unit) => {
      dispatch(
        CreateSession({
          sessionId: WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.randomUUID,
          onComplete,
        }),
      )
    }, [dispatch])

    let contextValue: contextValue = {state, dispatch, createSession}

    <ContextProvider value={Some(contextValue)}> {children} </ContextProvider>
  }
}
