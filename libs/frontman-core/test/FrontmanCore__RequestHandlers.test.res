open Vitest

module RequestHandlers = FrontmanCore__RequestHandlers
module ToolRegistry = FrontmanCore__ToolRegistry
module Relay = FrontmanAiFrontmanProtocol.FrontmanProtocol__Relay
module Path = FrontmanBindings.Path

module Helpers = {
  let handlerConfig: RequestHandlers.handlerConfig = {
    projectRoot: "/test/project",
    sourceRoot: "/test/project",
    serverName: "test-server",
    serverVersion: "1.0.0",
  }

  let registry = ToolRegistry.coreTools()

  let projectRoot = Path.join([FrontmanBindings.Process.cwd(), "test", "fixtures", "rsc-source"])
  let sourceRoot = Path.join([projectRoot, "src"])
  let sourceFile = Path.join([sourceRoot, "ServerPost.tsx"])

  let makePostRequest = (url: string, body: JSON.t): WebAPI.FetchAPI.request => {
    let headers = WebAPI.HeadersInit.fromDict(
      Dict.fromArray([("Content-Type", "application/json")]),
    )
    WebAPI.Request.fromURL(
      url,
      ~init={
        method: "POST",
        body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
        headers,
      },
    )
  }

  let resolveSourceLocationBody = (request: RequestHandlers.sourceContext): JSON.t =>
    request->S.decodeOrThrow(
      ~from=RequestHandlers.sourceContextSchema,
      ~to=S.json->S.noValidation(true),
    )

  let sourceLocation = (~file: string, ~componentName="App"): RequestHandlers.sourceLocation => {
    componentName: Some(componentName),
    tagName: None,
    file,
    line: 1,
    column: 0,
    componentProps: None,
  }

  let sourceRequest = (context: RequestHandlers.sourceContext): WebAPI.FetchAPI.request =>
    makePostRequest(
      "http://localhost/frontman/resolve-source-location",
      resolveSourceLocationBody(context),
    )

  let successfulResolver = async (context, _options): RequestHandlers.sourceResolutionResult => {
    success: true,
    data: Some(context),
    error: None,
  }
}

