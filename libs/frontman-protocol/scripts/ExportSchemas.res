// Export Sury schemas to JSON Schema files for contract testing and breaking-change detection.
// Run: node scripts/ExportSchemas.res.mjs

module ACP = FrontmanProtocol__ACP
module MCP = FrontmanProtocol__MCP
module Relay = FrontmanProtocol__Relay
module JsonRpc = FrontmanProtocol__JsonRpc

type schemaEntry = {
  dir: string,
  name: string,
  schema: S.t<unknown>,
}

// Cast any Sury schema to S.t<unknown> for uniform handling
external toUnknownSchema: S.t<'a> => S.t<unknown> = "%identity"
external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

// Resolve __dirname from import.meta.url (ESM equivalent)
@val @scope(("import", "meta"))
external importMetaUrl: string = "url"

@module("node:url")
external fileURLToPath: string => string = "fileURLToPath"

let schemasDir = FrontmanBindings.Path.join([FrontmanBindings.Path.dirname(fileURLToPath(importMetaUrl)), "..", "schemas"])

let entries: array<schemaEntry> = [
  // Relay
  {dir: "relay", name: "toolsResponse", schema: Relay.toolsResponseSchema->toUnknownSchema},
  {dir: "relay", name: "toolCallRequest", schema: Relay.toolCallRequestSchema->toUnknownSchema},
  {dir: "relay", name: "remoteTool", schema: Relay.remoteToolSchema->toUnknownSchema},
  // ACP
  {dir: "acp", name: "initializeParams", schema: ACP.initializeParamsSchema->toUnknownSchema},
  {dir: "acp", name: "initializeResult", schema: ACP.initializeResultSchema->toUnknownSchema},
  {dir: "acp", name: "sessionUpdate", schema: ACP.sessionUpdateSchema->toUnknownSchema},
  {
    dir: "acp",
    name: "sessionUpdateNotification",
    schema: ACP.sessionUpdateNotificationSchema->toUnknownSchema,
  },
  {dir: "acp", name: "contentBlock", schema: ACP.contentBlockSchema->toUnknownSchema},
  {dir: "acp", name: "promptResult", schema: ACP.promptResultSchema->toUnknownSchema},
  {dir: "acp", name: "sessionSummary", schema: ACP.sessionSummarySchema->toUnknownSchema},
  {dir: "acp", name: "listSessionsResult", schema: ACP.listSessionsResultSchema->toUnknownSchema},
  {dir: "acp", name: "sessionNewResult", schema: ACP.sessionNewResultSchema->toUnknownSchema},
  {dir: "acp", name: "sessionLoadParams", schema: ACP.sessionLoadParamsSchema->toUnknownSchema},
  {dir: "acp", name: "sessionLoadResult", schema: ACP.sessionLoadResultSchema->toUnknownSchema},
  {dir: "acp", name: "sessionConfigOption", schema: ACP.sessionConfigOptionSchema->toUnknownSchema},
  {dir: "acp", name: "sessionModeState", schema: ACP.sessionModeStateSchema->toUnknownSchema},
  {dir: "acp", name: "deleteSessionParams", schema: ACP.deleteSessionParamsSchema->toUnknownSchema},
  {dir: "acp", name: "implementation", schema: ACP.implementationSchema->toUnknownSchema},
  {dir: "acp", name: "planEntry", schema: ACP.planEntrySchema->toUnknownSchema},
  {
    dir: "acp",
    name: "toolCallContentItem",
    schema: ACP.toolCallContentItemSchema->toUnknownSchema,
  },
  {dir: "acp", name: "embeddedResource", schema: ACP.embeddedResourceSchema->toUnknownSchema},
  // MCP
  {dir: "mcp", name: "initializeParams", schema: MCP.initializeParamsSchema->toUnknownSchema},
  {dir: "mcp", name: "initializeResult", schema: MCP.initializeResultSchema->toUnknownSchema},
  {dir: "mcp", name: "callToolResult", schema: MCP.callToolResultSchema->toUnknownSchema},
  {dir: "mcp", name: "toolCallParams", schema: MCP.toolCallParamsSchema->toUnknownSchema},
  {dir: "mcp", name: "capabilities", schema: MCP.capabilitiesSchema->toUnknownSchema},
  {dir: "mcp", name: "info", schema: MCP.infoSchema->toUnknownSchema},
  {dir: "mcp", name: "toolResultContent", schema: MCP.toolResultContentSchema->toUnknownSchema},
  {dir: "mcp", name: "toolError", schema: MCP.toolErrorSchema->toUnknownSchema},
  {dir: "mcp", name: "toolsListResult", schema: MCP.toolsListResultSchema->toUnknownSchema},
  // JsonRpc
  {dir: "jsonrpc", name: "request", schema: JsonRpc.Request.schema->toUnknownSchema},
  {dir: "jsonrpc", name: "response", schema: JsonRpc.Response.schema->toUnknownSchema},
  {dir: "jsonrpc", name: "notification", schema: JsonRpc.Notification.schema->toUnknownSchema},
]

let main = async () => {
  let totalExported = ref(0)
  let skipped = ref(0)

  for i in 0 to entries->Array.length - 1 {
    let entry = entries->Array.getUnsafe(i)
    let outDir = FrontmanBindings.Path.join([schemasDir, entry.dir])
    let _ = await FrontmanBindings.Fs.Promises.mkdir(outDir, {recursive: true})

    try {
      let jsonSchema = entry.schema->S.toJSONSchema->jsonSchemaAsJson
      let outPath = FrontmanBindings.Path.join([outDir, `${entry.name}.json`])
      await FrontmanBindings.Fs.Promises.writeFile(
        outPath,
        JSON.stringify(jsonSchema, ~space=2) ++ "\n",
      )
      totalExported := totalExported.contents + 1
    } catch {
    | S.Error({code: InvalidJsonSchema(_)}) =>
      Console.error(`Skipping ${entry.dir}/${entry.name}: schema not convertible to JSON Schema`)
      skipped := skipped.contents + 1
    }
  }

  Console.log(
    `Exported ${totalExported.contents->Int.toString} schemas to ${schemasDir}` ++
    if skipped.contents > 0 {
      ` (${skipped.contents->Int.toString} skipped)`
    } else {
      ""
    },
  )
}

main()->ignore
