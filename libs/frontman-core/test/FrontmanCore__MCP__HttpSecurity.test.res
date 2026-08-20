open Vitest

module HttpSecurity = FrontmanCore__MCP__HttpSecurity

let authorize = async _headers => HttpSecurity.Authorized

describe("MCP route-independent HTTP security boundary", _t => {
  test("accepts only canonical HTTP origins", t => {
    let accepted = [
      "http://localhost",
      "http://localhost:3000",
      "https://example.com",
      "https://EXAMPLE.com",
      "https://example.com:443",
      "https://[::1]:8443",
    ]
    let rejected = [
      "",
      "null",
      "https:example.com",
      "https:/example.com",
      "https:\\example.com",
      "https://example.com/",
      "https://user@example.com",
      "https://example.com.",
      "https://%65xample.com",
      "https://example.com/path",
      "https://example.com?query",
      "https://example.com#hash",
      "ftp://example.com",
      "http://0177.0.0.1",
      "https://example.com, https://example.com",
    ]

    accepted->Array.forEach(origin => t->expect(HttpSecurity.parseOrigin(origin))->Expect.toBeSome)
    rejected->Array.forEach(origin => t->expect(HttpSecurity.parseOrigin(origin))->Expect.toBeNone)
  })

  test("crashes on a malformed configured origin", t => {
    let crashed = try {
      HttpSecurity.make(~allowedOrigins=["https://example.com/path"], ~authorize)->ignore
      false
    } catch {
    | Failure(message) =>
      t->expect(message)->Expect.toBe("Invalid configured MCP origin: https://example.com/path")
      true
    | exn => throw(exn)
    }
    t->expect(crashed)->Expect.toBe(true)
  })

  testAsync(
    "rejects missing, null, malformed, and unlisted origins before authorization",
    async t => {
      let authorizationCount = ref(0)
      let policy = HttpSecurity.make(
        ~allowedOrigins=["https://allowed.example"],
        ~authorize=async _headers => {
          authorizationCount.contents = authorizationCount.contents + 1
          HttpSecurity.Authorized
        },
      )
      let origins = [
        None,
        Some("null"),
        Some("https://allowed.example, https://allowed.example"),
        Some("http://allowed.example"),
        Some("https://allowed.example:444"),
        Some("https://sub.allowed.example"),
        Some("https://allowed.example.evil.test"),
        Some("https://evil.example"),
      ]

      let _ = await origins
      ->Array.map(
        async origin => {
          let headers = switch origin {
          | Some(origin) => WebAPI.HeadersInit.fromKeyValueArray([("Origin", origin)])
          | None => WebAPI.HeadersInit.fromKeyValueArray([])
          }
          let request = WebAPI.Request.fromURL("http://localhost/mcp", ~init={headers: headers})
          switch await HttpSecurity.validate(~request, ~policy) {
          | HttpSecurity.Allowed(_) => failwith("Expected Origin rejection")
          | HttpSecurity.Rejected(response) =>
            t->expect(response.status)->Expect.toBe(403)
            t->expect(await response->WebAPI.Response.text)->Expect.toBe("")
            t
            ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
            ->Expect.toEqual(Null.Null)
          }
        },
      )
      ->Promise.all

      t->expect(authorizationCount.contents)->Expect.toBe(0)
    },
  )

  testAsync("maps authentication and authorization failures after Origin acceptance", async t => {
    let assertDecision = async (~decision, ~status) => {
      let policy = HttpSecurity.make(
        ~allowedOrigins=["https://allowed.example"],
        ~authorize=async _headers => decision,
      )
      let headers = WebAPI.HeadersInit.fromKeyValueArray([("Origin", "https://allowed.example")])
      let request = WebAPI.Request.fromURL("http://localhost/mcp", ~init={headers: headers})
      switch await HttpSecurity.validate(~request, ~policy) {
      | HttpSecurity.Allowed(_) => failwith("Expected authorization rejection")
      | HttpSecurity.Rejected(response) =>
        t->expect(response.status)->Expect.toBe(status)
        t->expect(await response->WebAPI.Response.text)->Expect.toBe("")
        t
        ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin")->Null.toOption)
        ->Expect.toBe(Some("https://allowed.example"))
        t
        ->expect(response.headers->WebAPI.Headers.get("Vary")->Null.toOption)
        ->Expect.toBe(Some("Origin"))
        t
        ->expect(response.headers->WebAPI.Headers.get("WWW-Authenticate"))
        ->Expect.toEqual(Null.Null)
      }
    }

    await assertDecision(~decision=HttpSecurity.MissingAuthentication, ~status=401)
    await assertDecision(~decision=HttpSecurity.InsufficientAuthorization, ~status=403)
  })

  testAsync("isolates later validation headers from authorization callback mutation", async t => {
    let policy = HttpSecurity.make(
      ~allowedOrigins=["https://allowed.example"],
      ~authorize=async headers => {
        headers->WebAPI.Headers.set(~name="Mcp-Method", ~value="changed")
        HttpSecurity.Authorized
      },
    )
    let headers = WebAPI.HeadersInit.fromKeyValueArray([
      ("Origin", "https://allowed.example"),
      ("Mcp-Method", "server/discover"),
    ])
    let request = WebAPI.Request.fromURL("http://localhost/mcp", ~init={headers: headers})

    switch await HttpSecurity.validate(~request, ~policy) {
    | HttpSecurity.Rejected(_) => failwith("Expected security acceptance")
    | HttpSecurity.Allowed(_) =>
      t
      ->expect(request.headers->WebAPI.Headers.get("Mcp-Method")->Null.toOption)
      ->Expect.toBe(Some("server/discover"))
    }
  })
})
