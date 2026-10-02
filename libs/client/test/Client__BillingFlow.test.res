open Vitest
module Reducer = Client__State__StateReducer
module Billing = Client__Billing

type spy<'a>
@module("vitest") @scope("vi") external spyOn: (WebAPI.Window.t, string) => spy<'a> = "spyOn"
@send external mockImplementation: (spy<'a>, 'a) => unit = "mockImplementation"
@module("vitest") @scope("vi") external stubGlobal: (string, 'a) => unit = "stubGlobal"
@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"
@module("vitest") @scope("vi") external restoreAllMocks: unit => unit = "restoreAllMocks"
@module("vitest") @scope("vi") external waitFor: (unit => unit) => promise<unit> = "waitFor"
@obj
external makeTab: (
  ~closed: bool,
  ~close: unit => unit,
  ~location: {"assign": string => unit},
) => WebAPI.Window.t = ""
@set external setClosed: (WebAPI.Window.t, bool) => unit = "closed"
@get external opener: WebAPI.Window.t => Null.t<WebAPI.Window.t> = "opener"
@new external headers: WebAPI.FetchTypes.headersInit => WebAPI.FetchTypes.headers = "Headers"

let state = ref(Reducer.defaultState)
let tab = ref(WebAPI.Window.current)
let calls = ref([])
let navigations = ref([])
let closed = ref(0)
let opened = ref(0)
let authenticated = ref(0)
let navigationBlocked = ref(false)
let response = (status, body) => WebAPI.Response.fromString(body, ~init={status: status})
let pending = ref(Promise.withResolvers())
let rec dispatch = action => {
  let (updated, effects) = Reducer.next(state.contents, action)
  state := updated
  effects->Array.forEach(effect => Reducer.handleEffect(effect, updated, dispatch))
}
let request = operation => dispatch(RequestBilling(operation))
let flush = () => Promise.make((resolve, _) => {setTimeout(() => resolve(), 0)->ignore})
let urlResponse = () => response(200, `{"url":"https://billing.stripe.test/session"}`)
let statusJson = (status, access) =>
  `{"status":"${status}","access_allowed":${Bool.toString(
      access,
    )},"has_billing_customer":true,"interval":"monthly","current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`
let failed = () =>
  switch state.contents.billingFlow {
  | Failed(_) => true
  | _ => false
  }

beforeEach(() => {
  Client__EmbeddedAuth.saveToken("editor-account-a")
  calls := []
  navigations := []
  closed := 0
  opened := 0
  authenticated := 0
  navigationBlocked := false
  pending := Promise.withResolvers()
  tab :=
    makeTab(
      ~closed=false,
      ~close=() => closed := closed.contents + 1,
      ~location={
        "assign": url => {
          switch navigationBlocked.contents {
          | true => failwith("navigation blocked")
          | false => ()
          }
          navigations.contents->Array.push(url)
        },
      },
    )
  state := {
      ...Reducer.defaultState,
      acpSession: AcpSessionActive({
        apiBaseUrl: "https://api.example",
        requireAuthentication: () => authenticated := authenticated.contents + 1,
        sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _, ~_meta as _) => (),
        sendSessionCommand: _ => (),
        loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
        deleteSession: (_, ~onComplete as _) => (),
      }),
    }
  spyOn(WebAPI.Window.current, "open")->mockImplementation((url: string, target: string) => {
    assert(url == "about:blank" && target == "_blank")
    opened := opened.contents + 1
    Null.make(tab.contents)
  })
  stubGlobal("fetch", (url: string, init: WebAPI.FetchTypes.requestInit) => {
    switch url->String.endsWith("/status") {
    | true => ()
    | false => assert(opened.contents == 1)
    }
    calls.contents->Array.push((url, init))
    pending.contents.promise
  })
})
afterEach(() => {
  restoreAllMocks()
  unstubAllGlobals()
  Client__EmbeddedAuth.clearToken()
})

