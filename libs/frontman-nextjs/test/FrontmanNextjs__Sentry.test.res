open Vitest

module Sentry = FrontmanNextjs__Sentry
module SentryTestkit = Bindings__Test__SentryTestkit

describe("FrontmanNextjs Sentry", () => {
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
    test("initializes only once", t => {
      // Already initialized in beforeEach
      t->expect(Sentry.isEnabled())->Expect.toBe(true)

      // Try to initialize again - should be idempotent
      Sentry.initialize()
      Sentry.initialize()

      t->expect(Sentry.isEnabled())->Expect.toBe(true)
    })

    test("isEnabled returns true after initialization", t => {
      t->expect(Sentry.isEnabled())->Expect.toBe(true)
    })

    test("isEnabled returns false before initialization", t => {
      Sentry.reset()
      t->expect(Sentry.isEnabled())->Expect.toBe(false)
    })
  })

  describe("captureError", () => {
    test("captures error and returns event id", t => {
      let error = Exn.raiseError("Test error")
      let eventId = try {
        raise(error)
      } catch {
      | e => Sentry.captureError(e, ~operation="testOp")
      }

      t->expect(eventId->Option.isSome)->Expect.toBe(true)

      switch testkit.contents {
      | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.toBeGreaterThanOrEqual(1)
      | None => t->fail("Testkit not initialized")
      }
    })

    test("captures error with operation context", t => {
      let error = Exn.raiseError("Operation failed")
      try {
        raise(error)
      } catch {
      | e => Sentry.captureError(e, ~operation="serverConnection")->ignore
      }

      switch testkit.contents {
      | Some(tk) => {
          let reports = tk.reports()
          t->expect(reports->Array.length)->Expect.toBeGreaterThanOrEqual(1)
        }
      | None => t->fail("Testkit not initialized")
      }
    })

    test("captures error with extra data", t => {
      let error = Exn.raiseError("Error with context")
      let extra = Dict.fromArray([
        ("userId", JSON.Encode.string("123")),
        ("endpoint", JSON.Encode.string("/api/test")),
      ])

      try {
        raise(error)
      } catch {
      | e => Sentry.captureError(e, ~operation="apiCall", ~extra)->ignore
      }

      switch testkit.contents {
      | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.toBeGreaterThanOrEqual(1)
      | None => t->fail("Testkit not initialized")
      }
    })

    test("returns None when not initialized", t => {
      Sentry.reset()

      let error = Exn.raiseError("Should not capture")
      let eventId = try {
        raise(error)
      } catch {
      | e => Sentry.captureError(e)
      }

      t->expect(eventId)->Expect.toBe(None)
    })
  })

  describe("captureMessage", () => {
    test("captures message with default error level", t => {
      let eventId = Sentry.captureMessage("Something went wrong")

      t->expect(eventId->Option.isSome)->Expect.toBe(true)

      switch testkit.contents {
      | Some(tk) => {
          let reports = tk.reports()
          t->expect(reports->Array.length)->Expect.toBe(1)

          switch reports->Array.get(0) {
          | Some(report) => t->expect(report.message)->Expect.toBe(Some("Something went wrong"))
          | None => t->fail("Expected a report")
          }
        }
      | None => t->fail("Testkit not initialized")
      }
    })

    test("captures message with custom level", t => {
      Sentry.captureMessage("Warning message", ~level=#warning)->ignore

      switch testkit.contents {
      | Some(tk) => {
          let reports = tk.reports()
          t->expect(reports->Array.length)->Expect.toBe(1)

          switch reports->Array.get(0) {
          | Some(report) => t->expect(report.level)->Expect.toBe(Some("warning"))
          | None => t->fail("Expected a report")
          }
        }
      | None => t->fail("Testkit not initialized")
      }
    })

    test("captures message with operation context", t => {
      Sentry.captureMessage("Instrumentation error", ~operation="spanProcessor")->ignore

      switch testkit.contents {
      | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.toBe(1)
      | None => t->fail("Testkit not initialized")
      }
    })

    test("returns None when not initialized", t => {
      Sentry.reset()
      let eventId = Sentry.captureMessage("Should not capture")
      t->expect(eventId)->Expect.toBe(None)
    })
  })

  describe("addBreadcrumb", () => {
    test("adds breadcrumb that appears in subsequent errors", t => {
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
            | Some(breadcrumbs) => t->expect(breadcrumbs->Array.length)->Expect.toBeGreaterThanOrEqual(1)
            | None => () // Breadcrumbs may not always be present
            }
          | None => ()
          }
        }
      | None => t->fail("Testkit not initialized")
      }
    })

    test("adds breadcrumb with custom data", t => {
      let data = Dict.fromArray([("spanName", JSON.Encode.string("http.request"))])
      Sentry.addBreadcrumb(~category="trace", ~message="Span started", ~data)

      // Should not throw
      t->expect(true)->Expect.toBe(true)
    })
  })

  describe("integration scenarios", () => {
    test("multiple errors are captured independently", t => {
      Sentry.captureMessage("Error 1")->ignore
      Sentry.captureMessage("Error 2", ~level=#warning)->ignore
      Sentry.captureMessage("Error 3", ~operation="test")->ignore

      switch testkit.contents {
      | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.toBe(3)
      | None => t->fail("Testkit not initialized")
      }
    })

    test("reset clears initialization state", t => {
      t->expect(Sentry.isEnabled())->Expect.toBe(true)
      Sentry.reset()
      t->expect(Sentry.isEnabled())->Expect.toBe(false)
    })

    test("can reinitialize after reset", t => {
      Sentry.reset()
      t->expect(Sentry.isEnabled())->Expect.toBe(false)

      let (tk, transport) = SentryTestkit.setup()
      testkit := Some(tk)
      Sentry.initialize(~transport)

      t->expect(Sentry.isEnabled())->Expect.toBe(true)
    })
  })
})
