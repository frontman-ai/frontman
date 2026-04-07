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