[
  (Billing.Checkout(Monthly), "checkout", Some(`{"interval":"monthly"}`)),
  (Billing.Checkout(Yearly), "checkout", Some(`{"interval":"yearly"}`)),
  (Billing.CustomerPortal, "customer-portal", None),
]->Array.forEach(((operation, path, body)) => {
  testAsync(
    `opens synchronously and requests bearer-owned ${path} ${body->Option.getOr("")}`,
    async t => {
      request(operation)
      t->expect(navigations.contents)->Expect.toEqual(["about:blank"])
      t->expect(opener(tab.contents))->Expect.toEqual(Null.null)
      t->expect(state.contents.billingFlow)->Expect.toEqual(Billing.Opening)
      request(operation)
      t->expect(calls.contents->Array.length)->Expect.toBe(1)
      let (url, init) = calls.contents->Array.get(0)->Option.getOrThrow
      t->expect(url)->Expect.toBe(`https://api.example/api/billing/${path}`)
      t->expect(init.method)->Expect.toEqual(Some("POST"))
      t->expect(init.credentials)->Expect.toEqual(Some(WebAPI.FetchTypes.Omit))
      t
      ->expect(init.headers->Option.getOrThrow->headers->WebAPI.Headers.get("Authorization"))
      ->Expect.toEqual(Null.make("Bearer editor-account-a"))
      t->expect(init.body)->Expect.toEqual(body->Option.map(WebAPI.BodyInit.fromString))
      pending.contents.resolve(urlResponse())
      await waitFor(
        () =>
          t
          ->expect(navigations.contents)
          ->Expect.toEqual(["about:blank", "https://billing.stripe.test/session"]),
      )
      t->expect(state.contents.billingFlow)->Expect.toEqual(Billing.Idle)
    },
  )
})

testAsync("launch effects report URLs without navigating", async t => {
  let (opening, effects) = Reducer.next(state.contents, RequestBilling(CustomerPortal))
  let actions = []
  effects->Array.forEach(effect =>
    Reducer.handleEffect(effect, opening, action => actions->Array.push(action))
  )
  pending.contents.resolve(urlResponse())
  await waitFor(() =>
    t
    ->expect(actions)
    ->Expect.toEqual([
      Reducer.BillingUrlReceived({tab: tab.contents, url: "https://billing.stripe.test/session"}),
    ])
  )
  t->expect(navigations.contents)->Expect.toEqual(["about:blank"])
})

["closed", "navigation error"]->Array.forEach(mode => {
  testAsync(`${mode} reports a launch failure`, async t => {
    request(CustomerPortal)
    switch mode {
    | "closed" => setClosed(tab.contents, true)
    | _ => navigationBlocked := true
    }
    pending.contents.resolve(urlResponse())
    await waitFor(() => t->expect(failed())->Expect.toBe(true))
    t->expect(closed.contents)->Expect.toBe(1)
  })
})

test("blocked popups do not create unused checkout", t => {
  spyOn(WebAPI.Window.current, "open")->mockImplementation((_: string, _: string) => Null.null)
  request(CustomerPortal)
  t->expect(calls.contents)->Expect.toEqual([])
  t
  ->expect(state.contents.billingFlow)
  ->Expect.toEqual(Billing.Failed("Allow popups, then try again."))
})

[("missing", 0), ("expired", 1)]->Array.forEach(((mode, launches)) => {
  testAsync(`${mode} authorization uses embedded login`, async t => {
    switch mode {
    | "missing" => Client__EmbeddedAuth.clearToken()
    | _ => ()
    }
    request(CustomerPortal)
    pending.contents.resolve(response(401, `{"error":"authentication_required"}`))
    await waitFor(() => t->expect(authenticated.contents)->Expect.toBe(1))
    t->expect(Client__EmbeddedAuth.loadToken())->Expect.toEqual(None)
    t->expect(closed.contents)->Expect.toBe(launches)
    t->expect(calls.contents->Array.length)->Expect.toBe(launches)
  })
})

[409, 502]->Array.forEach(status => {
  testAsync(`HTTP ${Int.toString(status)} closes tab and shows server error`, async t => {
    request(CustomerPortal)
    pending.contents.resolve(
      response(status, `{"error":"Billing rejected the request","request_id":"ref-test"}`),
    )
    await waitFor(
      () =>
        t
        ->expect(state.contents.billingFlow)
        ->Expect.toEqual(
          Billing.Failed("Billing rejected the request Request reference: ref-test"),
        ),
    )
    t->expect(closed.contents)->Expect.toBe(1)
  })
})

["network", "unsafe URL"]->Array.forEach(mode => {
  testAsync(`${mode} closes tab and allows retry`, async t => {
    request(CustomerPortal)
    switch mode {
    | "network" => pending.contents.reject(Failure("offline"))
    | _ => pending.contents.resolve(response(200, `{"url":"javascript:void(0)"}`))
    }
    await waitFor(() => t->expect(failed())->Expect.toBe(true))
    t->expect(closed.contents)->Expect.toBe(1)
  })
})

