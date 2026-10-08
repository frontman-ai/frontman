module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanAiFrontmanClient.FrontmanClient__MCP__Server
module RuntimeConfig = Client__RuntimeConfig

module Provider = {
  @react.component
  let make = (
    ~endpoint: string,
    ~loginUrl: string,
    ~clientName: string="frontman-client",
    ~clientVersion: string="1.0.0",
    ~children: React.element,
  ) => {
    React.useEffect0(() => {
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
      Client__State__Store.dispatch(InitializeConnection({acp, relay, mcp}))
      let refreshBilling = _ => Client__State.Actions.requestBilling(Client__Billing.Status)
      WebAPI.Window.current->WebAPI.Window.addEventListener(Custom("focus"), refreshBilling)
      Some(
        () => {
          Client__TextDeltaBuffer.reset()
          Client__State.Actions.connection(Dispose)
          WebAPI.Window.current->WebAPI.Window.removeEventListener(Custom("focus"), refreshBilling)
        },
      )
    })
    children
  }
}
