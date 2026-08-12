open Vitest

module RelayBaseUrl = Client__RelayBaseUrl

describe("Client__RelayBaseUrl", () => {
  test("uses origin for regular sites", t => {
    let baseUrl = RelayBaseUrl.fromParts(
      ~protocol="https:",
      ~host="example.com",
      ~pathname="/frontman",
    )

    t->expect(baseUrl)->Expect.toBe("https://example.com")
  })

  test("preserves the leading Playground scope segment", t => {
    let baseUrl = RelayBaseUrl.fromParts(
      ~protocol="https:",
      ~host="playground.wordpress.net",
      ~pathname="/scope:kind-hip-valley/frontman",
    )

    t->expect(baseUrl)->Expect.toBe("https://playground.wordpress.net/scope:kind-hip-valley")
  })

  test("uses an explicit WordPress front-controller prefix", t => {
    let baseUrl = RelayBaseUrl.fromParts(
      ~protocol="https:",
      ~host="example.com",
      ~pathname="/index.php/frontman",
      ~routePrefix="/index.php",
    )

    t->expect(baseUrl)->Expect.toBe("https://example.com/index.php")
  })

  test("explicit route prefix wins over inferred Playground scope", t => {
    let baseUrl = RelayBaseUrl.fromParts(
      ~protocol="https:",
      ~host="playground.wordpress.net",
      ~pathname="/scope:kind-hip-valley/index.php/frontman",
      ~routePrefix="/scope:kind-hip-valley/index.php",
    )

    t
    ->expect(baseUrl)
    ->Expect.toBe("https://playground.wordpress.net/scope:kind-hip-valley/index.php")
  })

  test("preserves the leading Playground scope segment for nested preview routes", t => {
    let baseUrl = RelayBaseUrl.fromParts(
      ~protocol="https:",
      ~host="playground.wordpress.net",
      ~pathname="/scope:kind-hip-valley/about/frontman",
    )

    t->expect(baseUrl)->Expect.toBe("https://playground.wordpress.net/scope:kind-hip-valley")
  })

  test("ignores scope-like segments that are not the leading pathname segment", t => {
    let baseUrl = RelayBaseUrl.fromParts(
      ~protocol="https:",
      ~host="example.com",
      ~pathname="/blog/scope:kind-hip-valley/frontman",
    )

    t->expect(baseUrl)->Expect.toBe("https://example.com")
  })
})