["account switch", "session clear"]->Array.forEach(mode => {
  testAsync(`${mode} discards in-flight billing URL`, async t => {
    request(CustomerPortal)
    dispatch(ClearAcpSession)
    switch mode {
    | "account switch" => Client__EmbeddedAuth.saveToken("other-account")
    | _ => ()
    }
    let (_, init) = calls.contents->Array.get(0)->Option.getOrThrow
    t->expect((init.signal->Option.getOrThrow->Null.getOrThrow).aborted)->Expect.toBe(true)
    pending.contents.resolve(urlResponse())
    await waitFor(() => t->expect(closed.contents)->Expect.toBe(1))
    t->expect(navigations.contents)->Expect.toEqual(["about:blank"])
    t->expect(state.contents.billingFlow)->Expect.toEqual(Billing.Idle)
  })
})

["http", "parse", "network"]->Array.forEach(mode => {
  testAsync(`background status ${mode} failure preserves launch lock`, async t => {
    request(CustomerPortal)
    pending := Promise.withResolvers()
    request(Status)
    switch mode {
    | "network" => pending.contents.reject(Failure("offline"))
    | "http" => pending.contents.resolve(response(502, `{"error":"Unavailable"}`))
    | _ => pending.contents.resolve(response(200, "{}"))
    }
    await waitFor(
      () =>
        t
        ->expect(
          switch state.contents.billingStatus {
          | Error(_) => true
          | _ => false
          },
        )
        ->Expect.toBe(true),
    )
    t->expect(state.contents.billingFlow)->Expect.toEqual(Billing.Opening)
    request(CustomerPortal)
    t->expect(calls.contents->Array.length)->Expect.toBe(2)
  })
})

["refresh", "push"]->Array.forEach(source => {
  testAsync(`newer ${source} invalidates older status`, async t => {
    request(Status)
    let old = pending.contents
    let (_, init) = calls.contents->Array.get(0)->Option.getOrThrow
    switch source {
    | "refresh" =>
      pending := Promise.withResolvers()
      request(Status)
      pending.contents.resolve(response(200, statusJson("active", true)))
      await waitFor(
        () => t->expect(Reducer.Selectors.billingAccessAllowed(state.contents))->Expect.toBe(true),
      )
    | _ =>
      dispatch(
        BillingStatusReceived(
          S.parseOrThrow(JSON.parseOrThrow(statusJson("active", true)), ~to=Billing.statusSchema),
        ),
      )
    }
    t->expect((init.signal->Option.getOrThrow->Null.getOrThrow).aborted)->Expect.toBe(true)
    let latest = state.contents.billingStatus
    old.resolve(response(200, statusJson("inactive", false)))
    await flush()
    t->expect(state.contents.billingStatus)->Expect.toBe(latest)
  })
})

["success", "unauthorized", "network"]->Array.forEach(outcome => {
  testAsync(`session clear discards late status ${outcome} with same bearer`, async t => {
    request(Status)
    dispatch(ClearAcpSession)
    t->expect(Client__EmbeddedAuth.loadToken())->Expect.toEqual(Some("editor-account-a"))
    switch outcome {
    | "network" => pending.contents.reject(Failure("offline"))
    | "unauthorized" => pending.contents.resolve(response(401, "{}"))
    | _ => pending.contents.resolve(response(200, statusJson("active", true)))
    }
    await flush()
    t->expect(state.contents.billingStatus)->Expect.toEqual(Billing.NotLoaded)
    t->expect(state.contents.billingFlow)->Expect.toEqual(Billing.Idle)
    t->expect(authenticated.contents)->Expect.toBe(0)
  })
})

testAsync("status refresh uses same bearer without opening tab", async t => {
  request(Status)
  pending.contents.resolve(response(200, statusJson("trialing", true)))
  await waitFor(() =>
    t->expect(Reducer.Selectors.billingAccessAllowed(state.contents))->Expect.toBe(true)
  )
  t->expect(opened.contents)->Expect.toBe(0)
  let (url, init) = calls.contents->Array.get(0)->Option.getOrThrow
  t->expect(url)->Expect.toBe("https://api.example/api/billing/status")
  t->expect(init.method)->Expect.toEqual(Some("GET"))
})
