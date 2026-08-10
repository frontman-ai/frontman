open Vitest

let _installHeapCapture: unit => unit = %raw(`function() {
  window.__frontmanHeapTrack = null;
  window.heap = {
    track: function(name, properties) {
      window.__frontmanHeapTrack = { name: name, properties: properties };
    }
  };
}`)

let _clearHeapCapture: unit => unit = %raw(`function() {
  delete window.__frontmanHeapTrack;
  delete window.heap;
  delete window.__frontmanRuntime;
}`)

let _setFramework: string => unit = %raw(`function(framework) {
  window.__frontmanRuntime = { framework: framework };
}`)

let _eventName: unit => string = %raw(`function() { return window.__frontmanHeapTrack.name }`)
let _properties: unit => Dict.t<
  JSON.t,
> = %raw(`function() { return window.__frontmanHeapTrack.properties }`)

beforeEach(() => {
  _installHeapCapture()
  _setFramework("nextjs")
})

afterEach(() => _clearHeapCapture())

describe("Client__Heap.track", () => {
  test("tracks fixed event names with normalized framework", t => {
    Client__Heap.track(Client__Heap.PromptSubmissionInitiated)

    t->expect(_eventName())->Expect.toBe("prompt_submission_initiated")
    t
    ->expect(_properties()->Dict.get("framework")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("nextjs"))
  })

  test("tracks normalized relay failures without raw error details", t => {
    Client__Heap.track(
      Client__Heap.LocalRelayDiscoveryCompleted({
        outcome: Client__Heap.Failure(Client__Heap.NetworkError),
      }),
    )

    let properties = _properties()
    t->expect(_eventName())->Expect.toBe("local_relay_discovery_completed")
    t
    ->expect(properties->Dict.get("outcome")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("failure"))
    t
    ->expect(properties->Dict.get("reason_code")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("network_error"))
    let keys = properties->Dict.keysToArray
    t->expect(keys->Array.length)->Expect.toBe(3)
    t->expect(keys->Array.includes("framework"))->Expect.toBe(true)
    t->expect(keys->Array.includes("outcome"))->Expect.toBe(true)
    t->expect(keys->Array.includes("reason_code"))->Expect.toBe(true)
  })

  test("maps every activation event to its fixed Heap name", t => {
    [
      (Client__Heap.AuthenticatedClientIdentified, "authenticated_client_identified"),
      (Client__Heap.ProviderSetupBlockerShown, "provider_setup_blocker_shown"),
      (Client__Heap.PromptSubmissionInitiated, "prompt_submission_initiated"),
      (Client__Heap.TaskCreationRequested, "task_creation_requested"),
      (Client__Heap.PromptRequestSent, "prompt_request_sent"),
    ]->Array.forEach(
      ((event, expectedName)) => {
        Client__Heap.track(event)
        t->expect(_eventName())->Expect.toBe(expectedName)
      },
    )
  })

  test("omits a reason code from successful relay completion", t => {
    Client__Heap.track(Client__Heap.LocalRelayDiscoveryCompleted({outcome: Success}))

    let properties = _properties()
    t
    ->expect(properties->Dict.get("outcome")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("success"))
    t->expect(properties->Dict.get("reason_code"))->Expect.toEqual(None)
  })
})
