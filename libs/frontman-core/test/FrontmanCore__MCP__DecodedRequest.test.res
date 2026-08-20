open Vitest

module Protocol = FrontmanAiFrontmanProtocol
module JsonRpc = Protocol.FrontmanProtocol__JsonRpc
module MCP = Protocol.FrontmanProtocol__MCP
module DecodedRequest = FrontmanCore__MCP__DecodedRequest
module MethodRequest = FrontmanCore__MCP__MethodRequest
module ToolRegistry = FrontmanCore__ToolRegistry
module Tool = Protocol.FrontmanProtocol__Tool
module RawHeaders = FrontmanCore__MCP__RawHeaders

@schema
type callResultResponse = {
  jsonrpc: string,
  id: JsonRpc.Id.t,
  result: JSON.t,
}

@schema
type completeErrorResult = {
  resultType: string,
  isError: bool,
}

@schema
type textContent = {
  @live @as("type") type_: string,
  text: string,
}

@schema
type completeResult = {
  content: array<textContent>,
  resultType: string,
  isError?: bool,
}

let executionCount = ref(0)

type annotatedProperty = {
  @live @as("type") type_: string,
  @live @as("x-mcp-header") header: string,
}

external annotatedPropertyAsSchema: annotatedProperty => JSONSchema.t = "%identity"

module AnnotatedTool = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "annotated_tool",
    "Tests selected custom headers",
    Tool.Read,
    true,
    None,
  )

  @schema
  type payload = {
    region: string,
    requiredAfterCustomHeaders: int,
  }

  type input = payload

  let inputSchema = payloadSchema->S.extendJSONSchema({
    properties: Dict.fromArray([
      ("region", JSONSchema.Schema(annotatedPropertyAsSchema({type_: "string", header: "Region"}))),
    ]),
  })

  let execute = async (_context, _input) => {
    executionCount.contents = executionCount.contents + 1
    failwith("Request validation executed a tool")
  }
}

module InvalidAnnotatedTool = {
  include AnnotatedTool

  let name = "invalid_annotated_tool"
  let inputSchema = payloadSchema->S.extendJSONSchema({
    properties: Dict.fromArray([
      (
        "region",
        JSONSchema.Schema(annotatedPropertyAsSchema({type_: "string", header: "Bad Name"})),
      ),
    ]),
  })
}

module OptionalInputTool = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "optional_input_tool",
    "Tests omitted arguments",
    Tool.Read,
    true,
    None,
  )

  @schema
  type input = {@live value?: string}

  let execute = async (_context, _input) => {
    executionCount.contents = executionCount.contents + 1
    failwith("Request validation executed a tool")
  }
}

module SuccessfulTool = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "successful_tool",
    "Tests successful execution",
    Tool.Read,
    true,
    None,
  )

  @schema
  type input = {value: string}

  let execute = async (_context, input) => {
    executionCount.contents = executionCount.contents + 1
    MCP.CallToolResult.makeText(input.value)
  }
}

module BusinessFailureTool = {
  include SuccessfulTool

  let name = "business_failure_tool"
  let execute = async (_context, _input) => {
    executionCount.contents = executionCount.contents + 1
    MCP.CallToolResult.makeError("Business rule rejected the request")
  }
}

module ApiFailureTool = {
  include SuccessfulTool

  let name = "api_failure_tool"
  let execute = async (_context, _input) => {
    executionCount.contents = executionCount.contents + 1
    MCP.CallToolResult.makeError("API request failed")
  }
}

module ExceptionTool = {
  include SuccessfulTool

  let name = "exception_tool"
  let execute = async (_context, _input) => {
    executionCount.contents = executionCount.contents + 1
    failwith("Upstream API unavailable")
  }
}

module SignalTool = {
  include SuccessfulTool

  let name = "signal_tool"
  let receivedSignal = ref(None)
  let execute = async (context: Tool.serverExecutionContext, input) => {
    receivedSignal := Some(context.signal)
    MCP.CallToolResult.makeText(input.value)
  }
}

module StructuredTool = {
  let name = "structured_tool"
  let description = "Tests output schema validation"
  let access = Tool.Read
  let visibleToAgent = true

  @schema
  type input = {mode: string}

  @schema
  type output = {@live value: string}

  let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

  let execute = async (_context, input) => {
    executionCount.contents = executionCount.contents + 1
    switch input.mode {
    | "valid" => MCP.CallToolResult.makeStructured(JSON.parseOrThrow(`{"value":"ok"}`))
    | "metadata" =>
      JSON.parseOrThrow(`{"resultType":"complete","content":[{"type":"text","text":"{\\"value\\":\\"ok\\"}"}],"structuredContent":{"value":"ok"},"_meta":{"com.example/value":"preserved","io.modelcontextprotocol/serverInfo":{"name":"spoofed","version":"0"}}}`)->S.parseOrThrow(
        ~to=MCP.CallToolResult.schema,
      )
    | "missing" => MCP.CallToolResult.makeText("missing")
    | "error" => MCP.CallToolResult.makeError("business output error")
    | "valid-error" =>
      JSON.parseOrThrow(`{"resultType":"complete","content":[{"type":"text","text":"business structured error"}],"structuredContent":{"value":"business output error"},"isError":true}`)->S.parseOrThrow(
        ~to=MCP.CallToolResult.schema,
      )
    | "invalid-error" =>
      JSON.parseOrThrow(`{"resultType":"complete","content":[{"type":"text","text":"invalid structured error"}],"structuredContent":{"value":1},"isError":true}`)->S.parseOrThrow(
        ~to=MCP.CallToolResult.schema,
      )
    | _ => MCP.CallToolResult.makeStructured(JSON.parseOrThrow(`{"value":1}`))
    }
  }
}

