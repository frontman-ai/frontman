module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP

let formatEvent = (~eventType: string, ~data: string): string => {
  `event: ${eventType}\ndata: ${data}\n\n`
}

let progressEvent = (~progress: string): string => {
  let data = `{"progress":${JSON.stringify(String(progress))}}`
  formatEvent(~eventType="progress", ~data)
}

let resultEvent = (result: MCP.CallToolResult.t): string => {
  let data =
    result
    ->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json->S.noValidation(true))
    ->JSON.stringify
  formatEvent(~eventType="result", ~data)
}

let errorEvent = (result: MCP.CallToolResult.t): string => {
  let data =
    result
    ->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json->S.noValidation(true))
    ->JSON.stringify
  formatEvent(~eventType="error", ~data)
}

let headers = () => {
  WebAPI.HeadersInit.fromDict(
    Dict.fromArray([
      ("Content-Type", "text/event-stream"),
      ("Cache-Control", "no-cache, no-transform"),
      ("Connection", "keep-alive"),
    ]),
  )
}
