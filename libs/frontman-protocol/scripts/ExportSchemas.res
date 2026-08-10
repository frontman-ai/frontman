module ACP = FrontmanProtocol__ACP
module MCP = FrontmanProtocol__MCP
module ContentBlock = FrontmanProtocol__ContentBlock
module Relay = FrontmanProtocol__Relay
module JsonRpc = FrontmanProtocol__JsonRpc
module MCPMetadata = FrontmanProtocol__MCPMetadata

type schemaEntry = {
  dir: string,
  name: string,
  schema: S.t<unknown>,
}

external toUnknownSchema: S.t<'a> => S.t<unknown> = "%identity"
external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

@val @scope(("import", "meta"))
external importMetaUrl: string = "url"

@module("node:url")
external fileURLToPath: string => string = "fileURLToPath"

let schemasDir = FrontmanBindings.Path.join([
  FrontmanBindings.Path.dirname(fileURLToPath(importMetaUrl)),
  "..",
  "schemas",
])

let entries: array<schemaEntry> = [
  {dir: "relay", name: "toolsResponse", schema: Relay.toolsResponseSchema->toUnknownSchema},
  {dir: "relay", name: "toolCallRequest", schema: Relay.toolCallRequestSchema->toUnknownSchema},
  {dir: "relay", name: "remoteTool", schema: Relay.remoteToolSchema->toUnknownSchema},
  {dir: "acp", name: "initializeParams", schema: ACP.initializeParamsSchema->toUnknownSchema},
  {dir: "acp", name: "initializeResult", schema: ACP.initializeResultSchema->toUnknownSchema},
  {
    dir: "acp",
    name: "capabilityMetadata",
    schema: ACP.capabilityMetadataSchema->toUnknownSchema,
  },
  {dir: "acp", name: "agentCatalogEntry", schema: ACP.agentCatalogEntrySchema->toUnknownSchema},
  {
    dir: "acp",
    name: "agentAttributionConfigurationMetadata",
    schema: ACP.agentAttributionConfigurationMetadataSchema->toUnknownSchema,
  },
  {dir: "acp", name: "messageMetadata", schema: ACP.messageMetadataSchema->toUnknownSchema},
  {dir: "acp", name: "sessionUpdate", schema: ACP.sessionUpdateSchema->toUnknownSchema},
  {
    dir: "acp",
    name: "sessionUpdateNotification",
    schema: ACP.sessionUpdateNotificationSchema->toUnknownSchema,
  },
  {dir: "acp", name: "contentBlock", schema: ContentBlock.schema->toUnknownSchema},
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
  {
    dir: "acp",
    name: "embeddedResource",
    schema: ContentBlock.embeddedResourceSchema->toUnknownSchema,
  },
  {dir: "mcp", name: "callToolResult", schema: MCP.CallToolResult.jsonSchema->toUnknownSchema},
  {
    dir: "mcp",
    name: "callToolRequestParams",
    schema: MCP.CallToolRequestParams.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "callToolRequest", schema: MCP.CallToolRequest.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "cancelledNotification",
    schema: MCP.CancelledNotification.schema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "cancelledNotificationParams",
    schema: MCP.CancelledNotificationParams.schema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "createMessageRequest",
    schema: MCP.CreateMessageRequest.schema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "createMessageRequestParams",
    schema: MCP.CreateMessageRequestParams.schema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "clientCapabilities",
    schema: MCP.ClientCapabilities.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "discoverRequest", schema: MCP.DiscoverRequest.schema->toUnknownSchema},
  {dir: "mcp", name: "discoverResult", schema: MCP.DiscoverResult.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "discoverResultResponse",
    schema: MCP.DiscoverResultResponse.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "extensions", schema: MCP.Extensions.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "executionContextExtensionSettings",
    schema: MCP.ExecutionContextExtension.settingsSchema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "executionContext",
    schema: MCP.ExecutionContextExtension.contextSchema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "executionContextClientCapabilities",
    schema: MCP.ExecutionContextExtension.clientCapabilitiesSchema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "executionContextServerCapabilities",
    schema: MCP.ExecutionContextExtension.serverCapabilitiesSchema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "executionContextRequestMeta",
    schema: MCP.ExecutionContextExtension.requestMetaSchema->toUnknownSchema,
  },
  {dir: "mcp", name: "elicitRequest", schema: MCP.ElicitRequest.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "elicitRequestFormParams",
    schema: MCP.ElicitRequestFormParams.schema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "elicitRequestUrlParams",
    schema: MCP.ElicitRequestURLParams.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "parseError", schema: MCP.ParseError.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "invalidRequestError",
    schema: MCP.InvalidRequestError.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "jsonRpcRequest", schema: JsonRpc.Wire.requestSchema->toUnknownSchema},
  {dir: "mcp", name: "jsonRpcMessage", schema: JsonRpc.Wire.messageSchema->toUnknownSchema},
  {
    dir: "mcp",
    name: "methodNotFoundError",
    schema: MCP.MethodNotFoundError.schema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "invalidParamsError",
    schema: MCP.InvalidParamsError.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "internalError", schema: MCP.InternalError.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "headerMismatchError",
    schema: MCP.HeaderMismatchError.schema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "missingRequiredClientCapabilityError",
    schema: MCP.MissingRequiredClientCapabilityError.schema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "unsupportedProtocolVersionError",
    schema: MCP.UnsupportedProtocolVersionError.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "implementation", schema: MCP.Implementation.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "inputRequiredResult",
    schema: MCP.InputRequiredResult.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "inputRequests", schema: MCP.InputRequests.schema->toUnknownSchema},
  {dir: "mcp", name: "inputResponses", schema: MCP.InputResponses.schema->toUnknownSchema},
  {dir: "mcp", name: "listRootsRequest", schema: MCP.ListRootsRequest.schema->toUnknownSchema},
  {dir: "mcp", name: "listToolsRequest", schema: MCP.ListToolsRequest.schema->toUnknownSchema},
  {dir: "mcp", name: "listToolsResult", schema: MCP.ListToolsResult.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "listToolsResultResponse",
    schema: MCP.ListToolsResultResponse.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "metaObject", schema: MCPMetadata.schema->toUnknownSchema},
  {dir: "mcp", name: "modelHint", schema: MCP.ModelHint.schema->toUnknownSchema},
  {dir: "mcp", name: "modelPreferences", schema: MCP.ModelPreferences.schema->toUnknownSchema},
  {dir: "mcp", name: "notificationMeta", schema: MCP.NotificationMeta.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "primitiveSchemaDefinition",
    schema: MCP.PrimitiveSchemaDefinition.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "requestMeta", schema: MCP.RequestMeta.schema->toUnknownSchema},
  {dir: "mcp", name: "resultMeta", schema: MCP.ResultMeta.schema->toUnknownSchema},
  {dir: "mcp", name: "samplingMessage", schema: MCP.SamplingMessage.schema->toUnknownSchema},
  {
    dir: "mcp",
    name: "streamableHttpSseMessage",
    schema: MCP.StreamableHttpSseMessage.schema->toUnknownSchema,
  },
  {
    dir: "mcp",
    name: "serverCapabilities",
    schema: MCP.ServerCapabilities.schema->toUnknownSchema,
  },
  {dir: "mcp", name: "tool", schema: MCP.Tool.schema->toUnknownSchema},
  {dir: "mcp", name: "toolChoice", schema: MCP.ToolChoice.schema->toUnknownSchema},
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

    let jsonSchemaResult = try {
      Ok(entry.schema->S.toJSONSchema->jsonSchemaAsJson)
    } catch {
    | exn =>
      Error(exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error"))
    }

    switch jsonSchemaResult {
    | Ok(jsonSchema) =>
      let outPath = FrontmanBindings.Path.join([outDir, `${entry.name}.json`])
      await FrontmanBindings.Fs.Promises.writeFile(
        outPath,
        JSON.stringify(jsonSchema, ~space=2) ++ "\n",
      )
      totalExported := totalExported.contents + 1
    | Error(msg) =>
      Console.error(
        `Skipping ${entry.dir}/${entry.name}: schema not convertible to JSON Schema (${msg})`,
      )
      skipped := skipped.contents + 1
    }
  }

  Console.log(
    `Exported ${totalExported.contents->Int.toString} schemas to ${schemasDir}` ++ if (
      skipped.contents > 0
    ) {
      ` (${skipped.contents->Int.toString} skipped)`
    } else {
      ""
    },
  )
}

main()->ignore
