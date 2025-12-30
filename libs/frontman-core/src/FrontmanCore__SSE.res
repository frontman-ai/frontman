// SSE (Server-Sent Events) response helpers

module Protocol = FrontmanFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP

// Format SSE event
let formatEvent = (~eventType: string, ~data: string): string => {
  `event: ${eventType}\ndata: ${data}\n\n`
}

// Send progress event
let progressEvent = (~progress: string): string => {
  let data = `{"progress":${JSON.stringify(String(progress))}}`
  formatEvent(~eventType="progress", ~data)
}

// Send result event
let resultEvent = (result: MCP.callToolResult): string => {
  let data = result->S.reverseConvertToJsonOrThrow(MCP.callToolResultSchema)->JSON.stringify
  formatEvent(~eventType="result", ~data)
}

// Send error event
let errorEvent = (result: MCP.callToolResult): string => {
  let data = result->S.reverseConvertToJsonOrThrow(MCP.callToolResultSchema)->JSON.stringify
  formatEvent(~eventType="error", ~data)
}

// Create SSE response headers
let headers = () => {
  WebAPI.HeadersInit.fromDict(
    Dict.fromArray([
      ("Content-Type", "text/event-stream"),
      ("Cache-Control", "no-cache, no-transform"),
      ("Connection", "keep-alive"),
    ]),
  )
}