describe("RequestHandlers", _t => {
  describe("handleGetTools", _t => {
    testAsync(
      "returns JSON with tools array",
      async t => {
        let response = RequestHandlers.handleGetTools(
          ~registry=Helpers.registry,
          ~config=Helpers.handlerConfig,
        )

        let body = await response->WebAPI.Response.text
        let json = JSON.parseOrThrow(body)
        let obj = json->JSON.Decode.object->Option.getOrThrow

        t->expect(obj->Dict.get("tools")->Option.isSome)->Expect.toBe(true)
      },
    )

    testAsync(
      "returns application/json content type",
      async t => {
        let response = RequestHandlers.handleGetTools(
          ~registry=Helpers.registry,
          ~config=Helpers.handlerConfig,
        )

        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Value("application/json"))
      },
    )

    testAsync(
      "includes server info in response",
      async t => {
        let response = RequestHandlers.handleGetTools(
          ~registry=Helpers.registry,
          ~config=Helpers.handlerConfig,
        )

        let body = await response->WebAPI.Response.text
        let json = JSON.parseOrThrow(body)
        let obj = json->JSON.Decode.object->Option.getOrThrow
        let serverInfo =
          obj->Dict.get("serverInfo")->Option.flatMap(JSON.Decode.object)->Option.getOrThrow

        t
        ->expect(serverInfo->Dict.get("name")->Option.flatMap(JSON.Decode.string))
        ->Expect.toEqual(Some("test-server"))
        t
        ->expect(serverInfo->Dict.get("version")->Option.flatMap(JSON.Decode.string))
        ->Expect.toEqual(Some("1.0.0"))
      },
    )

    testAsync(
      "includes protocol version",
      async t => {
        let response = RequestHandlers.handleGetTools(
          ~registry=Helpers.registry,
          ~config=Helpers.handlerConfig,
        )

        let body = await response->WebAPI.Response.text
        let json = JSON.parseOrThrow(body)
        let obj = json->JSON.Decode.object->Option.getOrThrow

        t
        ->expect(obj->Dict.get("protocolVersion")->Option.flatMap(JSON.Decode.string))
        ->Expect.toEqual(Some(Relay.protocolVersion))
      },
    )

    test(
      "returns 200 status",
      t => {
        let response = RequestHandlers.handleGetTools(
          ~registry=Helpers.registry,
          ~config=Helpers.handlerConfig,
        )

        t->expect(response.status)->Expect.toBe(200)
      },
    )

    testAsync(
      "returns empty tools array for empty registry",
      async t => {
        let emptyRegistry = ToolRegistry.make()
        let response = RequestHandlers.handleGetTools(
          ~registry=emptyRegistry,
          ~config=Helpers.handlerConfig,
        )

        let body = await response->WebAPI.Response.text
        let json = JSON.parseOrThrow(body)
        let obj = json->JSON.Decode.object->Option.getOrThrow
        let tools = obj->Dict.get("tools")->Option.flatMap(JSON.Decode.array)->Option.getOrThrow

        t->expect(tools->Array.length)->Expect.toBe(0)
      },
    )
  })

  describe("handleToolCall", _t => {
    testAsync(
      "returns SSE stream for valid tool call",
      async t => {
        let body = JSON.Encode.object(
          Dict.fromArray([
            ("name", JSON.Encode.string("file_exists")),
            (
              "arguments",
              JSON.Encode.object(
                Dict.fromArray([("path", JSON.Encode.string("/nonexistent/path.txt"))]),
              ),
            ),
          ]),
        )

        let req = Helpers.makePostRequest("http://localhost/frontman/tools/call", body)
        let response = await RequestHandlers.handleToolCall(
          ~registry=Helpers.registry,
          ~config=Helpers.handlerConfig,
          req,
        )

        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Value("text/event-stream"))
      },
    )

    testAsync(
      "returns 400 for malformed request body",
      async t => {
        let body = JSON.Encode.string("not an object")
        let req = Helpers.makePostRequest("http://localhost/frontman/tools/call", body)

        let response = await RequestHandlers.handleToolCall(
          ~registry=Helpers.registry,
          ~config=Helpers.handlerConfig,
          req,
        )

        t->expect(response.status)->Expect.toBe(400)
      },
    )

    testAsync(
      "returns 400 error body for missing name field",
      async t => {
        let body = JSON.Encode.object(
          Dict.fromArray([("wrong_field", JSON.Encode.string("value"))]),
        )
        let req = Helpers.makePostRequest("http://localhost/frontman/tools/call", body)

        let response = await RequestHandlers.handleToolCall(
          ~registry=Helpers.registry,
          ~config=Helpers.handlerConfig,
          req,
        )

        t->expect(response.status)->Expect.toBe(400)
        let text = await response->WebAPI.Response.text
        t->expect(text->String.includes("Invalid request"))->Expect.toBe(true)
      },
    )

    testAsync(
      "SSE stream contains result event for nonexistent tool",
      async t => {
        let body = JSON.Encode.object(
          Dict.fromArray([
            ("name", JSON.Encode.string("nonexistent_tool")),
            ("arguments", JSON.Encode.object(Dict.make())),
          ]),
        )

        let req = Helpers.makePostRequest("http://localhost/frontman/tools/call", body)
        let response = await RequestHandlers.handleToolCall(
          ~registry=Helpers.registry,
          ~config=Helpers.handlerConfig,
          req,
        )

        t->expect(response.status)->Expect.toBe(200)

        let text = await response->WebAPI.Response.text
        t->expect(text->String.includes("event: error"))->Expect.toBe(true)
        t->expect(text->String.includes("Tool not found"))->Expect.toBe(true)
      },
    )
  })

  describe("handleResolveSourceLocation", _t => {
    testAsync(
      "normalizes a complete context through one real package fixture",
      async t => {
        let generatedFile = Path.join([Helpers.projectRoot, ".next", "server", "rsc-chunk.js"])
        let context: RequestHandlers.sourceContext = {
          definition: Some({
            ...Helpers.sourceLocation(~file=Helpers.sourceFile, ~componentName="ClientButton"),
            tagName: Some("BUTTON"),
            componentProps: Some(Dict.fromArray([("label", JSON.Encode.string("Save"))])),
          }),
          invocations: [
            {
              ...Helpers.sourceLocation(
                ~file=`about://React/Server/file://${generatedFile}`,
                ~componentName="ServerPost",
              ),
              tagName: Some("ARTICLE"),
              line: 2,
              column: 2,
            },
          ],
        }

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~projectRoot=Helpers.projectRoot,
          ~sourceRoot=Helpers.sourceRoot,
          Helpers.sourceRequest(context),
        )

        t->expect(response.status)->Expect.toBe(200)
        let result =
          (await response->WebAPI.Response.json)->S.parseOrThrow(
            ~to=RequestHandlers.sourceContextSchema,
          )
        let definition = result.definition->Option.getOrThrow
        let invocation = result.invocations->Array.get(0)->Option.getOrThrow
        t->expect(definition.file)->Expect.toBe("ServerPost.tsx")
        t->expect(definition.componentProps->Option.isSome)->Expect.toBe(true)
        t->expect(invocation.file)->Expect.toBe("ServerPost.tsx")
        t->expect(invocation.line)->Expect.toBe(3)
      },
    )

    testAsync(
      "delegates the complete context once with canonical projectRoot",
      async t => {
        let calls: array<(
          RequestHandlers.sourceContext,
          RequestHandlers.resolveSourceContextOptions,
        )> = []
        let resolver = async (context, options) => {
          calls->Array.push((context, options))->ignore
          await Helpers.successfulResolver(context, options)
        }
        let context: RequestHandlers.sourceContext = {
          definition: Some({
            ...Helpers.sourceLocation(~file=Helpers.sourceFile, ~componentName="Definition"),
            tagName: Some("SECTION"),
            componentProps: Some(Dict.fromArray([("enabled", JSON.Encode.bool(true))])),
          }),
          invocations: [
            {
              ...Helpers.sourceLocation(~file="ServerPost.tsx", ~componentName="Invocation"),
              tagName: Some("ARTICLE"),
              componentProps: Some(Dict.make()),
            },
          ],
        }

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~projectRoot=`${Helpers.sourceRoot}/..`,
          ~sourceRoot=Helpers.sourceRoot,
          ~resolveSourceContext=resolver,
          Helpers.sourceRequest(context),
        )

        t->expect(response.status)->Expect.toBe(200)
        t->expect(calls->Array.length)->Expect.toBe(1)
        let (receivedContext, options) = calls->Array.get(0)->Option.getOrThrow
        t->expect(receivedContext)->Expect.toEqual(context)
        t->expect(options.projectRoot)->Expect.toBe(Helpers.projectRoot)
      },
    )

    testAsync(
      "rejects more than ten invocations without calling the resolver",
      async t => {
        let calls = []
        let resolver = async (context, options) => {
          calls->Array.push(context)->ignore
          await Helpers.successfulResolver(context, options)
        }
        let invocation = Helpers.sourceLocation(~file="ServerPost.tsx")
        let context: RequestHandlers.sourceContext = {
          definition: None,
          invocations: Array.make(~length=11, invocation),
        }

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~sourceRoot=Helpers.sourceRoot,
          ~resolveSourceContext=resolver,
          Helpers.sourceRequest(context),
        )

        t->expect(response.status)->Expect.toBe(422)
        t->expect(calls->Array.length)->Expect.toBe(0)
        let text = await response->WebAPI.Response.text
        t->expect(text->String.includes("at most 10 invocations"))->Expect.toBe(true)
      },
    )

    testAsync(
      "returns 400 for malformed source context schema",
      async t => {
        let body = JSON.parseOrThrow(`{
          "invocations": [{"file":"src/App.tsx","line":"bad","column":1}]
        }`)
        let req = Helpers.makePostRequest("http://localhost/frontman/resolve-source-location", body)

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~sourceRoot=Helpers.sourceRoot,
          req,
        )

        t->expect(response.status)->Expect.toBe(400)
        let text = await response->WebAPI.Response.text
        t->expect(text->String.includes("Invalid request"))->Expect.toBe(true)
      },
    )

    testAsync(
      "returns package structured failures as 422",
      async t => {
        let resolver = async (_context, _options): RequestHandlers.sourceResolutionResult => {
          success: false,
          data: None,
          error: Some({code: "POSITION_NOT_FOUND", message: "No original position"}),
        }
        let context: RequestHandlers.sourceContext = {definition: None, invocations: []}

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~sourceRoot=Helpers.sourceRoot,
          ~resolveSourceContext=resolver,
          Helpers.sourceRequest(context),
        )

        t->expect(response.status)->Expect.toBe(422)
        let text = await response->WebAPI.Response.text
        t
        ->expect(text->String.includes("POSITION_NOT_FOUND: No original position"))
        ->Expect.toBe(true)
      },
    )

    testAsync(
      "returns 500 when the package unexpectedly throws",
      async t => {
        let resolver = async (_context, _options) => JsError.throwWithMessage("package exploded")
        let context: RequestHandlers.sourceContext = {definition: None, invocations: []}

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~sourceRoot=Helpers.sourceRoot,
          ~resolveSourceContext=resolver,
          Helpers.sourceRequest(context),
        )

        t->expect(response.status)->Expect.toBe(500)
        let text = await response->WebAPI.Response.text
        t->expect(text->String.includes("package exploded"))->Expect.toBe(true)
      },
    )

    testAsync(
      "rejects virtual, nonexistent, and outside-sourceRoot returned paths",
      async t => {
        let rejectReturnedPath = async (file, expectedDetails) => {
          let resolver = async (_context, _options): RequestHandlers.sourceResolutionResult => {
            success: true,
            data: Some({
              definition: None,
              invocations: [Helpers.sourceLocation(~file)],
            }),
            error: None,
          }
          let context: RequestHandlers.sourceContext = {definition: None, invocations: []}
          let response = await RequestHandlers.handleResolveSourceLocation(
            ~sourceRoot=Helpers.sourceRoot,
            ~resolveSourceContext=resolver,
            Helpers.sourceRequest(context),
          )

          t->expect(response.status)->Expect.toBe(422)
          let text = await response->WebAPI.Response.text
          t->expect(text->String.includes(expectedDetails))->Expect.toBe(true)
        }
        let outsideFile = Path.join([Helpers.projectRoot, ".next", "server", "rsc-chunk.js"])

        let _ = await Promise.all([
          rejectReturnedPath("about://React/Server/virtual", "remained virtual"),
          rejectReturnedPath("Missing.tsx", "does not exist"),
          rejectReturnedPath(outsideFile, "outside source root"),
        ])
      },
    )
  })
})
