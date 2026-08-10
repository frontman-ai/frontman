open Vitest

let property = (properties, name) => properties->Dict.get(name)->Option.flatMap(JSON.Decode.string)

describe("Client__Heap.encodeEvent", () => {
  test("maps activation event names", t => {
    [
      (Client__Heap.AuthenticatedClientIdentified, "authenticated_client_identified"),
      (Client__Heap.ProviderSetupBlockerShown, "provider_setup_blocker_shown"),
      (Client__Heap.PromptSubmissionInitiated, "prompt_submission_initiated"),
      (Client__Heap.TaskCreationRequested, "task_creation_requested"),
      (Client__Heap.PromptRequestSent, "prompt_request_sent"),
    ]->Array.forEach(
      ((event, expectedName)) => {
        let (name, properties) = Client__Heap.encodeEvent(~framework="nextjs", event)
        t->expect(name)->Expect.toBe(expectedName)
        t->expect(property(properties, "framework"))->Expect.toEqual(Some("nextjs"))
      },
    )
  })

  test("normalizes relay outcomes", t => {
    let (_, failed) = Client__Heap.encodeEvent(
      ~framework="vite",
      LocalRelayDiscoveryCompleted({outcome: Failure(NetworkError)}),
    )
    let (_, succeeded) = Client__Heap.encodeEvent(
      ~framework="vite",
      LocalRelayDiscoveryCompleted({outcome: Success}),
    )

    t->expect(property(failed, "outcome"))->Expect.toEqual(Some("failure"))
    t->expect(property(failed, "reason_code"))->Expect.toEqual(Some("network_error"))
    t->expect(failed->Dict.keysToArray->Array.length)->Expect.toBe(3)
    t->expect(property(succeeded, "outcome"))->Expect.toEqual(Some("success"))
    t->expect(property(succeeded, "reason_code"))->Expect.toEqual(None)
  })
})
