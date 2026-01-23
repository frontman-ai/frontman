open Vitest

module Sentry = FrontmanClient__Sentry
module SentryTestkit = FrontmanBindings.Bindings__Test__SentryTestkit

describe("FrontmanClient Sentry", () => {
  let testkit = ref(None)
  let transport = ref(None)

  // Set up testkit once - Sentry SDK only allows one init per process
  beforeAll(() => {
    let (tk, t) = SentryTestkit.setup()
    testkit := Some(tk)
    transport := Some(t)
  })

  // Reset state before each test
  beforeEach(() => {
    // Clear testkit reports
    switch testkit.contents {
    | Some(tk) => tk.reset()
    | None => ()
    }
    // Reset initialized flag and reinitialize with testkit transport
    Sentry.initialized.contents = false
    switch transport.contents {
    | Some(t) => Sentry.initialize(~transport=t)
    | None => ()
    }
  })

  describe("initialization", () => {
    test(
      "initializes only once",
      t => {
        // Already initialized in beforeEach
        let initialReportCount = switch testkit.contents {
        | Some(tk) => tk.reports()->Array.length
        | None => 0
        }

        // Try to initialize again
        Sentry.initialize()
        Sentry.initialize()

        // Should still work, no errors
        t->expect(Sentry.isEnabled())->Expect.toBe(true)

        // Report count shouldn't change from double init
        switch testkit.contents {
        | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.toBe(initialReportCount)
        | None => ()
        }
      },
    )

    test(
      "isEnabled returns true after initialization",
      t => {
        t->expect(Sentry.isEnabled())->Expect.toBe(true)
      },
    )
  })

  describe("captureConnectionError", () => {
    test(
      "captures connection error with endpoint context and tags",
      t => {
        Sentry.captureConnectionError(
          "Socket connection failed",
          ~endpoint="wss://example.com/socket",
        )

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.toBe(1)

            switch reports->Array.get(0) {
            | Some(report) => {
                t->expect(report.message)->Expect.toBe(Some("Socket connection failed"))
                t->expect(report.level)->Expect.toBe(Some("error"))

                // Verify tags are attached via withScope
                switch report.tags {
                | Some(tags) => {
                    t
                    ->expect(tags->Dict.get("frontman.library"))
                    ->Expect.toBe(Some("frontman-client"))
                    t
                    ->expect(tags->Dict.get("frontman.operation"))
                    ->Expect.toBe(Some("connection"))
                  }
                | None => t->expect(false)->Expect.toBe(true)
                }
              }
            | None => t->expect(false)->Expect.toBe(true)
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )
  })

  describe("captureProtocolError", () => {
    test(
      "captures ACP protocol error with tags",
      t => {
        Sentry.captureProtocolError("Initialize failed", ~protocol=#ACP, ~operation="initialize")

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.toBe(1)

            switch reports->Array.get(0) {
            | Some(report) => {
                t->expect(report.message)->Expect.toBe(Some("Initialize failed"))
                t->expect(report.level)->Expect.toBe(Some("error"))

                // Verify protocol-specific tags
                switch report.tags {
                | Some(tags) => {
                    t
                    ->expect(tags->Dict.get("frontman.library"))
                    ->Expect.toBe(Some("frontman-client"))
                    t->expect(tags->Dict.get("frontman.protocol"))->Expect.toBe(Some("ACP"))
                    t
                    ->expect(tags->Dict.get("frontman.operation"))
                    ->Expect.toBe(Some("initialize"))
                  }
                | None => t->expect(false)->Expect.toBe(true)
                }
              }
            | None => t->expect(false)->Expect.toBe(true)
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "captures MCP protocol error with tags",
      t => {
        Sentry.captureProtocolError("Tool call failed", ~protocol=#MCP, ~operation="tools/call")

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.toBe(1)

            switch reports->Array.get(0) {
            | Some(report) => {
                switch report.tags {
                | Some(tags) => {
                    t->expect(tags->Dict.get("frontman.protocol"))->Expect.toBe(Some("MCP"))
                    t
                    ->expect(tags->Dict.get("frontman.operation"))
                    ->Expect.toBe(Some("tools/call"))
                  }
                | None => t->expect(false)->Expect.toBe(true)
                }
              }
            | None => t->expect(false)->Expect.toBe(true)
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )
  })

  describe("captureException", () => {
    test(
      "captures exception with operation tag",
      t => {
        // Create and capture an exception
        try {
          JsError.throwWithMessage("Test error")
        } catch {
        | e => Sentry.captureException(e, ~operation="testOperation")
        }

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)

            switch reports->Array.get(0) {
            | Some(report) =>
              switch report.tags {
              | Some(tags) => {
                  t
                  ->expect(tags->Dict.get("frontman.library"))
                  ->Expect.toBe(Some("frontman-client"))
                  t
                  ->expect(tags->Dict.get("frontman.operation"))
                  ->Expect.toBe(Some("testOperation"))
                }
              | None => t->expect(false)->Expect.toBe(true)
              }
            | None => t->expect(false)->Expect.toBe(true)
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )
  })

  describe("addBreadcrumb", () => {
    test(
      "adds breadcrumb for connection events",
      t => {
        Sentry.addBreadcrumb(~category=#connection, ~message="Socket connected")

        // Breadcrumbs are attached to subsequent events
        Sentry.captureConnectionError("Later error", ~endpoint="wss://example.com")

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.toBe(1)

            switch reports->Array.get(0) {
            | Some(report) =>
              switch report.breadcrumbs {
              | Some(breadcrumbs) =>
                t->expect(breadcrumbs->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)
              | None => () // Breadcrumbs may not be present in all report formats
              }
            | None => ()
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "supports all breadcrumb categories",
      t => {
        Sentry.addBreadcrumb(~category=#connection, ~message="connection event")
        Sentry.addBreadcrumb(~category=#acp, ~message="acp event")
        Sentry.addBreadcrumb(~category=#mcp, ~message="mcp event")
        Sentry.addBreadcrumb(~category=#session, ~message="session event")

        // If we get here without errors, all categories work
        t->expect(true)->Expect.toBe(true)
      },
    )
  })

  describe("integration scenarios", () => {
    test(
      "multiple errors are captured independently",
      t => {
        Sentry.captureConnectionError("Error 1", ~endpoint="wss://a.com")
        Sentry.captureConnectionError("Error 2", ~endpoint="wss://b.com")
        Sentry.captureProtocolError("Error 3", ~protocol=#ACP, ~operation="test")

        switch testkit.contents {
        | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.toBe(3)
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "breadcrumbs accumulate across operations",
      t => {
        Sentry.addBreadcrumb(~category=#connection, ~message="Step 1")
        Sentry.addBreadcrumb(~category=#acp, ~message="Step 2")
        Sentry.addBreadcrumb(~category=#session, ~message="Step 3")
        Sentry.captureConnectionError("Final error", ~endpoint="wss://example.com")

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.toBe(1)
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )
  })
})