module Helpers = {
  let json = source => source->S.decodeOrThrow(~from=S.jsonString, ~to=S.json)
  let headers = (~version=MCP.protocolVersion, ~method, ~name=None) => {
    let entries = [
      ("MCP-Protocol-Version", version),
      ("Mcp-Method", method),
      ...name->Option.mapOr([], name => [("Mcp-Name", name)]),
    ]
    WebAPI.Headers.fromKeyValueArray(entries)
  }
  let rawHeaders = entries => RawHeaders.make(entries)
  let request = (
    ~version=MCP.protocolVersion,
    ~method="tools/call",
    ~id=`"request-1"`,
    ~clientCapabilities="{}",
    ~additionalMetadata="",
    ~name="read_file",
    ~arguments="",
  ) =>
    json(
      `{"jsonrpc":"2.0","id":${id},"method":"${method}","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${version}","io.modelcontextprotocol/clientCapabilities":${clientCapabilities}${additionalMetadata}},"name":"${name}"${arguments}}}`,
    )
  let responseFields = async response => {
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
  }
  let callResultResponse = async response => {
    let body = await response->WebAPI.Response.json
    let fields = body->S.parseOrThrow(~to=callResultResponseSchema)
    fields.result->S.parseOrThrow(~to=MCP.CallToolResult.schema)->ignore
    let result = fields.result->S.parseOrThrow(~to=completeErrorResultSchema)
    (fields, result)
  }
  let completeResultResponse = async response => {
    let body = await response->WebAPI.Response.json
    let fields = body->S.parseOrThrow(~to=callResultResponseSchema)
    fields.result->S.parseOrThrow(~to=MCP.CallToolResult.schema)->ignore
    let result = fields.result->S.parseOrThrow(~to=completeResultSchema)
    (fields, result)
  }
  let discoverResultResponse = async response => {
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=MCP.DiscoverResultResponse.schema)
  }
  let listToolsResultResponse = async response => {
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=MCP.ListToolsResultResponse.schema)
  }
}

let executionContext: FrontmanCore__Server.executionContext = {
  projectRoot: "/test/project",
  sourceRoot: "/test/project",
  signal: WebAPI.AbortController.make().signal,
  onProgress: None,
}

