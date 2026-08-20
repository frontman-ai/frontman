module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Tool = Protocol.FrontmanProtocol__Tool
module Core = FrontmanAiFrontmanCore
module Registry = Core.FrontmanCore__ToolRegistry
module Endpoint = Core.FrontmanCore__MCP__Endpoint
module HttpSecurity = Core.FrontmanCore__MCP__HttpSecurity
module Plugin = FrontmanVite__Plugin

let result = source => JSON.parseOrThrow(source)->S.parseOrThrow(~to=MCP.CallToolResult.schema)

module SimpleText = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "test_simple_text",
    "Returns conformance text content",
    Tool.Read,
    true,
    None,
  )
  @schema type input = {}
  let execute = async (_context, _input) =>
    MCP.CallToolResult.makeText("This is a simple text response for testing.")
}

module Image = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "test_image_content",
    "Returns conformance image content",
    Tool.Read,
    true,
    None,
  )
  @schema type input = {}
  let execute = async (_context, _input) =>
    MCP.CallToolResult.makeImage(
      ~data="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nWQAAAAASUVORK5CYII=",
      ~mimeType="image/png",
    )
}

module Audio = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "test_audio_content",
    "Returns conformance audio content",
    Tool.Read,
    true,
    None,
  )
  @schema type input = {}
  let execute = async (_context, _input) =>
    result(`{"resultType":"complete","content":[{"type":"audio","data":"UklGRgQAAABXQVZF","mimeType":"audio/wav"}]}`)
}

module EmbeddedResource = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "test_embedded_resource",
    "Returns a conformance embedded resource",
    Tool.Read,
    true,
    None,
  )
  @schema type input = {}
  let execute = async (_context, _input) =>
    result(`{"resultType":"complete","content":[{"type":"resource","resource":{"uri":"test://embedded-resource","mimeType":"text/plain","text":"This is an embedded resource content."}}]}`)
}

module MixedContent = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "test_multiple_content_types",
    "Returns mixed conformance content",
    Tool.Read,
    true,
    None,
  )
  @schema type input = {}
  let execute = async (_context, _input) =>
    result(`{"resultType":"complete","content":[{"type":"text","text":"Multiple content types test:"},{"type":"image","data":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nWQAAAAASUVORK5CYII=","mimeType":"image/png"},{"type":"resource","resource":{"uri":"test://mixed-content-resource","mimeType":"application/json","text":"{\\"test\\":\\"data\\",\\"value\\":123}"}}]}`)
}

module ErrorResult = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "test_error_handling",
    "Returns an intentional conformance error",
    Tool.Read,
    true,
    None,
  )
  @schema type input = {}
  let execute = async (_context, _input) =>
    MCP.CallToolResult.makeError("This tool intentionally returns an error for testing")
}

@@live
let makeMiddleware = allowedOrigins => {
  let registry =
    Registry.make()->Registry.addTools([
      module(SimpleText),
      module(Image),
      module(Audio),
      module(EmbeddedResource),
      module(MixedContent),
      module(ErrorResult),
    ])
  let mcp: Endpoint.config = {
    security: HttpSecurity.make(~allowedOrigins, ~authorize=async _headers =>
      HttpSecurity.Authorized
    ),
    registry,
    projectRoot: ".",
    sourceRoot: ".",
    serverName: "frontman-conformance",
    serverVersion: "1.0.0",
    allowedPreflightHeaders: [],
  }
  Plugin.adaptMiddlewareToVite(~basePath="frontman", ~mcp=Some(mcp), (_request, ~rawHeaders) => {
    rawHeaders->ignore
    Promise.resolve(None)
  })
}
