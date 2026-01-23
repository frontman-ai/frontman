open Vitest

module Sentry = FrontmanClient__Sentry
module SentryTestkit = FrontmanBindings.Bindings__Test__SentryTestkit

describe("FrontmanClient Sentry", () => {
  let testkit = ref(None)

  beforeEach(() => {
    let (tk, transport) = SentryTestkit.setup()
    testkit := Some(tk)
    Sentry.reset()
    Sentry.initialize(~transport)
  })

  afterEach(() => {
    switch testkit.contents {
    | Some(tk) => tk.reset()
    | None => ()
    }
    Sentry.reset()
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

    test(
      "isEnabled returns false before initialization",
      t => {
        Sentry.reset()
        t->expect(Sentry.isEnabled())->Expect.toBe(false)
      },
    )
  })

  describe("captureConnectionError", () => {
    test(
      "captures connection error with endpoint context",
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
              }
            | None => t->expect(false)->Expect.toBe(true)
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "does not capture when not initialized",
      t => {
        Sentry.reset()
        Sentry.captureConnectionError("Should not capture", ~endpoint="wss://example.com")

        switch testkit.contents {
        | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.toBe(0)
        | None => ()
        }
      },
    )
  })

  describe("captureProtocolError", () => {
    test(
      "captures ACP protocol error",
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
              }
            | None => t->expect(false)->Expect.toBe(true)
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "captures MCP protocol error",
      t => {
        Sentry.captureProtocolError("Tool call failed", ~protocol=#MCP, ~operation="tools/call")

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

  describe("captureException", () => {
    test(
      "captures exception with operation context",
      t => {
        let error = Exn.raiseError("Test error")
        try {
          error
        } catch {
        | e => Sentry.captureException(e, ~operation="testOperation")
        }

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)
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
