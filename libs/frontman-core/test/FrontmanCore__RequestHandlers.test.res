open Vitest

module RequestHandlers = FrontmanCore__RequestHandlers
module ToolRegistry = FrontmanCore__ToolRegistry
module Relay = FrontmanFrontmanProtocol.FrontmanProtocol__Relay

module Helpers = {
  let handlerConfig: RequestHandlers.handlerConfig = {
    projectRoot: "/test/project",
    sourceRoot: "/test/project",
    serverName: "test-server",
    serverVersion: "1.0.0",
  }

  let registry = ToolRegistry.coreTools()

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
}

describe("RequestHandlers", _t => {
  describe("handleGetTools", _t => {
    testAsync("returns JSON with tools array", async t => {
      let response = RequestHandlers.handleGetTools(
        ~registry=Helpers.registry,
        ~config=Helpers.handlerConfig,
      )

      let body = await response->WebAPI.Response.text
      let json = JSON.parseOrThrow(body)
      let obj = json->JSON.Decode.object->Option.getOrThrow

      t->expect(obj->Dict.get("tools")->Option.isSome)->Expect.toBe(true)
    })

    testAsync("returns application/json content type", async t => {
      let response = RequestHandlers.handleGetTools(
        ~registry=Helpers.registry,
        ~config=Helpers.handlerConfig,
      )

      t
      ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
      ->Expect.toEqual(Null.Value("application/json"))
    })

    testAsync("includes server info in response", async t => {
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
    })

    testAsync("includes protocol version", async t => {
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
    })

    test("returns 200 status", t => {
      let response = RequestHandlers.handleGetTools(
        ~registry=Helpers.registry,
        ~config=Helpers.handlerConfig,
      )

      t->expect(response.status)->Expect.toBe(200)
    })

    testAsync("returns empty tools array for empty registry", async t => {
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
    })
  })

  describe("handleToolCall", _t => {
    testAsync("returns SSE stream for valid tool call", async t => {
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
    })

    testAsync("returns 400 for malformed request body", async t => {
      let body = JSON.Encode.string("not an object")
      let req = Helpers.makePostRequest("http://localhost/frontman/tools/call", body)

      let response = await RequestHandlers.handleToolCall(
        ~registry=Helpers.registry,
        ~config=Helpers.handlerConfig,
        req,
      )

      t->expect(response.status)->Expect.toBe(400)
    })

    testAsync("returns 400 error body for missing name field", async t => {
      let body = JSON.Encode.object(Dict.fromArray([("wrong_field", JSON.Encode.string("value"))]))
      let req = Helpers.makePostRequest("http://localhost/frontman/tools/call", body)

      let response = await RequestHandlers.handleToolCall(
        ~registry=Helpers.registry,
        ~config=Helpers.handlerConfig,
        req,
      )

      t->expect(response.status)->Expect.toBe(400)
      let text = await response->WebAPI.Response.text
      t->expect(text->String.includes("Invalid request"))->Expect.toBe(true)
    })

    testAsync("SSE stream contains result event for nonexistent tool", async t => {
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

      // SSE response should still be 200 with event-stream content type
      t->expect(response.status)->Expect.toBe(200)

      let text = await response->WebAPI.Response.text
      t->expect(text->String.includes("event: error"))->Expect.toBe(true)
      t->expect(text->String.includes("Tool not found"))->Expect.toBe(true)
    })
  })

  describe("handleResolveSourceLocation", _t => {
    testAsync("returns 400 for completely invalid JSON body", async t => {
      let body = JSON.Encode.string("not an object")
      let req = Helpers.makePostRequest(
        "http://localhost/frontman/resolve-source-location",
        body,
      )

      let response = await RequestHandlers.handleResolveSourceLocation(
        ~sourceRoot="/test/project",
        req,
      )

      t->expect(response.status)->Expect.toBe(400)
      let text = await response->WebAPI.Response.text
      t->expect(text->String.includes("Invalid request"))->Expect.toBe(true)
    })

    testAsync("returns 400 for missing required fields", async t => {
      let body = JSON.Encode.object(
        Dict.fromArray([("componentName", JSON.Encode.string("Foo"))]),
      )
      let req = Helpers.makePostRequest(
        "http://localhost/frontman/resolve-source-location",
        body,
      )

      let response = await RequestHandlers.handleResolveSourceLocation(
        ~sourceRoot="/test/project",
        req,
      )

      t->expect(response.status)->Expect.toBe(400)
      let text = await response->WebAPI.Response.text
      t->expect(text->String.includes("Invalid request"))->Expect.toBe(true)
    })

    testAsync("returns 400 when line is wrong type", async t => {
      let body = JSON.Encode.object(
        Dict.fromArray([
          ("componentName", JSON.Encode.string("App")),
          ("file", JSON.Encode.string("src/App.tsx")),
          ("line", JSON.Encode.string("not a number")),
          ("column", JSON.Encode.float(1.0)),
        ]),
      )
      let req = Helpers.makePostRequest(
        "http://localhost/frontman/resolve-source-location",
        body,
      )

      let response = await RequestHandlers.handleResolveSourceLocation(
        ~sourceRoot="/test/project",
        req,
      )

      t->expect(response.status)->Expect.toBe(400)
    })
  })

  describe("Sury schemas", _t => {
    test("resolveSourceLocationRequestSchema parses valid input", t => {
      let json = JSON.Encode.object(
        Dict.fromArray([
          ("componentName", JSON.Encode.string("MyComponent")),
          ("file", JSON.Encode.string("src/MyComponent.tsx")),
          ("line", JSON.Encode.float(42.0)),
          ("column", JSON.Encode.float(10.0)),
        ]),
      )

      let parsed = json->S.parseOrThrow(RequestHandlers.resolveSourceLocationRequestSchema)

      t->expect(parsed.componentName)->Expect.toBe("MyComponent")
      t->expect(parsed.file)->Expect.toBe("src/MyComponent.tsx")
      t->expect(parsed.line)->Expect.toBe(42)
      t->expect(parsed.column)->Expect.toBe(10)
    })

    test("resolveSourceLocationResponseSchema serializes correctly", t => {
      let response: RequestHandlers.resolveSourceLocationResponse = {
        componentName: "App",
        file: "src/App.tsx",
        line: 5,
        column: 3,
      }

      let json = response->S.reverseConvertToJsonOrThrow(
        RequestHandlers.resolveSourceLocationResponseSchema,
      )
      let obj = json->JSON.Decode.object->Option.getOrThrow

      t
      ->expect(obj->Dict.get("componentName")->Option.flatMap(JSON.Decode.string))
      ->Expect.toEqual(Some("App"))
      t
      ->expect(obj->Dict.get("file")->Option.flatMap(JSON.Decode.string))
      ->Expect.toEqual(Some("src/App.tsx"))
    })

    test("errorResponseSchema serializes with details", t => {
      let err: RequestHandlers.errorResponse = {
        error: "Something failed",
        details: Some("stack trace here"),
      }

      let json = err->S.reverseConvertToJsonOrThrow(RequestHandlers.errorResponseSchema)
      let obj = json->JSON.Decode.object->Option.getOrThrow

      t
      ->expect(obj->Dict.get("error")->Option.flatMap(JSON.Decode.string))
      ->Expect.toEqual(Some("Something failed"))
      t
      ->expect(obj->Dict.get("details")->Option.flatMap(JSON.Decode.string))
      ->Expect.toEqual(Some("stack trace here"))
    })

    test("errorResponseSchema serializes without details", t => {
      let err: RequestHandlers.errorResponse = {
        error: "Something failed",
        details: None,
      }

      let json = err->S.reverseConvertToJsonOrThrow(RequestHandlers.errorResponseSchema)
      let text = JSON.stringify(json)

      t->expect(text->String.includes("Something failed"))->Expect.toBe(true)
    })

    test("resolveSourceLocationRequestSchema rejects missing fields", t => {
      let json = JSON.Encode.object(
        Dict.fromArray([("componentName", JSON.Encode.string("Foo"))]),
      )

      let result = try {
        let _ = json->S.parseOrThrow(RequestHandlers.resolveSourceLocationRequestSchema)
        Ok()
      } catch {
      | _ => Error("parse failed")
      }

      t->expect(result)->Expect.toEqual(Error("parse failed"))
    })

    test("resolveSourceLocationRequestSchema rejects wrong types", t => {
      let json = JSON.Encode.object(
        Dict.fromArray([
          ("componentName", JSON.Encode.float(123.0)),
          ("file", JSON.Encode.string("ok")),
          ("line", JSON.Encode.float(1.0)),
          ("column", JSON.Encode.float(1.0)),
        ]),
      )

      let result = try {
        let _ = json->S.parseOrThrow(RequestHandlers.resolveSourceLocationRequestSchema)
        Ok()
      } catch {
      | _ => Error("parse failed")
      }

      t->expect(result)->Expect.toEqual(Error("parse failed"))
    })
  })
})
