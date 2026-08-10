let protocolVersion = "2026-07-28"

module Metadata = FrontmanProtocol__MCPMetadata

module Extensions = {
  type settings = Dict.t<JSON.t>
  type t = Dict.t<settings>

  external toJson: t => JSON.t = "%identity"

  let jsonSchema: JSONSchema.t = {
    type_: JSONSchema.Arrayable.single(#object),
    additionalProperties: JSONSchema.Schema({
      type_: JSONSchema.Arrayable.single(#object),
    }),
    propertyNames: JSONSchema.Schema({
      allOf: [
        JSONSchema.Schema({pattern: FrontmanProtocol__MCPMetadata.keyPattern->RegExp.source}),
        JSONSchema.Schema({pattern: "/"}),
      ],
    }),
  }

  let schema =
    S.dict(S.dict(S.json))
    ->S.refine(value =>
      value
      ->Dict.keysToArray
      ->Array.every(key =>
        FrontmanProtocol__MCPMetadata.isValidKey(key) && key->String.includes("/")
      )
    , ~error="MCP extension identifiers require a valid prefix")
    ->S.extendJSONSchema(jsonSchema)
}

module ClientCapabilities = {
  type t = Dict.t<JSON.t>

  external toJson: t => JSON.t = "%identity"

  let jsonObjectSchema = S.dict(S.json)
  type elicitation = {
    form: option<Dict.t<JSON.t>>,
    url: option<Dict.t<JSON.t>>,
  }
  type sampling = {
    context: option<Dict.t<JSON.t>>,
    tools: option<Dict.t<JSON.t>>,
  }
  type knownFields = {
    elicitation: option<elicitation>,
    experimental: option<Dict.t<Dict.t<JSON.t>>>,
    extensions: option<Extensions.t>,
    roots: option<Dict.t<JSON.t>>,
    sampling: option<sampling>,
  }

  let elicitationSchema = S.object(s => {
    form: s.field("form", S.option(jsonObjectSchema)),
    url: s.field("url", S.option(jsonObjectSchema)),
  })
  let samplingSchema = S.object(s => {
    context: s.field("context", S.option(jsonObjectSchema)),
    tools: s.field("tools", S.option(jsonObjectSchema)),
  })
  let knownFieldsSchema = S.object(s => {
    elicitation: s.field("elicitation", S.option(elicitationSchema)),
    experimental: s.field("experimental", S.option(S.dict(jsonObjectSchema))),
    extensions: s.field("extensions", S.option(Extensions.schema)),
    roots: s.field("roots", S.option(jsonObjectSchema)),
    sampling: s.field("sampling", S.option(samplingSchema)),
  })

  let schema =
    S.dict(S.json)
    ->S.transform(_ => {
      parser: value => {
        value->toJson->S.parseOrThrow(~to=knownFieldsSchema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(knownFieldsSchema->S.toJSONSchema)
}

module ServerCapabilities = {
  type t = Dict.t<JSON.t>

  external toJson: t => JSON.t = "%identity"

  type listChanged = {listChanged: option<bool>}
  type resources = {
    listChanged: option<bool>,
    subscribe: option<bool>,
  }
  type knownFields = {
    completions: option<Dict.t<JSON.t>>,
    experimental: option<Dict.t<Dict.t<JSON.t>>>,
    extensions: option<Extensions.t>,
    logging: option<Dict.t<JSON.t>>,
    prompts: option<listChanged>,
    resources: option<resources>,
    tools: option<listChanged>,
  }

  let listChangedSchema = S.object(s => {
    listChanged: s.field("listChanged", S.option(S.bool)),
  })
  let resourcesSchema = S.object(s => {
    listChanged: s.field("listChanged", S.option(S.bool)),
    subscribe: s.field("subscribe", S.option(S.bool)),
  })
  let knownFieldsSchema = S.object(s => {
    completions: s.field("completions", S.option(ClientCapabilities.jsonObjectSchema)),
    experimental: s.field("experimental", S.option(S.dict(ClientCapabilities.jsonObjectSchema))),
    extensions: s.field("extensions", S.option(Extensions.schema)),
    logging: s.field("logging", S.option(ClientCapabilities.jsonObjectSchema)),
    prompts: s.field("prompts", S.option(listChangedSchema)),
    resources: s.field("resources", S.option(resourcesSchema)),
    tools: s.field("tools", S.option(listChangedSchema)),
  })

  let schema =
    S.dict(S.json)
    ->S.transform(_ => {
      parser: value => {
        value->toJson->S.parseOrThrow(~to=knownFieldsSchema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(knownFieldsSchema->S.toJSONSchema)
}

module Implementation = {
  type t = {
    name: string,
    version: string,
    title: option<string>,
    description: option<string>,
    websiteUrl: option<string>,
    icons: option<array<FrontmanProtocol__ContentBlock.icon>>,
  }

  let schema = S.object(s => {
    name: s.field("name", S.string),
    version: s.field("version", S.string),
    title: s.field("title", S.option(S.string)),
    description: s.field("description", S.option(S.string)),
    websiteUrl: s.field("websiteUrl", S.option(FrontmanProtocol__ContentBlock.uriSchema)),
    icons: s.field("icons", S.option(S.array(FrontmanProtocol__ContentBlock.iconSchema))),
  })
}

module LoggingLevel = {
  type t =
    | @as("alert") Alert
    | @as("critical") Critical
    | @as("debug") Debug
    | @as("emergency") Emergency
    | @as("error") Error
    | @as("info") Info
    | @as("notice") Notice
    | @as("warning") Warning

  let schema = S.union([
    S.literal(Alert),
    S.literal(Critical),
    S.literal(Debug),
    S.literal(Emergency),
    S.literal(Error),
    S.literal(Info),
    S.literal(Notice),
    S.literal(Warning),
  ])
}

module RequestMeta = {
  type t = FrontmanProtocol__MCPMetadata.t
  type knownFields = {
    protocolVersion: string,
    clientCapabilities: ClientCapabilities.t,
    clientInfo: option<Implementation.t>,
    logLevel: option<LoggingLevel.t>,
    progressToken: option<FrontmanProtocol__JsonRpc.Id.t>,
  }

  external toJson: t => JSON.t = "%identity"

  let knownFieldsSchema = S.object(s => {
    protocolVersion: s.field("io.modelcontextprotocol/protocolVersion", S.string),
    clientCapabilities: s.field(
      "io.modelcontextprotocol/clientCapabilities",
      ClientCapabilities.schema,
    ),
    clientInfo: s.field("io.modelcontextprotocol/clientInfo", S.option(Implementation.schema)),
    logLevel: s.field("io.modelcontextprotocol/logLevel", S.option(LoggingLevel.schema)),
    progressToken: s.field("progressToken", S.option(FrontmanProtocol__JsonRpc.Id.schema)),
  })
  let schema =
    FrontmanProtocol__MCPMetadata.schema
    ->S.transform(_ => {
      parser: value => {
        value->toJson->S.parseOrThrow(~to=knownFieldsSchema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(knownFieldsSchema->S.toJSONSchema)
}

module ResultMeta = {
  type t = FrontmanProtocol__MCPMetadata.t
  type knownFields = {serverInfo: option<Implementation.t>}

  external toJson: t => JSON.t = "%identity"

  let knownFieldsSchema = S.object(s => {
    serverInfo: s.field("io.modelcontextprotocol/serverInfo", S.option(Implementation.schema)),
  })

  let schema =
    FrontmanProtocol__MCPMetadata.schema
    ->S.transform(_ => {
      parser: value => {
        value->toJson->S.parseOrThrow(~to=knownFieldsSchema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(knownFieldsSchema->S.toJSONSchema)
}

module NotificationMeta = {
  type t = FrontmanProtocol__MCPMetadata.t
  type knownFields = {subscriptionId: option<FrontmanProtocol__JsonRpc.Id.t>}

  external toJson: t => JSON.t = "%identity"

  let knownFieldsSchema = S.object(s => {
    subscriptionId: s.field(
      "io.modelcontextprotocol/subscriptionId",
      S.option(FrontmanProtocol__JsonRpc.Id.schema),
    ),
  })

  let schema =
    FrontmanProtocol__MCPMetadata.schema
    ->S.transform(_ => {
      parser: value => {
        value->toJson->S.parseOrThrow(~to=knownFieldsSchema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(knownFieldsSchema->S.toJSONSchema)
}

module CacheScope = {
  type t = | @as("private") Private | @as("public") Public

  let schema = S.union([S.literal(Private), S.literal(Public)])
}

module CacheTtl = {
  @scope("Number") @val
  external isInteger: float => bool = "isInteger"

  let jsonSchema: JSONSchema.t = {
    type_: JSONSchema.Arrayable.single(#integer),
    minimum: 0.,
  }

  let schema =
    S.float
    ->S.refine(
      value => isInteger(value) && value >= 0.,
      ~error="MCP cache TTL must be non-negative",
    )
    ->S.extendJSONSchema(jsonSchema)
}

module ToolSchema = {
  type t = Dict.t<JSON.t>

  external toJson: t => JSON.t = "%identity"

  type inputKnownFields = {
    schemaDialect: option<string>,
    type_: string,
  }
  type outputKnownFields = {schemaDialect: option<string>}

  let inputKnownFieldsSchema = S.object(s => {
    schemaDialect: s.field("$schema", S.option(S.string)),
    type_: s.field("type", S.literal("object")),
  })
  let outputKnownFieldsSchema = S.object(s => {
    schemaDialect: s.field("$schema", S.option(S.string)),
  })

  let preserveWithSchema = knownFieldsSchema =>
    S.dict(S.json)
    ->S.transform(_ => {
      parser: value => {
        value->toJson->S.parseOrThrow(~to=knownFieldsSchema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(knownFieldsSchema->S.toJSONSchema)

  let inputSchema = preserveWithSchema(inputKnownFieldsSchema)
  let outputSchema = preserveWithSchema(outputKnownFieldsSchema)
}

module ToolAnnotations = {
  type t = Dict.t<JSON.t>

  external toJson: t => JSON.t = "%identity"

  type knownFields = {
    destructiveHint: option<bool>,
    idempotentHint: option<bool>,
    openWorldHint: option<bool>,
    readOnlyHint: option<bool>,
    title: option<string>,
  }

  let knownFieldsSchema = S.object(s => {
    destructiveHint: s.field("destructiveHint", S.option(S.bool)),
    idempotentHint: s.field("idempotentHint", S.option(S.bool)),
    openWorldHint: s.field("openWorldHint", S.option(S.bool)),
    readOnlyHint: s.field("readOnlyHint", S.option(S.bool)),
    title: s.field("title", S.option(S.string)),
  })

  let schema =
    S.dict(S.json)
    ->S.transform(_ => {
      parser: value => {
        value->toJson->S.parseOrThrow(~to=knownFieldsSchema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(knownFieldsSchema->S.toJSONSchema)
}

module Tool = {
  type t = {
    name: string,
    title: option<string>,
    description: option<string>,
    inputSchema: ToolSchema.t,
    outputSchema: option<ToolSchema.t>,
    icons: option<array<FrontmanProtocol__ContentBlock.icon>>,
    annotations: option<ToolAnnotations.t>,
    _meta: option<Metadata.t>,
  }

  let schema = S.object(s => {
    name: s.field("name", S.string),
    title: s.field("title", S.option(S.string)),
    description: s.field("description", S.option(S.string)),
    inputSchema: s.field("inputSchema", ToolSchema.inputSchema),
    outputSchema: s.field("outputSchema", S.option(ToolSchema.outputSchema)),
    icons: s.field("icons", S.option(S.array(FrontmanProtocol__ContentBlock.iconSchema))),
    annotations: s.field("annotations", S.option(ToolAnnotations.schema)),
    _meta: s.field("_meta", S.option(Metadata.schema)),
  })
}

module DiscoverRequest = {
  type params = {_meta: RequestMeta.t}
  type t = {
    jsonrpc: string,
    id: FrontmanProtocol__JsonRpc.Id.t,
    method: string,
    params: params,
  }

  let paramsSchema = S.object(s => {
    _meta: s.field("_meta", RequestMeta.schema),
  })

  let schema = S.object(s => {
    jsonrpc: s.field("jsonrpc", S.literal("2.0")),
    id: s.field("id", FrontmanProtocol__JsonRpc.Id.schema),
    method: s.field("method", S.literal("server/discover")),
    params: s.field("params", paramsSchema),
  })
}

module DiscoverResult = {
  type t = {
    resultType: string,
    supportedVersions: array<string>,
    capabilities: ServerCapabilities.t,
    _meta: option<ResultMeta.t>,
    instructions: option<string>,
    ttlMs: float,
    cacheScope: CacheScope.t,
  }

  let schema = S.object(s => {
    resultType: s.field("resultType", S.string),
    supportedVersions: s.field("supportedVersions", S.array(S.string)),
    capabilities: s.field("capabilities", ServerCapabilities.schema),
    _meta: s.field("_meta", S.option(ResultMeta.schema)),
    instructions: s.field("instructions", S.option(S.string)),
    ttlMs: s.field("ttlMs", CacheTtl.schema),
    cacheScope: s.field("cacheScope", CacheScope.schema),
  })
}

module DiscoverResultResponse = {
  type t = {
    jsonrpc: string,
    id: FrontmanProtocol__JsonRpc.Id.t,
    result: DiscoverResult.t,
  }

  let schema = S.object(s => {
    jsonrpc: s.field("jsonrpc", S.literal("2.0")),
    id: s.field("id", FrontmanProtocol__JsonRpc.Id.schema),
    result: s.field("result", DiscoverResult.schema),
  })
}

module ListToolsRequest = {
  type params = {
    _meta: RequestMeta.t,
    cursor: option<string>,
  }
  type t = {
    jsonrpc: string,
    id: FrontmanProtocol__JsonRpc.Id.t,
    method: string,
    params: params,
  }

  let paramsSchema = S.object(s => {
    _meta: s.field("_meta", RequestMeta.schema),
    cursor: s.field("cursor", S.option(S.string)),
  })

  let schema = S.object(s => {
    jsonrpc: s.field("jsonrpc", S.literal("2.0")),
    id: s.field("id", FrontmanProtocol__JsonRpc.Id.schema),
    method: s.field("method", S.literal("tools/list")),
    params: s.field("params", paramsSchema),
  })
}

module ListToolsResult = {
  type t = {
    resultType: string,
    tools: array<Tool.t>,
    nextCursor: option<string>,
    ttlMs: float,
    cacheScope: CacheScope.t,
    _meta: option<ResultMeta.t>,
  }

  let schema = S.object(s => {
    resultType: s.field("resultType", S.string),
    tools: s.field("tools", S.array(Tool.schema)),
    nextCursor: s.field("nextCursor", S.option(S.string)),
    ttlMs: s.field("ttlMs", CacheTtl.schema),
    cacheScope: s.field("cacheScope", CacheScope.schema),
    _meta: s.field("_meta", S.option(ResultMeta.schema)),
  })
}

module ListToolsResultResponse = {
  type t = {
    jsonrpc: string,
    id: FrontmanProtocol__JsonRpc.Id.t,
    result: ListToolsResult.t,
  }

  let schema = S.object(s => {
    jsonrpc: s.field("jsonrpc", S.literal("2.0")),
    id: s.field("id", FrontmanProtocol__JsonRpc.Id.schema),
    result: s.field("result", ListToolsResult.schema),
  })
}

let preserveJsonWithSchema = schema =>
  S.json
  ->S.transform(_ => {
    parser: value => {
      value->S.parseOrThrow(~to=schema)->ignore
      value
    },
    serializer: value => value,
  })
  ->S.extendJSONSchema(schema->S.toJSONSchema)

module ExecutionContextExtension = {
  let identifier = "ai.frontman/execution-context"

  type settingsFields = {version: int}
  type contextFields = {
    taskId: string,
    toolCallId: string,
  }
  type extensionsFields = {executionContext: JSON.t}
  type clientCapabilitiesFields = {extensions: Extensions.t}
  type serverCapabilitiesFields = {extensions: Extensions.t}
  type requestMetaFields = {executionContext: JSON.t}
  type missingServerSupport = {
    reason: string,
    extension: string,
    requiredVersion: int,
  }

  let nonEmptyStringJsonSchema: JSONSchema.t = {
    type_: JSONSchema.Arrayable.single(#string),
    minLength: 1,
  }
  let nonEmptyStringSchema =
    S.string
    ->S.refine(value => value->String.length > 0, ~error="Execution context IDs must not be empty")
    ->S.extendJSONSchema(nonEmptyStringJsonSchema)
  let settingsKnownFieldsSchema = S.object(s => {
    version: s.field("version", S.literal(1)),
  })
  let settingsSchema = preserveJsonWithSchema(settingsKnownFieldsSchema)
  let contextKnownFieldsSchema = S.object(s => {
    taskId: s.field("taskId", nonEmptyStringSchema),
    toolCallId: s.field("toolCallId", nonEmptyStringSchema),
  })
  let contextSchema = preserveJsonWithSchema(contextKnownFieldsSchema)
  let extensionsKnownFieldsSchema = S.object(s => {
    executionContext: s.field(identifier, settingsSchema),
  })
  let extensionsJsonSchema: JSONSchema.t = {
    allOf: [
      JSONSchema.Schema(Extensions.schema->S.toJSONSchema),
      JSONSchema.Schema(extensionsKnownFieldsSchema->S.toJSONSchema),
    ],
  }
  let extensionsSchema =
    Extensions.schema
    ->S.transform(_ => {
      parser: value => {
        value->Extensions.toJson->S.parseOrThrow(~to=extensionsKnownFieldsSchema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(extensionsJsonSchema)
  let clientCapabilitiesKnownFieldsSchema = S.object(s => {
    extensions: s.field("extensions", extensionsSchema),
  })
  let clientCapabilitiesJsonSchema: JSONSchema.t = {
    allOf: [
      JSONSchema.Schema(ClientCapabilities.schema->S.toJSONSchema),
      JSONSchema.Schema(clientCapabilitiesKnownFieldsSchema->S.toJSONSchema),
    ],
  }
  let clientCapabilitiesSchema =
    ClientCapabilities.schema
    ->S.transform(_ => {
      parser: value => {
        value
        ->ClientCapabilities.toJson
        ->S.parseOrThrow(~to=clientCapabilitiesKnownFieldsSchema)
        ->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(clientCapabilitiesJsonSchema)
  let serverCapabilitiesKnownFieldsSchema = S.object(s => {
    extensions: s.field("extensions", extensionsSchema),
  })
  let serverCapabilitiesJsonSchema: JSONSchema.t = {
    allOf: [
      JSONSchema.Schema(ServerCapabilities.schema->S.toJSONSchema),
      JSONSchema.Schema(serverCapabilitiesKnownFieldsSchema->S.toJSONSchema),
    ],
  }
  let serverCapabilitiesSchema =
    ServerCapabilities.schema
    ->S.transform(_ => {
      parser: value => {
        value
        ->ServerCapabilities.toJson
        ->S.parseOrThrow(~to=serverCapabilitiesKnownFieldsSchema)
        ->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(serverCapabilitiesJsonSchema)
  let requestMetaKnownFieldsSchema = S.object(s => {
    executionContext: s.field(identifier, contextSchema),
  })
  let requestMetaJsonSchema: JSONSchema.t = {
    allOf: [
      JSONSchema.Schema(RequestMeta.schema->S.toJSONSchema),
      JSONSchema.Schema(requestMetaKnownFieldsSchema->S.toJSONSchema),
    ],
  }
  let requestMetaSchema =
    RequestMeta.schema
    ->S.transform(_ => {
      parser: value => {
        value->RequestMeta.toJson->S.parseOrThrow(~to=requestMetaKnownFieldsSchema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(requestMetaJsonSchema)
  let missingServerSupport: missingServerSupport = {
    reason: "missing_required_server_extension",
    extension: identifier,
    requiredVersion: 1,
  }

  let extensions = (): Extensions.t =>
    Dict.fromArray([(identifier, Dict.fromArray([("version", JSON.Encode.int(1))]))])

  let clientCapabilities = (): ClientCapabilities.t =>
    Dict.fromArray([("extensions", extensions()->Extensions.toJson)])

  let serverCapabilities = (): ServerCapabilities.t =>
    Dict.fromArray([
      ("tools", JSON.Encode.object(Dict.make())),
      ("extensions", extensions()->Extensions.toJson),
    ])

  let requestMetaFields = (meta: RequestMeta.t): RequestMeta.knownFields =>
    meta->RequestMeta.toJson->S.parseOrThrow(~to=RequestMeta.knownFieldsSchema)

  let validateClientCapabilities = (meta: RequestMeta.t): unit => {
    let fields = meta->requestMetaFields
    fields.clientCapabilities
    ->ClientCapabilities.toJson
    ->S.parseOrThrow(~to=clientCapabilitiesSchema)
    ->ignore
  }

  let executionContext = (meta: RequestMeta.t): contextFields => {
    meta->S.parseOrThrow(~to=requestMetaSchema)->ignore
    meta
    ->Dict.get(identifier)
    ->Option.getOrThrow
    ->S.parseOrThrow(~to=contextKnownFieldsSchema)
  }
}

module NamedError = {
  type fields = {
    code: int,
    message: string,
    data: option<JSON.t>,
  }

  let schema = code =>
    preserveJsonWithSchema(
      S.object(s => {
        let value: fields = {
          code: s.field("code", S.literal(code)),
          message: s.field("message", S.string),
          data: s.field("data", S.option(S.json)),
        }
        value
      }),
    )
}

module ModernErrorCode = {
  let parseError = -32700
  let invalidRequest = -32600
  let methodNotFound = -32601
  let invalidParams = -32602
  let internalError = -32603
  let headerMismatch = -32020
  let missingRequiredClientCapability = -32021
  let unsupportedProtocolVersion = -32022
  let mcpReserved = [headerMismatch, missingRequiredClientCapability, unsupportedProtocolVersion]
}

module ParseError = {
  type t = JSON.t
  let schema = NamedError.schema(ModernErrorCode.parseError)
}

module InvalidRequestError = {
  type t = JSON.t
  let schema = NamedError.schema(ModernErrorCode.invalidRequest)
}

module MethodNotFoundError = {
  type t = JSON.t
  let schema = NamedError.schema(ModernErrorCode.methodNotFound)
}

module InvalidParamsError = {
  type t = JSON.t
  let schema = NamedError.schema(ModernErrorCode.invalidParams)
}

module InternalError = {
  type t = JSON.t
  let schema = NamedError.schema(ModernErrorCode.internalError)
}

module NamedErrorResponse = {
  type fields = {
    jsonrpc: string,
    id: option<FrontmanProtocol__JsonRpc.Id.t>,
    error: JSON.t,
  }

  let schema = errorSchema =>
    preserveJsonWithSchema(
      S.object(s => {
        let value: fields = {
          jsonrpc: s.field("jsonrpc", S.literal("2.0")),
          id: s.field("id", S.option(FrontmanProtocol__JsonRpc.Id.schema)),
          error: s.field("error", errorSchema),
        }
        value
      }),
    )
}

module HeaderMismatchError = {
  type t = JSON.t
  let schema = NamedErrorResponse.schema(NamedError.schema(ModernErrorCode.headerMismatch))
}

module MissingRequiredClientCapabilityError = {
  type dataFields = {requiredCapabilities: ClientCapabilities.t}
  type errorFields = {
    code: int,
    message: string,
    data: dataFields,
  }
  type t = JSON.t

  let dataSchema = S.object(s => {
    requiredCapabilities: s.field("requiredCapabilities", ClientCapabilities.schema),
  })
  let errorSchema = preserveJsonWithSchema(
    S.object(s => {
      let value: errorFields = {
        code: s.field("code", S.literal(ModernErrorCode.missingRequiredClientCapability)),
        message: s.field("message", S.string),
        data: s.field("data", dataSchema),
      }
      value
    }),
  )
  let schema = NamedErrorResponse.schema(errorSchema)
}

module UnsupportedProtocolVersionError = {
  type dataFields = {
    requested: string,
    supported: array<string>,
  }
  type errorFields = {
    code: int,
    message: string,
    data: dataFields,
  }
  type t = JSON.t

  let dataSchema = S.object(s => {
    requested: s.field("requested", S.string),
    supported: s.field("supported", S.array(S.string)),
  })
  let errorSchema = preserveJsonWithSchema(
    S.object(s => {
      let value: errorFields = {
        code: s.field("code", S.literal(ModernErrorCode.unsupportedProtocolVersion)),
        message: s.field("message", S.string),
        data: s.field("data", dataSchema),
      }
      value
    }),
  )
  let schema = NamedErrorResponse.schema(errorSchema)
}

module CancelledNotificationParams = {
  type knownFields = {
    requestId: FrontmanProtocol__JsonRpc.Id.t,
    reason: option<string>,
    _meta: option<NotificationMeta.t>,
  }
  type t = JSON.t

  let knownFieldsSchema = S.object(s => {
    requestId: s.field("requestId", FrontmanProtocol__JsonRpc.Id.schema),
    reason: s.field("reason", S.option(S.string)),
    _meta: s.field("_meta", S.option(NotificationMeta.schema)),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module CancelledNotification = {
  type knownFields = {
    jsonrpc: string,
    method: string,
    params: JSON.t,
  }
  type t = JSON.t

  let knownFieldsSchema = S.object(s => {
    jsonrpc: s.field("jsonrpc", S.literal("2.0")),
    method: s.field("method", S.literal("notifications/cancelled")),
    params: s.field("params", CancelledNotificationParams.schema),
  })
  let jsonSchema: JSONSchema.t = {
    allOf: [
      JSONSchema.Schema(knownFieldsSchema->S.toJSONSchema),
      JSONSchema.Schema({properties: Dict.fromArray([("id", JSONSchema.Never)])}),
    ],
  }
  let schema =
    preserveJsonWithSchema(knownFieldsSchema)
    ->S.refine(value =>
      switch value->JSON.Decode.object {
      | Some(fields) => !(fields->Dict.has("id"))
      | None => false
      }
    , ~error="MCP notifications must not include an id")
    ->S.extendJSONSchema(jsonSchema)
}

module StreamableHttpSseMessage = {
  type t = JSON.t

  let schema = S.union([
    FrontmanProtocol__JsonRpc.Wire.notificationSchema,
    FrontmanProtocol__JsonRpc.Wire.responseSchema,
  ])
}

module ElicitResult = {
  type action = | @as("accept") Accept | @as("cancel") Cancel | @as("decline") Decline
  type t = {
    action: action,
    content: option<Dict.t<JSON.t>>,
  }

  let actionSchema = S.union([S.literal(Accept), S.literal(Cancel), S.literal(Decline)])
  let contentValueSchema = S.union([
    preserveJsonWithSchema(S.string),
    preserveJsonWithSchema(FrontmanProtocol__ContentBlock.integerSchema),
    preserveJsonWithSchema(S.bool),
    preserveJsonWithSchema(S.array(S.string)),
  ])
  let schema = S.object(s => {
    action: s.field("action", actionSchema),
    content: s.field("content", S.option(S.dict(contentValueSchema))),
  })
}

module ListRootsResult = {
  type root = {
    uri: string,
    name: option<string>,
    _meta: option<Metadata.t>,
  }
  type t = {roots: array<root>}

  let fileUriJsonSchema: JSONSchema.t = {
    type_: JSONSchema.Arrayable.single(#string),
    format: "uri",
    pattern: "^[Ff][Ii][Ll][Ee]://",
  }
  let fileUriSchema =
    S.url
    ->S.refine(
      value => value->String.toLowerCase->String.startsWith("file://"),
      ~error="Root URI must use the file scheme",
    )
    ->S.extendJSONSchema(fileUriJsonSchema)
  let rootSchema = S.object(s => {
    uri: s.field("uri", fileUriSchema),
    name: s.field("name", S.option(S.string)),
    _meta: s.field("_meta", S.option(Metadata.schema)),
  })
  let schema = S.object(s => {
    roots: s.field("roots", S.array(rootSchema)),
  })
}

module SamplingContent = {
  type toolUse = {
    id: string,
    name: string,
    input: Dict.t<JSON.t>,
    _meta: option<Metadata.t>,
  }
  type toolResult = {
    toolUseId: string,
    content: array<FrontmanProtocol__ContentBlock.t>,
    structuredContent: option<JSON.t>,
    isError: option<bool>,
    _meta: option<Metadata.t>,
  }

  let toolUseSchema = S.object(s => {
    s.tag("type", "tool_use")
    {
      id: s.field("id", S.string),
      name: s.field("name", S.string),
      input: s.field("input", S.dict(S.json)),
      _meta: s.field("_meta", S.option(Metadata.schema)),
    }
  })
  let toolResultSchema = S.object(s => {
    s.tag("type", "tool_result")
    {
      toolUseId: s.field("toolUseId", S.string),
      content: s.field("content", S.array(FrontmanProtocol__ContentBlock.schema)),
      structuredContent: s.field("structuredContent", S.option(S.json)),
      isError: s.field("isError", S.option(S.bool)),
      _meta: s.field("_meta", S.option(Metadata.schema)),
    }
  })
  let singleSchema = S.union([
    preserveJsonWithSchema(FrontmanProtocol__ContentBlock.textContentSchema),
    preserveJsonWithSchema(FrontmanProtocol__ContentBlock.imageContentSchema),
    preserveJsonWithSchema(FrontmanProtocol__ContentBlock.audioContentSchema),
    preserveJsonWithSchema(toolUseSchema),
    preserveJsonWithSchema(toolResultSchema),
  ])
  let schema = S.union([singleSchema, preserveJsonWithSchema(S.array(singleSchema))])
}

module CreateMessageResult = {
  type t = {
    role: FrontmanProtocol__ContentBlock.role,
    content: JSON.t,
    model: string,
    stopReason: option<string>,
    _meta: option<Metadata.t>,
  }

  let schema = S.object(s => {
    role: s.field("role", FrontmanProtocol__ContentBlock.roleSchema),
    content: s.field("content", SamplingContent.schema),
    model: s.field("model", S.string),
    stopReason: s.field("stopReason", S.option(S.string)),
    _meta: s.field("_meta", S.option(Metadata.schema)),
  })
}

module InputResponse = {
  let schema = S.union([
    preserveJsonWithSchema(CreateMessageResult.schema),
    preserveJsonWithSchema(ListRootsResult.schema),
    preserveJsonWithSchema(ElicitResult.schema),
  ])
}

module InputResponses = {
  type t = Dict.t<JSON.t>

  let schema = S.dict(InputResponse.schema)
}

module PrimitiveSchemaDefinition = {
  type enumOption = {
    const: string,
    title: string,
  }
  type stringSchema = {
    type_: string,
    title: option<string>,
    description: option<string>,
    minLength: option<float>,
    maxLength: option<float>,
    format: option<string>,
    default: option<string>,
  }
  type numberSchema = {
    type_: string,
    title: option<string>,
    description: option<string>,
    minimum: option<float>,
    maximum: option<float>,
    default: option<float>,
  }
  type booleanSchema = {
    type_: string,
    title: option<string>,
    description: option<string>,
    default: option<bool>,
  }
  type untitledSingle = {
    type_: string,
    title: option<string>,
    description: option<string>,
    enum: array<string>,
    default: option<string>,
  }
  type titledSingle = {
    type_: string,
    title: option<string>,
    description: option<string>,
    oneOf: array<enumOption>,
    default: option<string>,
  }
  type legacyTitled = {
    type_: string,
    title: option<string>,
    description: option<string>,
    enum: array<string>,
    enumNames: option<array<string>>,
    default: option<string>,
  }
  type untitledItems = {
    type_: string,
    enum: array<string>,
  }
  type titledItems = {anyOf: array<enumOption>}
  type untitledMulti = {
    type_: string,
    title: option<string>,
    description: option<string>,
    items: untitledItems,
    minItems: option<float>,
    maxItems: option<float>,
    default: option<array<string>>,
  }
  type titledMulti = {
    type_: string,
    title: option<string>,
    description: option<string>,
    items: titledItems,
    minItems: option<float>,
    maxItems: option<float>,
    default: option<array<string>>,
  }

  let nonNegativeIntegerJsonSchema: JSONSchema.t = {
    type_: JSONSchema.Arrayable.single(#integer),
    minimum: 0.,
  }
  let nonNegativeIntegerSchema =
    FrontmanProtocol__ContentBlock.integerSchema
    ->S.refine(value => value >= 0., ~error="Schema bound must be non-negative")
    ->S.extendJSONSchema(nonNegativeIntegerJsonSchema)

  let optionSchema = S.object(s => {
    const: s.field("const", S.string),
    title: s.field("title", S.string),
  })
  let stringSchema = S.object(s => {
    type_: s.field("type", S.literal("string")),
    title: s.field("title", S.option(S.string)),
    description: s.field("description", S.option(S.string)),
    minLength: s.field("minLength", S.option(nonNegativeIntegerSchema)),
    maxLength: s.field("maxLength", S.option(nonNegativeIntegerSchema)),
    format: s.field(
      "format",
      S.option(
        S.union([S.literal("date"), S.literal("date-time"), S.literal("email"), S.literal("uri")]),
      ),
    ),
    default: s.field("default", S.option(S.string)),
  })
  let numberSchema = S.object(s => {
    type_: s.field("type", S.union([S.literal("integer"), S.literal("number")])),
    title: s.field("title", S.option(S.string)),
    description: s.field("description", S.option(S.string)),
    minimum: s.field("minimum", S.option(S.float)),
    maximum: s.field("maximum", S.option(S.float)),
    default: s.field("default", S.option(S.float)),
  })
  let booleanSchema = S.object(s => {
    type_: s.field("type", S.literal("boolean")),
    title: s.field("title", S.option(S.string)),
    description: s.field("description", S.option(S.string)),
    default: s.field("default", S.option(S.bool)),
  })
  let untitledSingleSchema = S.object(s => {
    type_: s.field("type", S.literal("string")),
    title: s.field("title", S.option(S.string)),
    description: s.field("description", S.option(S.string)),
    enum: s.field("enum", S.array(S.string)),
    default: s.field("default", S.option(S.string)),
  })
  let titledSingleSchema = S.object(s => {
    type_: s.field("type", S.literal("string")),
    title: s.field("title", S.option(S.string)),
    description: s.field("description", S.option(S.string)),
    oneOf: s.field("oneOf", S.array(optionSchema)),
    default: s.field("default", S.option(S.string)),
  })
  let legacyTitledSchema = S.object(s => {
    type_: s.field("type", S.literal("string")),
    title: s.field("title", S.option(S.string)),
    description: s.field("description", S.option(S.string)),
    enum: s.field("enum", S.array(S.string)),
    enumNames: s.field("enumNames", S.option(S.array(S.string))),
    default: s.field("default", S.option(S.string)),
  })
  let untitledItemsSchema = S.object(s => {
    type_: s.field("type", S.literal("string")),
    enum: s.field("enum", S.array(S.string)),
  })
  let titledItemsSchema = S.object(s => {
    anyOf: s.field("anyOf", S.array(optionSchema)),
  })
  let untitledMultiSchema = S.object(s => {
    let value: untitledMulti = {
      type_: s.field("type", S.literal("array")),
      title: s.field("title", S.option(S.string)),
      description: s.field("description", S.option(S.string)),
      items: s.field("items", untitledItemsSchema),
      minItems: s.field("minItems", S.option(nonNegativeIntegerSchema)),
      maxItems: s.field("maxItems", S.option(nonNegativeIntegerSchema)),
      default: s.field("default", S.option(S.array(S.string))),
    }
    value
  })
  let titledMultiSchema = S.object(s => {
    let value: titledMulti = {
      type_: s.field("type", S.literal("array")),
      title: s.field("title", S.option(S.string)),
      description: s.field("description", S.option(S.string)),
      items: s.field("items", titledItemsSchema),
      minItems: s.field("minItems", S.option(nonNegativeIntegerSchema)),
      maxItems: s.field("maxItems", S.option(nonNegativeIntegerSchema)),
      default: s.field("default", S.option(S.array(S.string))),
    }
    value
  })
  let schema = S.union([
    preserveJsonWithSchema(stringSchema),
    preserveJsonWithSchema(numberSchema),
    preserveJsonWithSchema(booleanSchema),
    preserveJsonWithSchema(untitledSingleSchema),
    preserveJsonWithSchema(titledSingleSchema),
    preserveJsonWithSchema(untitledMultiSchema),
    preserveJsonWithSchema(titledMultiSchema),
    preserveJsonWithSchema(legacyTitledSchema),
  ])
}

module ElicitRequestFormParams = {
  type requestedSchema = {
    schemaDialect: option<string>,
    type_: string,
    properties: Dict.t<JSON.t>,
    required: option<array<string>>,
  }
  type knownFields = {
    mode: option<string>,
    message: string,
    requestedSchema: requestedSchema,
  }
  type t = JSON.t

  let requestedSchemaSchema = S.object(s => {
    schemaDialect: s.field("$schema", S.option(S.string)),
    type_: s.field("type", S.literal("object")),
    properties: s.field("properties", S.dict(PrimitiveSchemaDefinition.schema)),
    required: s.field("required", S.option(S.array(S.string))),
  })
  let knownFieldsSchema = S.object(s => {
    mode: s.field("mode", S.option(S.literal("form"))),
    message: s.field("message", S.string),
    requestedSchema: s.field("requestedSchema", requestedSchemaSchema),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module ElicitRequestURLParams = {
  type knownFields = {
    mode: string,
    message: string,
    url: string,
  }
  type t = JSON.t

  let knownFieldsSchema = S.object(s => {
    mode: s.field("mode", S.literal("url")),
    message: s.field("message", S.string),
    url: s.field("url", FrontmanProtocol__ContentBlock.uriSchema),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module ElicitRequest = {
  type knownFields = {
    method: string,
    params: JSON.t,
  }
  type t = JSON.t

  let paramsSchema = S.union([ElicitRequestFormParams.schema, ElicitRequestURLParams.schema])
  let knownFieldsSchema = S.object(s => {
    method: s.field("method", S.literal("elicitation/create")),
    params: s.field("params", paramsSchema),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module ModelHint = {
  type knownFields = {name: option<string>}
  type t = JSON.t

  let knownFieldsSchema = S.object(s => {
    name: s.field("name", S.option(S.string)),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module ModelPreferences = {
  type knownFields = {
    hints: option<array<JSON.t>>,
    costPriority: option<float>,
    intelligencePriority: option<float>,
    speedPriority: option<float>,
  }
  type t = JSON.t

  let knownFieldsSchema = S.object(s => {
    hints: s.field("hints", S.option(S.array(ModelHint.schema))),
    costPriority: s.field("costPriority", S.option(FrontmanProtocol__ContentBlock.prioritySchema)),
    intelligencePriority: s.field(
      "intelligencePriority",
      S.option(FrontmanProtocol__ContentBlock.prioritySchema),
    ),
    speedPriority: s.field(
      "speedPriority",
      S.option(FrontmanProtocol__ContentBlock.prioritySchema),
    ),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module ToolChoice = {
  type knownFields = {mode: option<string>}
  type t = JSON.t

  let knownFieldsSchema = S.object(s => {
    mode: s.field(
      "mode",
      S.option(S.union([S.literal("auto"), S.literal("none"), S.literal("required")])),
    ),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module SamplingMessage = {
  type validated = {
    role: FrontmanProtocol__ContentBlock.role,
    content: array<JSON.t>,
    _meta: option<Metadata.t>,
  }
  type knownFields = {
    role: FrontmanProtocol__ContentBlock.role,
    content: JSON.t,
    _meta: option<Metadata.t>,
  }
  type t = JSON.t

  let singleContentSchema =
    SamplingContent.singleSchema
    ->S.transform(_ => {
      parser: value => [value],
      serializer: values => values->Array.getUnsafe(0),
    })
    ->S.extendJSONSchema(SamplingContent.singleSchema->S.toJSONSchema)
  let contentSchema =
    S.union([singleContentSchema, S.array(SamplingContent.singleSchema)])->S.extendJSONSchema(
      SamplingContent.schema->S.toJSONSchema,
    )
  let validationSchema = S.object(s => {
    let value: validated = {
      role: s.field("role", FrontmanProtocol__ContentBlock.roleSchema),
      content: s.field("content", contentSchema),
      _meta: s.field("_meta", S.option(Metadata.schema)),
    }
    value
  })
  let knownFieldsSchema = S.object(s => {
    let value: knownFields = {
      role: s.field("role", FrontmanProtocol__ContentBlock.roleSchema),
      content: s.field("content", SamplingContent.schema),
      _meta: s.field("_meta", S.option(Metadata.schema)),
    }
    value
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)

  let toolUseId = block =>
    try {
      let parsed = S.parseOrThrow(block, ~to=SamplingContent.toolUseSchema)
      Some(parsed.id)
    } catch {
    | _ => None
    }
  let toolResultId = block =>
    try {
      let parsed = S.parseOrThrow(block, ~to=SamplingContent.toolResultSchema)
      Some(parsed.toolUseId)
    } catch {
    | _ => None
    }
  let idsMatch = (expected, actual) =>
    expected->Array.length === actual->Array.length &&
    expected->Array.every(id =>
      actual->Array.filter(actualId => actualId === id)->Array.length === 1
    ) &&
    actual->Array.every(id =>
      expected->Array.filter(expectedId => expectedId === id)->Array.length === 1
    )

  let sequenceIsValid = (messages: array<validated>) => {
    let valid = ref(true)

    for index in 0 to messages->Array.length - 1 {
      let message = messages->Array.getUnsafe(index)
      let toolUseIds = message.content->Array.filterMap(toolUseId)
      let toolResultIds = message.content->Array.filterMap(toolResultId)

      switch (message.role, toolUseIds->Array.length, toolResultIds->Array.length) {
      | (User, uses, _) if uses > 0 => valid := false
      | (Assistant, _, results) if results > 0 => valid := false
      | (User, _, results) if results > 0 =>
        let previous = messages->Array.get(index - 1)
        switch previous {
        | Some({role: Assistant, content}) =>
          let previousUseIds = content->Array.filterMap(toolUseId)
          switch previousUseIds->Array.length > 0 {
          | true => ()
          | false => valid := false
          }
        | _ => valid := false
        }
      | (Assistant, uses, _) if uses > 0 =>
        let next = messages->Array.get(index + 1)
        switch next {
        | Some({role: User, content}) =>
          let nextResultIds = content->Array.filterMap(toolResultId)
          switch nextResultIds->Array.length === content->Array.length &&
            idsMatch(toolUseIds, nextResultIds) {
          | true => ()
          | false => valid := false
          }
        | _ => valid := false
        }
      | _ => ()
      }
    }

    valid.contents
  }
}

module CreateMessageRequestParams = {
  type knownFields = {
    messages: array<SamplingMessage.validated>,
    modelPreferences: option<JSON.t>,
    systemPrompt: option<string>,
    includeContext: option<string>,
    temperature: option<float>,
    maxTokens: float,
    stopSequences: option<array<string>>,
    metadata: option<Dict.t<JSON.t>>,
    tools: option<array<Tool.t>>,
    toolChoice: option<JSON.t>,
  }
  type t = JSON.t

  let knownFieldsSchema = S.object(s => {
    messages: s.field(
      "messages",
      S.array(SamplingMessage.validationSchema)->S.refine(
        SamplingMessage.sequenceIsValid,
        ~error="Sampling tool use and result messages must be balanced",
      ),
    ),
    modelPreferences: s.field("modelPreferences", S.option(ModelPreferences.schema)),
    systemPrompt: s.field("systemPrompt", S.option(S.string)),
    includeContext: s.field(
      "includeContext",
      S.option(S.union([S.literal("allServers"), S.literal("none"), S.literal("thisServer")])),
    ),
    temperature: s.field("temperature", S.option(S.float)),
    maxTokens: s.field("maxTokens", FrontmanProtocol__ContentBlock.integerSchema),
    stopSequences: s.field("stopSequences", S.option(S.array(S.string))),
    metadata: s.field("metadata", S.option(S.dict(S.json))),
    tools: s.field("tools", S.option(S.array(Tool.schema))),
    toolChoice: s.field("toolChoice", S.option(ToolChoice.schema)),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module CreateMessageRequest = {
  type knownFields = {
    method: string,
    params: JSON.t,
  }
  type t = JSON.t

  let knownFieldsSchema = S.object(s => {
    method: s.field("method", S.literal("sampling/createMessage")),
    params: s.field("params", CreateMessageRequestParams.schema),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module ListRootsRequest = {
  type params = {_meta: option<Metadata.t>}
  type knownFields = {
    method: string,
    params: option<params>,
  }
  type t = JSON.t

  let paramsSchema = S.object(s => {
    _meta: s.field("_meta", S.option(Metadata.schema)),
  })
  let knownFieldsSchema = S.object(s => {
    method: s.field("method", S.literal("roots/list")),
    params: s.field("params", S.option(paramsSchema)),
  })
  let schema = preserveJsonWithSchema(knownFieldsSchema)
}

module InputRequest = {
  let schema = S.union([CreateMessageRequest.schema, ListRootsRequest.schema, ElicitRequest.schema])
}

module InputRequests = {
  type t = Dict.t<JSON.t>

  let schema = S.dict(InputRequest.schema)
}

module InputRequiredResult = {
  type withInputRequests = {
    resultType: string,
    inputRequests: InputRequests.t,
    requestState: option<string>,
    _meta: option<ResultMeta.t>,
  }
  type withRequestState = {
    resultType: string,
    inputRequests: option<InputRequests.t>,
    requestState: string,
    _meta: option<ResultMeta.t>,
  }
  type t = JSON.t

  let withInputRequestsSchema = S.object(s => {
    let value: withInputRequests = {
      resultType: s.field("resultType", S.literal("input_required")),
      inputRequests: s.field("inputRequests", InputRequests.schema),
      requestState: s.field("requestState", S.option(S.string)),
      _meta: s.field("_meta", S.option(ResultMeta.schema)),
    }
    value
  })
  let withRequestStateSchema = S.object(s => {
    let value: withRequestState = {
      resultType: s.field("resultType", S.literal("input_required")),
      inputRequests: s.field("inputRequests", S.option(InputRequests.schema)),
      requestState: s.field("requestState", S.string),
      _meta: s.field("_meta", S.option(ResultMeta.schema)),
    }
    value
  })
  let schema = S.union([
    preserveJsonWithSchema(withInputRequestsSchema),
    preserveJsonWithSchema(withRequestStateSchema),
  ])
}

module CallToolRequestParams = {
  type t = {
    _meta: RequestMeta.t,
    name: string,
    arguments: option<Dict.t<JSON.t>>,
    inputResponses: option<InputResponses.t>,
    requestState: option<string>,
  }

  let schema = S.object(s => {
    _meta: s.field("_meta", RequestMeta.schema),
    name: s.field("name", S.string),
    arguments: s.field("arguments", S.option(S.dict(S.json))),
    inputResponses: s.field("inputResponses", S.option(InputResponses.schema)),
    requestState: s.field("requestState", S.option(S.string)),
  })
}

module CallToolRequest = {
  type t = {
    jsonrpc: string,
    id: FrontmanProtocol__JsonRpc.Id.t,
    method: string,
    params: CallToolRequestParams.t,
  }

  let schema = S.object(s => {
    jsonrpc: s.field("jsonrpc", S.literal("2.0")),
    id: s.field("id", FrontmanProtocol__JsonRpc.Id.schema),
    method: s.field("method", S.literal("tools/call")),
    params: s.field("params", CallToolRequestParams.schema),
  })
}

module CallToolResult: {
  type t
  let schema: S.t<t>
  let jsonSchema: S.t<t>
  let makeText: string => t
  let makeStructured: JSON.t => t
  let makeImage: (~data: string, ~mimeType: string) => t
  let makeError: string => t
} = {
  type t = {
    content: @s.matches(FrontmanProtocol__ContentBlock.arraySchema)
    array<FrontmanProtocol__ContentBlock.t>,
    structuredContent?: JSON.t,
    isError?: bool,
    _meta?: ResultMeta.t,
    resultType: string,
  }

  let schema = S.object(s => {
    content: s.field("content", S.array(FrontmanProtocol__ContentBlock.schema)),
    structuredContent: ?s.field("structuredContent", S.option(S.json)),
    isError: ?s.field("isError", S.option(S.bool)),
    _meta: ?s.field("_meta", S.option(ResultMeta.schema)),
    resultType: s.field("resultType", S.literal("complete")),
  })

  let jsonSchema = schema

  let makeText = text => {
    content: [TextContent({text, _meta: None, annotations: None})],
    resultType: "complete",
  }

  let makeStructured = json => {
    content: [TextContent({text: JSON.stringify(json), _meta: None, annotations: None})],
    structuredContent: json,
    resultType: "complete",
  }

  let makeImage = (~data, ~mimeType) => {
    content: [ImageContent({data, mimeType, _meta: None, annotations: None})],
    resultType: "complete",
  }

  let makeError = text => {
    content: [TextContent({text, _meta: None, annotations: None})],
    isError: true,
    resultType: "complete",
  }
}

module ErrorCode = {
  let invalidParams = ModernErrorCode.invalidParams
  let internalError = ModernErrorCode.internalError
  let methodNotFound = ModernErrorCode.methodNotFound
  let missingRequiredClientCapability = ModernErrorCode.missingRequiredClientCapability
  let unsupportedProtocolVersion = ModernErrorCode.unsupportedProtocolVersion
}

type serverInterface<'server> = {
  server: 'server,
  buildDiscoverResult: 'server => DiscoverResult.t,
  buildToolsListResult: 'server => ListToolsResult.t,
  executeTool: (
    'server,
    ~name: string,
    ~arguments: option<Dict.t<JSON.t>>,
    ~taskId: string,
    ~toolCallId: string,
    ~onProgress: option<string => unit>,
  ) => promise<CallToolResult.t>,
}

module type Server = {
  type t
  let buildDiscoverResult: t => DiscoverResult.t
  let buildToolsListResult: t => ListToolsResult.t
  let executeTool: (
    t,
    ~name: string,
    ~arguments: option<Dict.t<JSON.t>>=?,
    ~taskId: string,
    ~toolCallId: string,
    ~onProgress: option<string => unit>=?,
  ) => promise<CallToolResult.t>
}
