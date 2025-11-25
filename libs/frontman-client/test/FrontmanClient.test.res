open Vitest

describe("FrontmanClient API", _t => {
  test("should create client with endpoint and sessionId", _t => {
    let _client = FrontmanClient.make(
      ~endpoint="ws://localhost:4000/socket",
      ~sessionId="test-session",
    )
  })

  test("should have connect method returning promise", _t => {
    let client = FrontmanClient.make(
      ~endpoint="ws://localhost:4000/socket",
      ~sessionId="test-session",
    )

    // Just verify method exists and returns promise (won't actually connect without server)
    let _promise = client->FrontmanClient.connect()
  })
})
