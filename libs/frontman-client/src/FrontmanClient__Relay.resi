type config = {
  baseUrl: string,
  requestHeaders: Dict.t<string>,
  fetch: (string, WebAPI.FetchTypes.requestInit) => promise<WebAPI.Response.t>,
}

type connected

let makeConfig: (
  ~baseUrl: string,
  ~requestHeaders: Dict.t<string>=?,
  ~fetch: (string, WebAPI.FetchTypes.requestInit) => promise<WebAPI.Response.t>=?,
) => config

let connect: (config, ~signal: WebAPI.EventTypes.abortSignal) => promise<result<connected, string>>
let getServerInfo: connected => FrontmanClient__MCP__Types.info
let getToolsJson: connected => array<JSON.t>
let hasTool: (connected, string) => bool
let executeTool: (
  connected,
  ~name: string,
  ~arguments: Dict.t<JSON.t>=?,
) => promise<result<FrontmanClient__MCP__Types.CallToolResult.t, string>>

let parseToolsResponse: JSON.t => result<FrontmanClient__Relay__Types.toolsResponse, string>
type httpError = {code: option<string>, error: string}
let readHttpError: WebAPI.Response.t => promise<httpError>
