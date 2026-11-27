open Vitest

@module("vitest") @scope("vi") external stubEnv: (string, string) => unit = "stubEnv"
@module("vitest") @scope("vi") external unstubAllEnvs: unit => unit = "unstubAllEnvs"

let setup: unit => unit = %raw(`function() {
  delete window.__tracked;
  window.__frontmanRuntime = {framework: "vite"};
  window.heap = {
    track: function(name, properties) { window.__tracked = {name: name, properties: properties}; }
  };
}`)
let trackedName: unit => string = %raw(`function() { return window.__tracked.name }`)
let trackedProperties: unit => Dict.t<
  JSON.t,
> = %raw(`function() { return window.__tracked.properties }`)

beforeEach(() => setup())
afterEach(() => unstubAllEnvs())

let property = (properties, name) => properties->Dict.get(name)->Option.flatMap(JSON.Decode.string)

test("tracks normalized relay outcomes", t => {
  stubEnv("VITE_HEAP_APP_ID", "test-environment")
  Client__Analytics.track(RelayConnectionCompleted(Failure(NetworkError)))
  let failed = trackedProperties()

  t->expect(trackedName())->Expect.toBe("relay_connection_completed")
  t->expect(property(failed, "framework"))->Expect.toEqual(Some("vite"))
  t->expect(property(failed, "outcome"))->Expect.toEqual(Some("failure"))
  t->expect(property(failed, "reason_code"))->Expect.toEqual(Some("network_error"))

  Client__Analytics.track(RelayConnectionCompleted(Success))
  let succeeded = trackedProperties()
  t->expect(property(succeeded, "outcome"))->Expect.toEqual(Some("success"))
  t->expect(property(succeeded, "reason_code"))->Expect.toEqual(None)
})

test("an unconfigured build leaves the page's Heap instance alone", t => {
  stubEnv("VITE_HEAP_APP_ID", "")
  Client__Heap.init()
  Client__Heap.identify("test-user")
  Client__Analytics.track(RelayConnectionCompleted(Success))
  let untouched: bool = %raw(`window.__tracked === undefined && window.heap.load === undefined`)
  t->expect(untouched)->Expect.toBe(true)
})
