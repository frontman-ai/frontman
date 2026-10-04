module Connection = Client__ConnectionReducer
module ACP = Connection.ACP

let config = (~apiBaseUrl="http://localhost:4000"): Connection.config => {
  acp: ACP.makeConfig(
    ~endpoint="ws://test",
    ~loginUrl=`${apiBaseUrl}/users/log-in`,
    ~getAuthToken=() => None,
    ~name="test",
    ~version="1",
    ~_meta=JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("test"))])),
  ),
  relay: Connection.Relay.makeConfig(~baseUrl="http://test"),
  mcp: Connection.MCPServer.makeConfig(),
}
let connection: ACP.connection = Obj.magic({
  "state": ref({
    ...FrontmanAiFrontmanClient.FrontmanClient__ACP__Client.initialState,
    acpState: Initialized(Obj.magic({"protocolVersion": 1})),
  }),
  "dispose": () => (),
})
let session = (sessionId): ACP.session => {
  sessionId,
  connection,
  channel: Obj.magic({"off": _ => (), "leave": () => ()}),
  onUpdate: (_, _) => (),
}
let ready = (~sessionId=None, ~apiBaseUrl="http://localhost:4000"): option<
  Connection.state,
> => Some({
  config: config(~apiBaseUrl),
  connection: Ok(
    Some({
      lifetimeAbortController: WebAPI.AbortController.make(),
      phase: Ready({
        connection,
        relay: Obj.magic({"id": "relay"}),
        mcpServer: Obj.magic({"tools": []}),
        session: switch sessionId {
        | None => NoSession
        | Some(id) => SessionActive({session: session(id), requestId: ref()})
        },
      }),
    }),
  ),
})
