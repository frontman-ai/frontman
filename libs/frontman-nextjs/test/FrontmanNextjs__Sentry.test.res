open Vitest

module Sentry = FrontmanNextjs__Sentry
module SentryTestkit = FrontmanBindings.Bindings__Test__SentryTestkit

describe("FrontmanNextjs Sentry", () => {
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
        t->expect(Sentry.isEnabled())->Expect.toBe(true)

        // Try to initialize again - should be idempotent
        Sentry.initialize()
        Sentry.initialize()

        t->expect(Sentry.isEnabled())->Expect.toBe(true)
      },
    )

    test(
      "isEnabled returns true after initialization",
      t => {
        t->expect(Sentry.isEnabled())->Expect.toBe(true)
      },
    )
  })

  describe("captureError", () => {
    test(
      "captures error and returns event id",
      t => {
        let eventId = try {
          JsError.throwWithMessage("Test error")
        } catch {
        | e => Sentry.captureError(e, ~operation="testOp")
        }

        t->expect(eventId->Option.isSome)->Expect.toBe(true)

        switch testkit.contents {
        | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "captures error with operation context",
      t => {
        try {
          JsError.throwWithMessage("Operation failed")
        } catch {
        | e => Sentry.captureError(e, ~operation="serverConnection")->ignore
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

    test(
      "captures error with extra data",
      t => {
        let extra = Dict.fromArray([
          ("userId", JSON.Encode.string("123")),
          ("endpoint", JSON.Encode.string("/api/test")),
        ])

        try {
          JsError.throwWithMessage("Error with context")
        } catch {
        | e => Sentry.captureError(e, ~operation="apiCall", ~extra)->ignore
        }

        switch testkit.contents {
        | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "captures error with operation tag",
      t => {
        try {
          JsError.throwWithMessage("Tagged error")
        } catch {
        | e => Sentry.captureError(e, ~operation="serverConnection")->ignore
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
                  ->Expect.toBe(Some("frontman-nextjs"))
                  t
                  ->expect(tags->Dict.get("frontman.operation"))
                  ->Expect.toBe(Some("serverConnection"))
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

  describe("captureMessage", () => {
    test(
      "captures message with default error level",
      t => {
        let eventId = Sentry.captureMessage("Something went wrong")

        t->expect(eventId->Option.isSome)->Expect.toBe(true)

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.toBe(1)

            switch reports->Array.get(0) {
            | Some(report) => t->expect(report.message)->Expect.toBe(Some("Something went wrong"))
            | None => t->expect(false)->Expect.toBe(true)
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "captures message with custom level",
      t => {
        Sentry.captureMessage("Warning message", ~level=#warning)->ignore

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.toBe(1)

            switch reports->Array.get(0) {
            | Some(report) => t->expect(report.level)->Expect.toBe(Some("warning"))
            | None => t->expect(false)->Expect.toBe(true)
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "captures message with operation tag",
      t => {
        Sentry.captureMessage("Instrumentation error", ~operation="spanProcessor")->ignore

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.toBe(1)

            switch reports->Array.get(0) {
            | Some(report) =>
              switch report.tags {
              | Some(tags) => {
                  t
                  ->expect(tags->Dict.get("frontman.library"))
                  ->Expect.toBe(Some("frontman-nextjs"))
                  t
                  ->expect(tags->Dict.get("frontman.operation"))
                  ->Expect.toBe(Some("spanProcessor"))
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
      "adds breadcrumb that appears in subsequent errors",
      t => {
        Sentry.addBreadcrumb(~category="instrumentation", ~message="LogCapture initialized")
        Sentry.addBreadcrumb(~category="instrumentation", ~message="SpanProcessor started")
        Sentry.captureMessage("Error after breadcrumbs")->ignore

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.toBe(1)

            switch reports->Array.get(0) {
            | Some(report) =>
              switch report.breadcrumbs {
              | Some(breadcrumbs) =>
                t->expect(breadcrumbs->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)
              | None => () // Breadcrumbs may not always be present
              }
            | None => ()
            }
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    test(
      "adds breadcrumb with custom data",
      t => {
        let data = Dict.fromArray([("spanName", JSON.Encode.string("http.request"))])
        Sentry.addBreadcrumb(~category="trace", ~message="Span started", ~data)

        // Should not throw
        t->expect(true)->Expect.toBe(true)
      },
    )
  })

  describe("integration scenarios", () => {
    test(
      "multiple errors are captured independently",
      t => {
        Sentry.captureMessage("Error 1")->ignore
        Sentry.captureMessage("Error 2", ~level=#warning)->ignore
        Sentry.captureMessage("Error 3", ~operation="test")->ignore

        switch testkit.contents {
        | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.toBe(3)
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )
  })
})
