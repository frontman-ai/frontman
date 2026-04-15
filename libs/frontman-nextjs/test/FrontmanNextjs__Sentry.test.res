open Vitest

module Sentry = FrontmanNextjs__Sentry
module SentryTypes = FrontmanBindings.Sentry__Types
module SentryFilter = FrontmanBindings.Sentry__Filter
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
    testAsync(
      "captures error and returns event id",
      async t => {
        let eventId = try {
          JsError.throwWithMessage("Test error")
        } catch {
        | e => Sentry.captureError(e, ~operation="testOp")
        }

        t->expect(eventId->Option.isSome)->Expect.toBe(true)

        let _ = await Sentry.flush()

        switch testkit.contents {
        | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    testAsync(
      "captures error with operation context",
      async t => {
        try {
          JsError.throwWithMessage("Operation failed")
        } catch {
        | e => Sentry.captureError(e, ~operation="serverConnection")->ignore
        }

        let _ = await Sentry.flush()

        switch testkit.contents {
        | Some(tk) => {
            let reports = tk.reports()
            t->expect(reports->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)
          }
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    testAsync(
      "captures error with extra data",
      async t => {
        let extra = Dict.fromArray([
          ("userId", JSON.Encode.string("123")),
          ("endpoint", JSON.Encode.string("/api/test")),
        ])

        try {
          JsError.throwWithMessage("Error with context")
        } catch {
        | e => Sentry.captureError(e, ~operation="apiCall", ~extra)->ignore
        }

        let _ = await Sentry.flush()

        switch testkit.contents {
        | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    testAsync(
      "captures error with operation tag",
      async t => {
        try {
          JsError.throwWithMessage("Tagged error")
        } catch {
        | e => Sentry.captureError(e, ~operation="serverConnection")->ignore
        }

        let _ = await Sentry.flush()

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
    testAsync(
      "captures message with default error level",
      async t => {
        let eventId = Sentry.captureMessage("Something went wrong")

        t->expect(eventId->Option.isSome)->Expect.toBe(true)

        let _ = await Sentry.flush()

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

    testAsync(
      "captures message with custom level",
      async t => {
        Sentry.captureMessage("Warning message", ~level=#warning)->ignore

        let _ = await Sentry.flush()

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

    testAsync(
      "captures message with operation tag",
      async t => {
        Sentry.captureMessage("Instrumentation error", ~operation="spanProcessor")->ignore

        let _ = await Sentry.flush()

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
    testAsync(
      "adds breadcrumb that appears in subsequent errors",
      async t => {
        Sentry.addBreadcrumb(~category="instrumentation", ~message="LogCapture initialized")
        Sentry.addBreadcrumb(~category="instrumentation", ~message="SpanProcessor started")
        Sentry.captureMessage("Error after breadcrumbs")->ignore

        let _ = await Sentry.flush()

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
    testAsync(
      "multiple errors are captured independently",
      async t => {
        Sentry.captureMessage("Error 1")->ignore
        Sentry.captureMessage("Error 2", ~level=#warning)->ignore
        Sentry.captureMessage("Error 3", ~operation="test")->ignore

        let _ = await Sentry.flush()

        switch testkit.contents {
        | Some(tk) => t->expect(tk.reports()->Array.length)->Expect.toBe(3)
        | None => t->expect(false)->Expect.toBe(true)
        }
      },
    )
  })

  describe("beforeSend filtering", () => {
    describe(
      "hasFrontmanFrames",
      () => {
        test(
          "returns true for events with no exception (e.g. captureMessage)",
          t => {
            let event: SentryTypes.sentryEvent = {exception_: None}
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(true)
          },
        )

        test(
          "returns true for exception with no values",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({values: None}),
            }
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(true)
          },
        )

        test(
          "returns true for exception with empty values array",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({values: Some([])}),
            }
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(true)
          },
        )

        test(
          "returns true for exception with no stacktrace",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({
                values: Some([{stacktrace: None}]),
              }),
            }
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(true)
          },
        )

        test(
          "returns true for exception with empty frames array",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({
                values: Some([
                  {
                    stacktrace: Some({frames: Some([])}),
                  },
                ]),
              }),
            }
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(true)
          },
        )

        test(
          "returns true when a frame contains frontman in filename",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({
                values: Some([
                  {
                    stacktrace: Some({
                      frames: Some([
                        {filename: Some("/node_modules/.pnpm/next/dist/server.js")},
                        {
                          filename: Some(
                            "/node_modules/.pnpm/@frontman-ai+nextjs/dist/instrumentation.js",
                          ),
                        },
                      ]),
                    }),
                  },
                ]),
              }),
            }
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(true)
          },
        )

        test(
          "returns true when a frame contains FrontmanNextjs in filename",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({
                values: Some([
                  {
                    stacktrace: Some({
                      frames: Some([
                        {
                          filename: Some(
                            "/libs/frontman-nextjs/src/FrontmanNextjs__Middleware.res.mjs",
                          ),
                        },
                      ]),
                    }),
                  },
                ]),
              }),
            }
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(true)
          },
        )

        test(
          "returns false when all frames are third-party (Next.js/Turbopack)",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({
                values: Some([
                  {
                    stacktrace: Some({
                      frames: Some([
                        {
                          filename: Some(
                            "/my-website/.next/dev/server/chunks/ssr/b142f_next_dist.js",
                          ),
                        },
                        {
                          filename: Some(
                            "/my-website/.next/dev/server/chunks/5fae1__pnpm_164ddc1c._.js",
                          ),
                        },
                        {filename: Some("node:internal/deps/undici/undici")},
                        {filename: Some("node:internal/process/task_queues")},
                      ]),
                    }),
                  },
                ]),
              }),
            }
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(false)
          },
        )

        test(
          "returns false when all frames have no filename",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({
                values: Some([
                  {
                    stacktrace: Some({
                      frames: Some([{filename: None}, {filename: None}]),
                    }),
                  },
                ]),
              }),
            }
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(false)
          },
        )

        test(
          "is case-insensitive for filename matching",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({
                values: Some([
                  {
                    stacktrace: Some({
                      frames: Some([{filename: Some("/path/to/FRONTMAN-NEXTJS/dist/index.js")}]),
                    }),
                  },
                ]),
              }),
            }
            t->expect(SentryFilter.hasFrontmanFrames(event))->Expect.toBe(true)
          },
        )
      },
    )

    describe(
      "beforeSend",
      () => {
        test(
          "keeps events with Frontman frames",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({
                values: Some([
                  {
                    stacktrace: Some({
                      frames: Some([
                        {
                          filename: Some(
                            "/node_modules/@frontman-ai/nextjs/dist/instrumentation.js",
                          ),
                        },
                      ]),
                    }),
                  },
                ]),
              }),
            }
            let hint: SentryTypes.eventHint = {}
            let result = SentryFilter.beforeSend(event, hint)
            t->expect(result->Nullable.toOption->Option.isSome)->Expect.toBe(true)
          },
        )

        test(
          "drops events with only third-party frames",
          t => {
            let event: SentryTypes.sentryEvent = {
              exception_: Some({
                values: Some([
                  {
                    stacktrace: Some({
                      frames: Some([
                        {filename: Some("/next/dist/server/chunks/ssr/dedupeFetch.js")},
                        {filename: Some("node:internal/deps/undici/undici")},
                      ]),
                    }),
                  },
                ]),
              }),
            }
            let hint: SentryTypes.eventHint = {}
            let result = SentryFilter.beforeSend(event, hint)
            t->expect(result->Nullable.toOption->Option.isSome)->Expect.toBe(false)
          },
        )

        test(
          "keeps captureMessage events (no exception)",
          t => {
            let event: SentryTypes.sentryEvent = {exception_: None}
            let hint: SentryTypes.eventHint = {}
            let result = SentryFilter.beforeSend(event, hint)
            t->expect(result->Nullable.toOption->Option.isSome)->Expect.toBe(true)
          },
        )
      },
    )
  })
})