describe("MCP decoded HTTP request boundary", _t => {
  testAsync("adds server identity without changing audio content discriminators", async t => {
    let result =
      Helpers.json(`{"resultType":"complete","content":[{"type":"audio","data":"UklGRgQAAABXQVZF","mimeType":"audio/wav"}]}`)->S.parseOrThrow(
        ~to=MCP.CallToolResult.schema,
      )
    let response = DecodedRequest.completeToolResult(
      ~id=JSON.Encode.string("audio-request")->S.parseOrThrow(~to=JsonRpc.Id.schema),
      ~result,
      ~serverIdentity=Some({serverName: "audio-server", serverVersion: "1.0.0"}),
    )
    let body = await response->WebAPI.Response.json

    t
    ->expect(body->JSON.stringify->String.includes(`"type":"audio"`))
    ->Expect.toBe(true)
    t
    ->expect(body->JSON.stringify->String.includes(`"type":"image"`))
    ->Expect.toBe(false)
  })

  testAsync("passes the execution signal to the selected tool unchanged", async t => {
    let controller = WebAPI.AbortController.make()
    let ctx: FrontmanCore__Server.executionContext = {
      ...executionContext,
      signal: controller.signal,
    }
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(SignalTool)])
    let validated = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/call", ~name=Some(SignalTool.name)),
      ~json=Helpers.request(~name=SignalTool.name, ~arguments=`,"arguments":{"value":"ok"}`),
      ~registry,
    )

    switch validated {
    | DecodedRequest.Accepted(request) =>
      let _ = await DecodedRequest.execute(
        ~ctx,
        ~serverName="frontman-test",
        ~serverVersion="1.0.0",
        request,
      )
    | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected the signal tool request to be accepted")
    }

    t->expect(SignalTool.receivedSignal.contents == Some(controller.signal))->Expect.toBe(true)
  })

  test("accepts only after envelope and standard-header validation", t => {
    let result = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/call", ~name=Some("read_file")),
      ~json=Helpers.request(~arguments=`,"arguments":{"path":"README.md"}`),
      ~registry=ToolRegistry.coreTools(),
    )

    switch result {
    | DecodedRequest.Accepted({envelope, authorities, metadata, request}) =>
      t->expect(envelope.method)->Expect.toBe("tools/call")
      t->expect(authorities.headers.name)->Expect.toEqual(Some(Helpers.json(`"read_file"`)))
      metadata->S.parseOrThrow(~to=MCP.RequestMeta.schema)->ignore
      switch request {
      | MethodRequest.SelectedCallTool({params}) => t->expect(params.name)->Expect.toBe("read_file")
      | MethodRequest.SelectedDiscover(_) | MethodRequest.SelectedListTools(_) =>
        failwith("Expected call-tool request")
      }
    | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected decoded request acceptance")
    }
  })

  testAsync("rejects an invalid envelope before inspecting required headers", async t => {
    let result = DecodedRequest.validate(
      ~headers=WebAPI.Headers.make(),
      ~json=Helpers.json(`{"jsonrpc":"1.0","id":"recoverable","method":"tools/call"}`),
      ~registry=ToolRegistry.coreTools(),
    )

    switch result {
    | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
      failwith("Expected invalid request rejection")
    | DecodedRequest.Rejected(response) =>
      let fields = await Helpers.responseFields(response)
      t->expect(response.status)->Expect.toBe(400)
      t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidRequest))
      t
      ->expect(fields.id->Option.map(JsonRpc.Id.toJson))
      ->Expect.toEqual(Some(Helpers.json(`"recoverable"`)))
    }
  })

  testAsync("omits an unreadable ID from InvalidRequest", async t => {
    let result = DecodedRequest.validate(
      ~headers=WebAPI.Headers.make(),
      ~json=Helpers.json(`{"jsonrpc":"2.0","id":null,"method":"tools/call"}`),
      ~registry=ToolRegistry.coreTools(),
    )

    switch result {
    | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
      failwith("Expected invalid request rejection")
    | DecodedRequest.Rejected(response) =>
      let fields = await Helpers.responseFields(response)
      t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidRequest))
      t->expect(fields.id)->Expect.toBeNone
    }
  })

  testAsync("preserves header presence, comparison, and version precedence", async t => {
    let unsupportedRequest = Helpers.request(~version="1900-01-01")
    let assertRejected = async (~headers, ~expectedCode, ~expectedMessage) => {
      switch DecodedRequest.validate(
        ~headers,
        ~json=unsupportedRequest,
        ~registry=ToolRegistry.coreTools(),
      ) {
      | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
        failwith("Expected decoded request rejection")
      | DecodedRequest.Rejected(response) =>
        let fields = await Helpers.responseFields(response)
        t->expect(fields.error.code)->Expect.toBe(Int.toFloat(expectedCode))
        t->expect(fields.error.message)->Expect.toBe(expectedMessage)
      }
    }

    await assertRejected(
      ~headers=WebAPI.Headers.fromKeyValueArray([
        ("MCP-Protocol-Version", "1900-01-01"),
        ("Mcp-Name", "read_file"),
      ]),
      ~expectedCode=MCP.ModernErrorCode.headerMismatch,
      ~expectedMessage="Header mismatch: Mcp-Method",
    )
    await assertRejected(
      ~headers=Helpers.headers(
        ~version="1900-01-01",
        ~method="Tools/Call",
        ~name=Some("read_file"),
      ),
      ~expectedCode=MCP.ModernErrorCode.headerMismatch,
      ~expectedMessage="Header mismatch: Mcp-Method",
    )
    await assertRejected(
      ~headers=Helpers.headers(
        ~version="1900-01-01",
        ~method="tools/call",
        ~name=Some("read_file"),
      ),
      ~expectedCode=MCP.ModernErrorCode.unsupportedProtocolVersion,
      ~expectedMessage="Unsupported protocol version",
    )
  })

  testAsync("classifies a type-confused body mirror as HeaderMismatch", async t => {
    let json = Helpers.json(`{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":1,"io.modelcontextprotocol/clientCapabilities":{}},"name":"read_file"}}`)
    let result = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/call", ~name=Some("read_file")),
      ~json,
      ~registry=ToolRegistry.coreTools(),
    )

    switch result {
    | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
      failwith("Expected header mismatch rejection")
    | DecodedRequest.Rejected(response) =>
      let fields = await Helpers.responseFields(response)
      t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.headerMismatch))
      t->expect(fields.error.message)->Expect.toBe("Header mismatch: MCP-Protocol-Version")
      t->expect(fields.id->Option.flatMap(JsonRpc.Id.toInt))->Expect.toEqual(Some(7))
    }
  })

  testAsync(
    "rejects missing or malformed complete request metadata with HTTP InvalidParams",
    async t => {
      let assertInvalidMetadata = async json => {
        switch DecodedRequest.validate(
          ~headers=Helpers.headers(~method="tools/call", ~name=Some("read_file")),
          ~json,
          ~registry=ToolRegistry.coreTools(),
        ) {
        | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
          failwith("Expected request metadata rejection")
        | DecodedRequest.Rejected(response) =>
          let fields = await Helpers.responseFields(response)
          t->expect(response.status)->Expect.toBe(400)
          t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidParams))
          t->expect(fields.error.message)->Expect.toBe("Invalid request metadata")
          fields.error
          ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
          ->S.parseOrThrow(~to=MCP.InvalidParamsError.schema)
          ->ignore
        }
      }

      await assertInvalidMetadata(
        Helpers.json(
          `{"jsonrpc":"2.0","id":"missing-capabilities","method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}"},"name":"read_file"}}`,
        ),
      )
      await assertInvalidMetadata(Helpers.request(~clientCapabilities=`{"roots":true}`))
      await assertInvalidMetadata(
        Helpers.request(~additionalMetadata=`,"io.modelcontextprotocol/logLevel":"verbose"`),
      )
    },
  )

  testAsync("preserves standard-header and version errors before malformed metadata", async t => {
    let malformedMetadata = Helpers.request(
      ~version="1900-01-01",
      ~clientCapabilities=`{"roots":true}`,
    )
    let assertCode = async (~headers, ~expectedCode) => {
      switch DecodedRequest.validate(
        ~headers,
        ~json=malformedMetadata,
        ~registry=ToolRegistry.coreTools(),
      ) {
      | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
        failwith("Expected ordered rejection")
      | DecodedRequest.Rejected(response) =>
        let fields = await Helpers.responseFields(response)
        t->expect(fields.error.code)->Expect.toBe(Int.toFloat(expectedCode))
      }
    }

    await assertCode(
      ~headers=Helpers.headers(
        ~version="1900-01-01",
        ~method="Tools/Call",
        ~name=Some("read_file"),
      ),
      ~expectedCode=MCP.ModernErrorCode.headerMismatch,
    )
    await assertCode(
      ~headers=Helpers.headers(
        ~version="1900-01-01",
        ~method="tools/call",
        ~name=Some("read_file"),
      ),
      ~expectedCode=MCP.ModernErrorCode.unsupportedProtocolVersion,
    )
  })

  testAsync("rejects an explicitly required absent or incompatible client capability", async t => {
    let requiredClientCapabilities: DecodedRequest.requiredClientCapabilities = {
      value: MCP.ExecutionContextExtension.clientCapabilities(),
      schema: MCP.ExecutionContextExtension.clientCapabilitiesSchema,
    }
    let assertMissing = async (~id, ~clientCapabilities) => {
      let result = DecodedRequest.validate(
        ~headers=WebAPI.Headers.fromKeyValueArray([
          ("MCP-Protocol-Version", MCP.protocolVersion),
          ("Mcp-Method", "tools/call"),
          ("Mcp-Name", "read_file"),
          ("Mcp-Param-Unrecognized", "ignored-after-capability"),
        ]),
        ~json=Helpers.request(~id, ~clientCapabilities),
        ~registry=ToolRegistry.coreTools(),
        ~requiredClientCapabilities=Some(requiredClientCapabilities),
      )

      switch result {
      | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
        failwith("Expected missing capability rejection")
      | DecodedRequest.Rejected(response) =>
        let fields = await Helpers.responseFields(response)
        let data =
          fields.error.data
          ->Option.getOrThrow
          ->S.parseOrThrow(~to=MCP.MissingRequiredClientCapabilityError.dataSchema)
        t->expect(response.status)->Expect.toBe(400)
        t
        ->expect(fields.error.code)
        ->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.missingRequiredClientCapability))
        t->expect(fields.error.message)->Expect.toBe("Missing required client capability")
        t
        ->expect(fields.id->Option.map(JsonRpc.Id.toJson))
        ->Expect.toEqual(Some(Helpers.json(id)))
        t
        ->expect(data.requiredCapabilities->MCP.ClientCapabilities.toJson)
        ->Expect.toEqual(
          MCP.ExecutionContextExtension.clientCapabilities()->MCP.ClientCapabilities.toJson,
        )
      }
    }

    await assertMissing(~id="9007199254740991", ~clientCapabilities="{}")
    await assertMissing(
      ~id=`"incompatible"`,
      ~clientCapabilities=`{"extensions":{"ai.frontman/execution-context":{"version":2}}}`,
    )
  })

  test("accepts when an explicitly required client capability is declared", t => {
    let requiredClientCapabilities: DecodedRequest.requiredClientCapabilities = {
      value: MCP.ExecutionContextExtension.clientCapabilities(),
      schema: MCP.ExecutionContextExtension.clientCapabilitiesSchema,
    }
    let capabilities = MCP.ExecutionContextExtension.clientCapabilities()
    let capabilitiesJson = capabilities->MCP.ClientCapabilities.toJson->JSON.stringify
    let result = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/call", ~name=Some("read_file")),
      ~json=Helpers.request(
        ~clientCapabilities=capabilitiesJson,
        ~arguments=`,"arguments":{"path":"README.md"}`,
      ),
      ~registry=ToolRegistry.coreTools(),
      ~requiredClientCapabilities=Some(requiredClientCapabilities),
    )

    switch result {
    | DecodedRequest.Accepted({metadata}) =>
      let fields = metadata->S.parseOrThrow(~to=MCP.RequestMeta.knownFieldsSchema)
      t
      ->expect(fields.clientCapabilities->MCP.ClientCapabilities.toJson)
      ->Expect.toEqual(capabilities->MCP.ClientCapabilities.toJson)
    | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected required capability acceptance")
    }
  })

  testAsync("returns method-specific HTTP errors only after metadata validation", async t => {
    let assertError = async (~json, ~headers, ~status, ~code, ~message) => {
      switch DecodedRequest.validate(~headers, ~json, ~registry=ToolRegistry.coreTools()) {
      | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
        failwith("Expected method request rejection")
      | DecodedRequest.Rejected(response) =>
        let fields = await Helpers.responseFields(response)
        t->expect(response.status)->Expect.toBe(status)
        t->expect(fields.error.code)->Expect.toBe(Int.toFloat(code))
        t->expect(fields.error.message)->Expect.toBe(message)
      }
    }

    await assertError(
      ~json=Helpers.request(~clientCapabilities=`{"roots":true}`),
      ~headers=Helpers.headers(~method="tools/call", ~name=Some("read_file")),
      ~status=400,
      ~code=MCP.ModernErrorCode.invalidParams,
      ~message="Invalid request metadata",
    )
    await assertError(
      ~json=Helpers.request(~id=`"bad-params"`, ~arguments=`,"arguments":[]`),
      ~headers=Helpers.headers(~method="tools/call", ~name=Some("read_file")),
      ~status=200,
      ~code=MCP.ModernErrorCode.invalidParams,
      ~message="Invalid method parameters",
    )
    await assertError(
      ~json=Helpers.request(~method="resources/list", ~id=`"unknown-method"`),
      ~headers=Helpers.headers(~method="resources/list"),
      ~status=404,
      ~code=MCP.ModernErrorCode.methodNotFound,
      ~message="Method not found",
    )
  })

  testAsync("rejects every unsolicited tools-list cursor without side effects", async t => {
    executionCount.contents = 0
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(SuccessfulTool)])
    let assertInvalidCursor = async (~id, ~cursor) => {
      let result = DecodedRequest.validate(
        ~headers=Helpers.headers(~method="tools/list"),
        ~json=Helpers.request(~method="tools/list", ~id, ~arguments=`,"cursor":${cursor}`),
        ~registry,
      )

      switch result {
      | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
        failwith("Expected unsolicited cursor rejection")
      | DecodedRequest.Rejected(response) =>
        let fields = await Helpers.responseFields(response)
        fields.error
        ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
        ->S.parseOrThrow(~to=MCP.InvalidParamsError.schema)
        ->ignore
        t->expect(response.status)->Expect.toBe(200)
        t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidParams))
        t->expect(fields.error.message)->Expect.toBe("Invalid method parameters")
        t
        ->expect(fields.id->Option.map(JsonRpc.Id.toJson))
        ->Expect.toEqual(Some(Helpers.json(id)))
        t->expect(executionCount.contents)->Expect.toBe(0)
      }
    }

    await assertInvalidCursor(~id=`"empty-cursor"`, ~cursor=`""`)
    await assertInvalidCursor(~id="9007199254740991", ~cursor=`"opaque/continuation=="`)
  })

  testAsync("returns exact unknown-tool errors with string and numeric IDs", async t => {
    let registry = ToolRegistry.make()
    let assertUnknown = async id => {
      let result = DecodedRequest.validate(
        ~headers=WebAPI.Headers.fromKeyValueArray([
          ("MCP-Protocol-Version", MCP.protocolVersion),
          ("Mcp-Method", "tools/call"),
          ("Mcp-Name", "read_file"),
          ("Mcp-Param-Unrecognized", "ignored-before-selection"),
        ]),
        ~json=Helpers.request(~id),
        ~registry,
      )

      switch result {
      | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
        failwith("Expected unknown-tool rejection")
      | DecodedRequest.Rejected(response) =>
        let fields = await Helpers.responseFields(response)
        t->expect(response.status)->Expect.toBe(200)
        t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidParams))
        t->expect(fields.error.message)->Expect.toBe("Unknown tool: read_file")
        t
        ->expect(fields.id->Option.map(JsonRpc.Id.toJson))
        ->Expect.toEqual(Some(Helpers.json(id)))
      }
    }

    await assertUnknown(`"unknown-tool"`)
    await assertUnknown("9007199254740991")
  })

  test("validates selected custom headers before complete tool arguments", _t => {
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(AnnotatedTool)])
    let result = DecodedRequest.validate(
      ~headers=WebAPI.Headers.fromKeyValueArray([
        ("MCP-Protocol-Version", MCP.protocolVersion),
        ("Mcp-Method", "tools/call"),
        ("Mcp-Name", "annotated_tool"),
        ("mcp-param-region", "=?base64?dXMtZWFzdDE=?="),
      ]),
      ~rawHeaders=Some(
        Helpers.rawHeaders([
          ("MCP-Protocol-Version", MCP.protocolVersion),
          ("Mcp-Method", "tools/call"),
          ("Mcp-Name", "annotated_tool"),
          ("mcp-param-region", "=?base64?dXMtZWFzdDE=?="),
        ]),
      ),
      ~json=Helpers.request(
        ~name="annotated_tool",
        ~arguments=`,"arguments":{"region":"us-east1"}`,
      ),
      ~registry,
    )

    switch result {
    | DecodedRequest.Completed(_) => ()
    | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected selected-tool input error result")
    }
  })

  testAsync(
    "maps selected-tool input rejection to a complete error result without execution",
    async t => {
      executionCount.contents = 0
      let registry = ToolRegistry.make()->ToolRegistry.addTools([module(AnnotatedTool)])
      let assertInputError = async id => {
        let result = DecodedRequest.validate(
          ~headers=WebAPI.Headers.fromKeyValueArray([
            ("MCP-Protocol-Version", MCP.protocolVersion),
            ("Mcp-Method", "tools/call"),
            ("Mcp-Name", "annotated_tool"),
            ("Mcp-Param-Region", "us-east1"),
          ]),
          ~rawHeaders=Some(
            Helpers.rawHeaders([
              ("MCP-Protocol-Version", MCP.protocolVersion),
              ("Mcp-Method", "tools/call"),
              ("Mcp-Name", "annotated_tool"),
              ("Mcp-Param-Region", "us-east1"),
            ]),
          ),
          ~json=Helpers.request(
            ~id,
            ~name="annotated_tool",
            ~arguments=`,"arguments":{"region":"us-east1","requiredAfterCustomHeaders":"wrong"}`,
          ),
          ~registry,
        )

        switch result {
        | DecodedRequest.Completed(response) =>
          let (fields, callResult) = await Helpers.callResultResponse(response)
          t->expect(response.status)->Expect.toBe(200)
          t->expect(fields.jsonrpc)->Expect.toBe("2.0")
          t
          ->expect(fields.id->JsonRpc.Id.toJson)
          ->Expect.toEqual(Helpers.json(id))
          t->expect(callResult.resultType)->Expect.toBe("complete")
          t->expect(callResult.isError)->Expect.toBe(true)
          t->expect(executionCount.contents)->Expect.toBe(0)
        | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
          failwith("Expected selected-tool input error result")
        }
      }

      await assertInputError(`"invalid-input"`)
      await assertInputError("9007199254740991")
    },
  )

  testAsync("preserves custom-header rejection before complete argument validation", async t => {
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(AnnotatedTool)])
    let result = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/call", ~name=Some("annotated_tool")),
      ~rawHeaders=Some(Helpers.rawHeaders([])),
      ~json=Helpers.request(
        ~name="annotated_tool",
        ~arguments=`,"arguments":{"region":"us-east1","requiredAfterCustomHeaders":"wrong"}`,
      ),
      ~registry,
    )

    switch result {
    | DecodedRequest.Rejected(response) =>
      let fields = await Helpers.responseFields(response)
      t->expect(response.status)->Expect.toBe(400)
      t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.headerMismatch))
    | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
      failwith("Expected custom-header rejection")
    }
  })

  test("retains a valid selected call without executing it", t => {
    executionCount.contents = 0
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(AnnotatedTool)])
    let result = DecodedRequest.validate(
      ~headers=WebAPI.Headers.fromKeyValueArray([
        ("MCP-Protocol-Version", MCP.protocolVersion),
        ("Mcp-Method", "tools/call"),
        ("Mcp-Name", "annotated_tool"),
        ("Mcp-Param-Region", "us-east1"),
      ]),
      ~rawHeaders=Some(
        Helpers.rawHeaders([
          ("MCP-Protocol-Version", MCP.protocolVersion),
          ("Mcp-Method", "tools/call"),
          ("Mcp-Name", "annotated_tool"),
          ("Mcp-Param-Region", "us-east1"),
        ]),
      ),
      ~json=Helpers.request(
        ~name="annotated_tool",
        ~arguments=`,"arguments":{"region":"us-east1","requiredAfterCustomHeaders":7}`,
      ),
      ~registry,
    )

    switch result {
    | DecodedRequest.Accepted({request: MethodRequest.SelectedCallTool({params, tool})}) =>
      module SelectedTool = unpack(tool)
      t->expect(SelectedTool.name)->Expect.toBe("annotated_tool")
      t->expect(params.arguments->Option.isSome)->Expect.toBe(true)
      t->expect(executionCount.contents)->Expect.toBe(0)
    | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected validated selected call")
    }
  })

  testAsync("rejects duplicate recognized physical custom headers before execution", async t => {
    executionCount.contents = 0
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(AnnotatedTool)])
    let headers = WebAPI.Headers.fromKeyValueArray([
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Method", "tools/call"),
      ("Mcp-Name", "annotated_tool"),
      ("Mcp-Param-Region", "us-east1"),
      ("mcp-param-region", "us-east1"),
    ])
    let rawHeaders = RawHeaders.make([
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Method", "tools/call"),
      ("Mcp-Name", "annotated_tool"),
      ("Mcp-Param-Region", "us-east1"),
      ("mcp-param-region", "us-east1"),
    ])
    let result = DecodedRequest.validate(
      ~headers,
      ~rawHeaders=Some(rawHeaders),
      ~json=Helpers.request(
        ~name="annotated_tool",
        ~arguments=`,"arguments":{"region":"us-east1","requiredAfterCustomHeaders":7}`,
      ),
      ~registry,
    )

    switch result {
    | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
      failwith("Expected duplicate custom-header rejection")
    | DecodedRequest.Rejected(response) =>
      let fields = await Helpers.responseFields(response)
      t->expect(response.status)->Expect.toBe(400)
      t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.headerMismatch))
      t->expect(fields.error.message)->Expect.toBe("Header mismatch: Mcp-Param-Region")
      t->expect(executionCount.contents)->Expect.toBe(0)
    }
  })

  test("crashes before custom validation when physical headers are unavailable", t => {
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(AnnotatedTool)])
    let crashed = try {
      DecodedRequest.validate(
        ~headers=WebAPI.Headers.fromKeyValueArray([
          ("MCP-Protocol-Version", MCP.protocolVersion),
          ("Mcp-Method", "tools/call"),
          ("Mcp-Name", "annotated_tool"),
          ("Mcp-Param-Region", "us-east1"),
        ]),
        ~json=Helpers.request(
          ~name="annotated_tool",
          ~arguments=`,"arguments":{"region":"us-east1","requiredAfterCustomHeaders":7}`,
        ),
        ~registry,
      )->ignore
      false
    } catch {
    | Failure(message) =>
      t
      ->expect(message)
      ->Expect.toBe("Raw physical headers are required for x-mcp-header validation")
      true
    | exn => throw(exn)
    }
    t->expect(crashed)->Expect.toBe(true)
  })

  testAsync("executes a validated selected call exactly once", async t => {
    executionCount.contents = 0
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(SuccessfulTool)])
    let validated = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/call", ~name=Some("successful_tool")),
      ~json=Helpers.request(
        ~id=`"successful-execution"`,
        ~name="successful_tool",
        ~arguments=`,"arguments":{"value":"completed"}`,
      ),
      ~registry,
    )

    switch validated {
    | DecodedRequest.Accepted(accepted) =>
      switch await DecodedRequest.execute(
        ~ctx=executionContext,
        ~serverName="test-server",
        ~serverVersion="1.0.0",
        accepted,
      ) {
      | DecodedRequest.Completed(response) =>
        let (fields, result) = await Helpers.completeResultResponse(response)
        t->expect(response.status)->Expect.toBe(200)
        t
        ->expect(fields.id->JsonRpc.Id.toJson)
        ->Expect.toEqual(Helpers.json(`"successful-execution"`))
        t->expect(result.resultType)->Expect.toBe("complete")
        t->expect(result.isError)->Expect.toBeNone
        let content = result.content->Array.get(0)->Option.getOrThrow
        t->expect(content.text)->Expect.toBe("completed")
        t->expect(executionCount.contents)->Expect.toBe(1)
      | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
        failwith("Expected completed tool execution")
      }
    | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected validated selected call")
    }
  })

  testAsync("returns business, API, and execution failures as complete error results", async t => {
    let registry =
      ToolRegistry.make()->ToolRegistry.addTools([
        module(BusinessFailureTool),
        module(ApiFailureTool),
        module(ExceptionTool),
      ])
    let assertFailure = async (~name, ~id, ~message) => {
      executionCount.contents = 0
      let validated = DecodedRequest.validate(
        ~headers=Helpers.headers(~method="tools/call", ~name=Some(name)),
        ~json=Helpers.request(~id, ~name, ~arguments=`,"arguments":{"value":"rejected"}`),
        ~registry,
      )
      switch validated {
      | DecodedRequest.Accepted(accepted) =>
        switch await DecodedRequest.execute(
          ~ctx=executionContext,
          ~serverName="test-server",
          ~serverVersion="1.0.0",
          accepted,
        ) {
        | DecodedRequest.Completed(response) =>
          let (fields, result) = await Helpers.completeResultResponse(response)
          t->expect(response.status)->Expect.toBe(200)
          t->expect(fields.id->JsonRpc.Id.toJson)->Expect.toEqual(Helpers.json(id))
          t->expect(result.resultType)->Expect.toBe("complete")
          t->expect(result.isError)->Expect.toEqual(Some(true))
          let content = result.content->Array.get(0)->Option.getOrThrow
          t->expect(content.text)->Expect.toBe(message)
          t->expect(executionCount.contents)->Expect.toBe(1)
        | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
          failwith("Expected completed tool failure")
        }
      | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
        failwith("Expected validated selected call")
      }
    }

    await assertFailure(
      ~name="business_failure_tool",
      ~id=`"business-failure"`,
      ~message="Business rule rejected the request",
    )
    await assertFailure(
      ~name="api_failure_tool",
      ~id="9007199254740991",
      ~message="API request failed",
    )
    await assertFailure(
      ~name="exception_tool",
      ~id=`"execution-failure"`,
      ~message="Tool execution failed",
    )
  })

  test("validates omitted arguments as an empty object", t => {
    executionCount.contents = 0
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(OptionalInputTool)])
    let result = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/call", ~name=Some("optional_input_tool")),
      ~json=Helpers.request(~name="optional_input_tool"),
      ~registry,
    )

    switch result {
    | DecodedRequest.Accepted({request: MethodRequest.SelectedCallTool({params, tool})}) =>
      module SelectedTool = unpack(tool)
      t->expect(SelectedTool.name)->Expect.toBe("optional_input_tool")
      t->expect(params.arguments)->Expect.toBeNone
      t->expect(executionCount.contents)->Expect.toBe(0)
    | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected omitted-argument selected call")
    }

    switch DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/call", ~name=Some("read_file")),
      ~json=Helpers.request(),
      ~registry=ToolRegistry.coreTools(),
    ) {
    | DecodedRequest.Completed(_) => t->expect(executionCount.contents)->Expect.toBe(0)
    | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected omitted required arguments to produce an error result")
    }
  })

  testAsync(
    "returns exact custom HeaderMismatch responses with string and numeric IDs",
    async t => {
      let registry = ToolRegistry.make()->ToolRegistry.addTools([module(AnnotatedTool)])
      let assertMismatch = async id => {
        let result = DecodedRequest.validate(
          ~headers=Helpers.headers(~method="tools/call", ~name=Some("annotated_tool")),
          ~rawHeaders=Some(Helpers.rawHeaders([])),
          ~json=Helpers.request(
            ~id,
            ~name="annotated_tool",
            ~arguments=`,"arguments":{"region":"us-east1"}`,
          ),
          ~registry,
        )

        switch result {
        | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
          failwith("Expected custom-header mismatch")
        | DecodedRequest.Rejected(response) =>
          let body = await response->WebAPI.Response.json
          body->S.parseOrThrow(~to=MCP.HeaderMismatchError.schema)->ignore
          body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
          let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
          t->expect(response.status)->Expect.toBe(400)
          t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.headerMismatch))
          t->expect(fields.error.message)->Expect.toBe("Header mismatch: Mcp-Param-Region")
          t
          ->expect(fields.id->Option.map(JsonRpc.Id.toJson))
          ->Expect.toEqual(Some(Helpers.json(id)))
        }
      }

      await assertMismatch(`"custom-header"`)
      await assertMismatch("9007199254740991")
    },
  )

  test("rejects an invalid owned annotation when the registry is built", t => {
    let crashed = try {
      ToolRegistry.make()->ToolRegistry.addTools([module(InvalidAnnotatedTool)])->ignore
      false
    } catch {
    | Failure(message) =>
      t->expect(message)->Expect.toBe("Invalid MCP tool JSON Schema")
      true
    | exn => throw(exn)
    }
    t->expect(crashed)->Expect.toBe(true)
  })

  testAsync(
    "preserves conforming structured output and adds server identity to every call result",
    async t => {
      let registry = ToolRegistry.make()->ToolRegistry.addTools([module(StructuredTool)])
      let assertResult = async (
        ~mode,
        ~expectedError,
        ~expectedText,
        ~expectedCustomMetadata=false,
        ~expectedStructuredContent=None,
      ) => {
        executionCount.contents = 0
        let validated = DecodedRequest.validate(
          ~headers=Helpers.headers(~method="tools/call", ~name=Some(StructuredTool.name)),
          ~json=Helpers.request(
            ~name=StructuredTool.name,
            ~arguments=`,"arguments":{"mode":"${mode}"}`,
          ),
          ~registry,
        )
        switch validated {
        | DecodedRequest.Accepted(accepted) =>
          switch await DecodedRequest.execute(
            ~ctx=executionContext,
            ~serverName="schema-server",
            ~serverVersion="3.2.1",
            accepted,
          ) {
          | DecodedRequest.Completed(response) =>
            let body = await response->WebAPI.Response.json
            let responseFields = body->S.parseOrThrow(~to=callResultResponseSchema)
            let result = responseFields.result->S.parseOrThrow(~to=MCP.CallToolResult.schema)
            let resultJson =
              result->S.decodeOrThrow(
                ~from=MCP.CallToolResult.schema,
                ~to=S.json->S.noValidation(true),
              )
            let resultFields = resultJson->JSON.Decode.object->Option.getOrThrow
            let content = resultFields->Dict.get("content")->Option.getOrThrow
            let text =
              content
              ->JSON.Decode.array
              ->Option.getOrThrow
              ->Array.get(0)
              ->Option.getOrThrow
              ->JSON.Decode.object
              ->Option.getOrThrow
              ->Dict.get("text")
              ->Option.getOrThrow
              ->JSON.Decode.string
              ->Option.getOrThrow
            let isError =
              resultFields
              ->Dict.get("isError")
              ->Option.flatMap(JSON.Decode.bool)
              ->Option.mapOr(false, value => value)
            let metadata =
              resultFields
              ->Dict.get("_meta")
              ->Option.getOrThrow
              ->S.parseOrThrow(~to=MCP.ResultMeta.schema)
            let metadataFields = metadata->S.parseOrThrow(~to=MCP.ResultMeta.knownFieldsSchema)
            let serverInfo = metadataFields.serverInfo->Option.getOrThrow

            t->expect(text)->Expect.toBe(expectedText)
            t->expect(isError)->Expect.toBe(expectedError)
            t->expect(serverInfo.name)->Expect.toBe("schema-server")
            t->expect(serverInfo.version)->Expect.toBe("3.2.1")
            switch expectedCustomMetadata {
            | true =>
              t
              ->expect(metadata->Dict.get("com.example/value"))
              ->Expect.toEqual(Some(JSON.Encode.string("preserved")))
            | false => ()
            }
            switch expectedStructuredContent {
            | Some(expected) =>
              t
              ->expect(resultFields->Dict.get("structuredContent"))
              ->Expect.toEqual(Some(expected))
            | None => ()
            }
            t->expect(executionCount.contents)->Expect.toBe(1)
          | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
            failwith("Expected completed structured result")
          }
        | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
          failwith("Expected selected structured call")
        }
      }

      await assertResult(~mode="valid", ~expectedError=false, ~expectedText=`{"value":"ok"}`)
      await assertResult(
        ~mode="metadata",
        ~expectedError=false,
        ~expectedText=`{"value":"ok"}`,
        ~expectedCustomMetadata=true,
      )
      await assertResult(
        ~mode="valid-error",
        ~expectedError=true,
        ~expectedText="business structured error",
        ~expectedStructuredContent=Some(JSON.parseOrThrow(`{"value":"business output error"}`)),
      )
    },
  )

  testAsync(
    "returns JSON-RPC InternalError when selected tool output violates its declared schema",
    async t => {
      let registry = ToolRegistry.make()->ToolRegistry.addTools([module(StructuredTool)])
      let assertOutputError = async mode => {
        executionCount.contents = 0
        let validated = DecodedRequest.validate(
          ~headers=Helpers.headers(~method="tools/call", ~name=Some(StructuredTool.name)),
          ~json=Helpers.request(
            ~name=StructuredTool.name,
            ~arguments=`,"arguments":{"mode":"${mode}"}`,
          ),
          ~registry,
        )
        switch validated {
        | DecodedRequest.Accepted(accepted) =>
          switch await DecodedRequest.execute(
            ~ctx=executionContext,
            ~serverName="schema-server",
            ~serverVersion="3.2.1",
            accepted,
          ) {
          | DecodedRequest.Completed(response) =>
            let body = await response->WebAPI.Response.json
            body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
            let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
            fields.error
            ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
            ->S.parseOrThrow(~to=MCP.InternalError.schema)
            ->ignore

            t->expect(response.status)->Expect.toBe(200)
            t
            ->expect(fields.id->Option.map(JsonRpc.Id.toJson))
            ->Expect.toEqual(Some(Helpers.json(`"request-1"`)))
            t
            ->expect(fields.error.code)
            ->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.internalError))
            t->expect(fields.error.message)->Expect.toBe("Tool output did not match output schema")
            t->expect(fields.error.data)->Expect.toBeNone
            t->expect(executionCount.contents)->Expect.toBe(1)
          | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
            failwith("Expected completed output-schema error")
          }
        | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
          failwith("Expected selected structured call")
        }
      }

      await assertOutputError("missing")
      await assertOutputError("mismatch")
      await assertOutputError("invalid-error")
      await assertOutputError("error")
    },
  )

  test("preserves discovery and listing without consulting registry contents", _t => {
    let registry = ToolRegistry.make()
    let assertAccepted = (~method, ~expected) => {
      let result = DecodedRequest.validate(
        ~headers=Helpers.headers(~method),
        ~json=Helpers.request(~method),
        ~registry,
      )
      switch (result, expected) {
      | (DecodedRequest.Accepted({request: MethodRequest.SelectedDiscover(_)}), #discover)
      | (DecodedRequest.Accepted({request: MethodRequest.SelectedListTools(_)}), #list) => ()
      | (DecodedRequest.Accepted(_), _)
      | (DecodedRequest.Completed(_), _)
      | (DecodedRequest.Rejected(_), _) =>
        failwith("Expected selected pass-through request")
      }
    }

    assertAccepted(~method="server/discover", ~expected=#discover)
    assertAccepted(~method="tools/list", ~expected=#list)
  })

  testAsync("builds complete discovery results with exact identity and capabilities", async t => {
    let assertDiscovery = async id => {
      let validated = DecodedRequest.validate(
        ~headers=Helpers.headers(~method="server/discover"),
        ~json=Helpers.request(~id, ~method="server/discover"),
        ~registry=ToolRegistry.make(),
      )

      switch validated {
      | DecodedRequest.Accepted(accepted) =>
        switch await DecodedRequest.execute(
          ~ctx=executionContext,
          ~serverName="frontman-test",
          ~serverVersion="2.3.4",
          accepted,
        ) {
        | DecodedRequest.Completed(response) =>
          let fields = await Helpers.discoverResultResponse(response)
          let capabilities =
            fields.result.capabilities->S.parseOrThrow(~to=MCP.ServerCapabilities.knownFieldsSchema)
          let metadata =
            fields.result._meta
            ->Option.getOrThrow
            ->S.parseOrThrow(~to=MCP.ResultMeta.knownFieldsSchema)
          let serverInfo = metadata.serverInfo->Option.getOrThrow

          t->expect(response.status)->Expect.toBe(200)
          t->expect(fields.id->JsonRpc.Id.toJson)->Expect.toEqual(Helpers.json(id))
          t->expect(fields.result.resultType)->Expect.toBe("complete")
          t->expect(fields.result.supportedVersions)->Expect.toEqual([MCP.protocolVersion])
          t->expect(capabilities.tools)->Expect.toEqual(Some({listChanged: Some(false)}))
          t->expect(capabilities.completions)->Expect.toBeNone
          t->expect(capabilities.prompts)->Expect.toBeNone
          t->expect(capabilities.resources)->Expect.toBeNone
          t->expect(serverInfo.name)->Expect.toBe("frontman-test")
          t->expect(serverInfo.version)->Expect.toBe("2.3.4")
          t->expect(fields.result.instructions)->Expect.toBeNone
          t->expect(fields.result.ttlMs)->Expect.toBe(0.)
          t->expect(fields.result.cacheScope)->Expect.toEqual(MCP.CacheScope.Private)
        | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
          failwith("Expected completed discovery result")
        }
      | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
        failwith("Expected validated discovery request")
      }
    }

    await assertDiscovery(`"discover-result"`)
    await assertDiscovery("9007199254740991")
  })

  testAsync("builds one deterministic private tools page without executing tools", async t => {
    executionCount.contents = 0
    let registry = ToolRegistry.coreTools()->ToolRegistry.addTools([module(SuccessfulTool)])
    let validated = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/list"),
      ~json=Helpers.request(~method="tools/list", ~id=`"list-result"`),
      ~registry,
    )

    switch validated {
    | DecodedRequest.Accepted(accepted) =>
      switch await DecodedRequest.execute(
        ~ctx=executionContext,
        ~serverName="frontman-test",
        ~serverVersion="2.3.4",
        accepted,
      ) {
      | DecodedRequest.Completed(response) =>
        let fields = await Helpers.listToolsResultResponse(response)
        let names = fields.result.tools->Array.map(tool => tool.name)
        let metadata =
          fields.result._meta
          ->Option.getOrThrow
          ->S.parseOrThrow(~to=MCP.ResultMeta.knownFieldsSchema)
        let readFile =
          fields.result.tools
          ->Array.find(tool => tool.name == "read_file")
          ->Option.getOrThrow
        let readAnnotations =
          readFile.annotations
          ->Option.getOrThrow
          ->S.parseOrThrow(~to=MCP.ToolAnnotations.knownFieldsSchema)
        let writeFile =
          fields.result.tools
          ->Array.find(tool => tool.name == "write_file")
          ->Option.getOrThrow
        let writeAnnotations =
          writeFile.annotations
          ->Option.getOrThrow
          ->S.parseOrThrow(~to=MCP.ToolAnnotations.knownFieldsSchema)

        t->expect(response.status)->Expect.toBe(200)
        t->expect(fields.id->JsonRpc.Id.toJson)->Expect.toEqual(Helpers.json(`"list-result"`))
        t
        ->expect(names)
        ->Expect.toEqual([
          "edit_file",
          "file_exists",
          "grep",
          "lighthouse",
          "list_files",
          "list_tree",
          "read_file",
          "search_files",
          "successful_tool",
          "write_file",
        ])
        t->expect(names->Array.includes("load_agent_instructions"))->Expect.toBe(false)
        t->expect(readFile.outputSchema->Option.isSome)->Expect.toBe(true)
        t->expect(readAnnotations.readOnlyHint)->Expect.toEqual(Some(true))
        t->expect(writeAnnotations.readOnlyHint)->Expect.toEqual(Some(false))
        t->expect(fields.result.nextCursor)->Expect.toBeNone
        t->expect(fields.result.ttlMs)->Expect.toBe(0.)
        t->expect(fields.result.cacheScope)->Expect.toEqual(MCP.CacheScope.Private)
        t
        ->expect(metadata.serverInfo->Option.map(info => (info.name, info.version)))
        ->Expect.toEqual(Some(("frontman-test", "2.3.4")))
        t->expect(executionCount.contents)->Expect.toBe(0)
      | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
        failwith("Expected completed tools list")
      }
    | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected validated tools-list request")
    }
  })

  testAsync("builds a complete empty tools page", async t => {
    let validated = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="tools/list"),
      ~json=Helpers.request(~method="tools/list", ~id="9007199254740991"),
      ~registry=ToolRegistry.make(),
    )

    switch validated {
    | DecodedRequest.Accepted(accepted) =>
      switch await DecodedRequest.execute(
        ~ctx=executionContext,
        ~serverName="frontman-test",
        ~serverVersion="2.3.4",
        accepted,
      ) {
      | DecodedRequest.Completed(response) =>
        let fields = await Helpers.listToolsResultResponse(response)
        t->expect(response.status)->Expect.toBe(200)
        t
        ->expect(fields.id->JsonRpc.Id.toJson)
        ->Expect.toEqual(Helpers.json("9007199254740991"))
        t->expect(fields.result.tools)->Expect.toEqual([])
        t->expect(fields.result.nextCursor)->Expect.toBeNone
      | DecodedRequest.Accepted(_) | DecodedRequest.Rejected(_) =>
        failwith("Expected completed empty tools list")
      }
    | DecodedRequest.Completed(_) | DecodedRequest.Rejected(_) =>
      failwith("Expected validated empty tools-list request")
    }
  })

  testAsync("checks an explicit required capability before method classification", async t => {
    let requiredClientCapabilities: DecodedRequest.requiredClientCapabilities = {
      value: MCP.ExecutionContextExtension.clientCapabilities(),
      schema: MCP.ExecutionContextExtension.clientCapabilitiesSchema,
    }
    let result = DecodedRequest.validate(
      ~headers=Helpers.headers(~method="resources/list"),
      ~json=Helpers.request(~method="resources/list"),
      ~registry=ToolRegistry.coreTools(),
      ~requiredClientCapabilities=Some(requiredClientCapabilities),
    )

    switch result {
    | DecodedRequest.Accepted(_) | DecodedRequest.Completed(_) =>
      failwith("Expected capability rejection")
    | DecodedRequest.Rejected(response) =>
      let fields = await Helpers.responseFields(response)
      t->expect(response.status)->Expect.toBe(400)
      t
      ->expect(fields.error.code)
      ->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.missingRequiredClientCapability))
    }
  })
})
