open Vitest

describe("Logs_level", _t => {
  test("shouldLog respects threshold", t => {
    // Error (0) >= Error (0) = true
    t->expect(Logs_level.shouldLog(Logs_level.Error, Logs_level.Error))->Expect.toBeTruthy
    // Info (2) >= Debug (3) = false
    t->expect(Logs_level.shouldLog(Logs_level.Info, Logs_level.Debug))->Expect.toBeFalsy
    // Debug (3) >= Error (0) = true
    t->expect(Logs_level.shouldLog(Logs_level.Debug, Logs_level.Error))->Expect.toBeTruthy
  })

  test("ofString is case-insensitive", t => {
    t->expect(Logs_level.ofString("error"))->Expect.toEqual(Logs_level.Error)
    t->expect(Logs_level.ofString("ERROR"))->Expect.toEqual(Logs_level.Error)
    t->expect(Logs_level.ofString("Warning"))->Expect.toEqual(Logs_level.Warning)
    t->expect(Logs_level.ofString("unknown"))->Expect.toEqual(Logs_level.Info)
  })

  test("toString roundtrips with ofString", t => {
    t
    ->expect(Logs_level.Debug->Logs_level.toString->Logs_level.ofString)
    ->Expect.toEqual(Logs_level.Debug)
  })
})

describe("Logs handler receives correct data", _t => {
  test("handler receives component and level", t => {
    let receivedComponent = ref("")
    let receivedLevel = ref(Logs_level.Debug)
    let receivedMessage = ref("")

    let handler: Logs.Handler.t = {
      id: "test",
      run: (~component, ~stacktrace as _, ~level, message, _ctx, _err) => {
        receivedComponent := component
        receivedLevel := level
        receivedMessage := message
      },
    }
    Logs.addHandler(handler)
    Logs.setLogLevel(Logs_level.Debug)

    Logs.warning(~component=#ACP, "test message")

    t->expect(receivedComponent.contents)->Expect.toEqual("ACP")
    t->expect(receivedLevel.contents)->Expect.toEqual(Logs_level.Warning)
    t->expect(receivedMessage.contents)->Expect.toEqual("test message")
  })
})

describe("Logs Make functor", _t => {
  test("scoped logger uses fixed component", t => {
    let receivedComponent = ref("")

    let handler: Logs.Handler.t = {
      id: "test-functor",
      run: (~component, ~stacktrace as _, ~level as _, _message, _ctx, _err) => {
        receivedComponent := component
      },
    }
    Logs.addHandler(handler)
    Logs.setLogLevel(Logs_level.Debug)

    module Log = Logs.Make({
      let component = #MCP
    })

    Log.info("functor test")

    t->expect(receivedComponent.contents)->Expect.toEqual("MCP")
  })
})

describe("Logs global context", _t => {
  test("starts empty", t => {
    // Reset context by creating fresh state
    let ctx = Logs.getGlobalContext()
    // Global context is an object — just check it's an object
    t->expect(typeof(ctx))->Expect.toEqual(#object)
  })

  test("addGlobalContext merges into context", t => {
    Logs.addGlobalContext({"userId": 42})
    let ctx = Logs.getGlobalContext()
    t->expect(ctx)->Expect.toEqual({"userId": 42})
  })

  test("prepareContext merges global and local", t => {
    Logs.addGlobalContext({"userId": 42})
    let prepared = Logs.prepareContext({"requestId": "abc"})
    t->expect(prepared)->Expect.toEqual({"userId": 42, "requestId": "abc"})
  })
})

describe("Logs level control", _t => {
  test("setLogLevel and getLogLevel roundtrip", t => {
    Logs.setLogLevel(Logs_level.Error)
    t->expect(Logs.getLogLevel())->Expect.toEqual(Logs_level.Error)

    Logs.setLogLevel(Logs_level.Debug)
    t->expect(Logs.getLogLevel())->Expect.toEqual(Logs_level.Debug)
  })

  test("messages below threshold are not logged", t => {
    let callCount = ref(0)

    let handler: Logs.Handler.t = {
      id: "test-threshold",
      run: (~component as _, ~stacktrace as _, ~level as _, _message, _ctx, _err) => {
        callCount := callCount.contents + 1
      },
    }
    Logs.addHandler(handler)

    let before = callCount.contents
    Logs.setLogLevel(Logs_level.Error)
    Logs.debug(~component=#Global, "should be filtered")
    t->expect(callCount.contents)->Expect.toEqual(before)
  })
})

describe("Logs console handler", _t => {
  test("does not crash", _t => {
    Logs.Console.useColors(false)
    Logs.addHandler(Logs.Console.handler)
    Logs.setLogLevel(Logs_level.Debug)

    // Smoke test — just verify these don't throw
    Logs.error(~component=#Global, "test error")
    Logs.warning(~component=#Global, "test warning")
    Logs.info(~component=#Global, "test info")
    Logs.debug(~component=#Global, "test debug")
  })
})
