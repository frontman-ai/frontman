open Vitest

module RequestHandlers = FrontmanCore__RequestHandlers

module Helpers = {
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
  describe("handleResolveSourceLocation", _t => {
    testAsync(
      "normalizes resolved files relative to configured sourceRoot",
      async t => {
        let body = JSON.Encode.object(
          Dict.fromArray([
            ("componentName", JSON.Encode.string("App")),
            ("file", JSON.Encode.string("/workspace/apps/web/src/App.tsx")),
            ("line", JSON.Encode.float(12.0)),
            ("column", JSON.Encode.float(4.0)),
          ]),
        )

        let req = Helpers.makePostRequest("http://localhost/frontman/resolve-source-location", body)

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~sourceRoot="/workspace/apps/web",
          req,
        )

        t->expect(response.status)->Expect.toBe(200)
        let json = await response->WebAPI.Response.json
        let result = json->S.parseOrThrow(~to=RequestHandlers.resolveSourceLocationResponseSchema)
        t->expect(result.file)->Expect.toBe("src/App.tsx")
      },
    )

    testAsync(
      "returns 400 for completely invalid JSON body",
      async t => {
        let body = JSON.Encode.string("not an object")
        let req = Helpers.makePostRequest("http://localhost/frontman/resolve-source-location", body)

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~sourceRoot="/test/project",
          req,
        )

        t->expect(response.status)->Expect.toBe(400)
        let text = await response->WebAPI.Response.text
        t->expect(text->String.includes("Invalid request"))->Expect.toBe(true)
      },
    )

    testAsync(
      "returns 400 for missing required fields",
      async t => {
        let body = JSON.Encode.object(
          Dict.fromArray([("componentName", JSON.Encode.string("Foo"))]),
        )
        let req = Helpers.makePostRequest("http://localhost/frontman/resolve-source-location", body)

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~sourceRoot="/test/project",
          req,
        )

        t->expect(response.status)->Expect.toBe(400)
        let text = await response->WebAPI.Response.text
        t->expect(text->String.includes("Invalid request"))->Expect.toBe(true)
      },
    )

    testAsync(
      "returns 400 when line is wrong type",
      async t => {
        let body = JSON.Encode.object(
          Dict.fromArray([
            ("componentName", JSON.Encode.string("App")),
            ("file", JSON.Encode.string("src/App.tsx")),
            ("line", JSON.Encode.string("not a number")),
            ("column", JSON.Encode.float(1.0)),
          ]),
        )
        let req = Helpers.makePostRequest("http://localhost/frontman/resolve-source-location", body)

        let response = await RequestHandlers.handleResolveSourceLocation(
          ~sourceRoot="/test/project",
          req,
        )

        t->expect(response.status)->Expect.toBe(400)
      },
    )
  })

  describe("Sury schemas", _t => {
    test(
      "resolveSourceLocationRequestSchema parses valid input",
      t => {
        let json = JSON.Encode.object(
          Dict.fromArray([
            ("componentName", JSON.Encode.string("MyComponent")),
            ("file", JSON.Encode.string("src/MyComponent.tsx")),
            ("line", JSON.Encode.float(42.0)),
            ("column", JSON.Encode.float(10.0)),
          ]),
        )

        let parsed = json->S.parseOrThrow(~to=RequestHandlers.resolveSourceLocationRequestSchema)

        t->expect(parsed.componentName)->Expect.toBe("MyComponent")
        t->expect(parsed.file)->Expect.toBe("src/MyComponent.tsx")
        t->expect(parsed.line)->Expect.toBe(42)
        t->expect(parsed.column)->Expect.toBe(10)
      },
    )

    test(
      "resolveSourceLocationResponseSchema serializes correctly",
      t => {
        let response: RequestHandlers.resolveSourceLocationResponse = {
          componentName: "App",
          file: "src/App.tsx",
          line: 5,
          column: 3,
        }

        let json =
          response->S.decodeOrThrow(
            ~from=RequestHandlers.resolveSourceLocationResponseSchema,
            ~to=S.json,
          )
        let obj = json->JSON.Decode.object->Option.getOrThrow

        t
        ->expect(obj->Dict.get("componentName")->Option.flatMap(JSON.Decode.string))
        ->Expect.toEqual(Some("App"))
        t
        ->expect(obj->Dict.get("file")->Option.flatMap(JSON.Decode.string))
        ->Expect.toEqual(Some("src/App.tsx"))
      },
    )

    test(
      "errorResponseSchema serializes with details",
      t => {
        let err: RequestHandlers.errorResponse = {
          error: "Something failed",
          details: Some("stack trace here"),
        }

        let json =
          err->S.decodeOrThrow(
            ~from=RequestHandlers.errorResponseSchema,
            ~to=S.json->S.noValidation(true),
          )
        let obj = json->JSON.Decode.object->Option.getOrThrow

        t
        ->expect(obj->Dict.get("error")->Option.flatMap(JSON.Decode.string))
        ->Expect.toEqual(Some("Something failed"))
        t
        ->expect(obj->Dict.get("details")->Option.flatMap(JSON.Decode.string))
        ->Expect.toEqual(Some("stack trace here"))
      },
    )

    test(
      "errorResponseSchema serializes without details",
      t => {
        let err: RequestHandlers.errorResponse = {
          error: "Something failed",
          details: None,
        }

        let json =
          err->S.decodeOrThrow(
            ~from=RequestHandlers.errorResponseSchema,
            ~to=S.json->S.noValidation(true),
          )
        let text = JSON.stringify(json)

        t->expect(text->String.includes("Something failed"))->Expect.toBe(true)
      },
    )

    test(
      "resolveSourceLocationRequestSchema rejects missing fields",
      t => {
        let json = JSON.Encode.object(
          Dict.fromArray([("componentName", JSON.Encode.string("Foo"))]),
        )

        let result = try {
          let _ = json->S.parseOrThrow(~to=RequestHandlers.resolveSourceLocationRequestSchema)
          Ok()
        } catch {
        | _ => Error("parse failed")
        }

        t->expect(result)->Expect.toEqual(Error("parse failed"))
      },
    )

    test(
      "resolveSourceLocationRequestSchema rejects wrong types",
      t => {
        let json = JSON.Encode.object(
          Dict.fromArray([
            ("componentName", JSON.Encode.float(123.0)),
            ("file", JSON.Encode.string("ok")),
            ("line", JSON.Encode.float(1.0)),
            ("column", JSON.Encode.float(1.0)),
          ]),
        )

        let result = try {
          let _ = json->S.parseOrThrow(~to=RequestHandlers.resolveSourceLocationRequestSchema)
          Ok()
        } catch {
        | _ => Error("parse failed")
        }

        t->expect(result)->Expect.toEqual(Error("parse failed"))
      },
    )
  })
})
