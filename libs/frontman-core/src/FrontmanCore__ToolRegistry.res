module Protocol = FrontmanAiFrontmanProtocol
module Tool = Protocol.FrontmanProtocol__Tool
module Relay = Protocol.FrontmanProtocol__Relay

type tool = module(Tool.ServerTool)

type t = {tools: array<tool>}

let make = (): t => {
  tools: [],
}

let coreTools = (): t => {
  tools: [
    module(FrontmanCore__Tool__ReadFile),
    module(FrontmanCore__Tool__WriteFile),
    module(FrontmanCore__Tool__ListFiles),
    module(FrontmanCore__Tool__FileExists),
    module(FrontmanCore__Tool__LoadAgentInstructions),
    module(FrontmanCore__Tool__Grep),
    module(FrontmanCore__Tool__SearchFiles),
    module(FrontmanCore__Tool__Lighthouse),
    module(FrontmanCore__Tool__EditFile),
    module(FrontmanCore__Tool__ListTree),
  ],
}

let addTools = (registry: t, newTools: array<tool>): t => {
  tools: Array.concat(registry.tools, newTools),
}

@@live
let replaceByName = (registry: t, replacement: tool): t => {
  module R = unpack(replacement)
  {
    tools: registry.tools->Array.map(m => {
      module T = unpack(m)
      switch T.name == R.name {
      | true => replacement
      | false => m
      }
    }),
  }
}

let merge = (a: t, b: t): t => {
  tools: Array.concat(a.tools, b.tools),
}

let getToolByName = (registry: t, name: string): option<tool> => {
  registry.tools->Array.find(m => {
    module T = unpack(m)
    T.name == name
  })
}

external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

let serializeTool = (m: tool): Relay.remoteTool => {
  module T = unpack(m)
  let metadata = dict{
    "access": T.access->S.decodeOrThrow(~from=Tool.accessSchema, ~to=S.json->S.noValidation(true)),
    "visibleToAgent": JSON.Encode.bool(T.visibleToAgent),
  }
  let tool = dict{
    "name": JSON.Encode.string(T.name),
    "description": JSON.Encode.string(T.description),
    "inputSchema": T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
    "_meta": JSON.Encode.object(dict{"ai.frontman/tool-metadata": JSON.Encode.object(metadata)}),
  }
  T.outputJsonSchema->Option.forEach(outputSchema =>
    tool->Dict.set("outputSchema", outputSchema->jsonSchemaAsJson)
  )
  JSON.Encode.object(tool)
}

let getToolDefinitions = (registry: t): array<Relay.remoteTool> => {
  registry.tools->Array.map(serializeTool)
}

let count = (registry: t): int => {
  registry.tools->Array.length
}
