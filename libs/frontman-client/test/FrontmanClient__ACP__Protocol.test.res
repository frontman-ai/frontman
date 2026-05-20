open Vitest

module Client = FrontmanClient__ACP__Client
module Protocol = FrontmanClient__ACP__Protocol
module Channel = FrontmanClient__Phoenix__Channel

let _makeChannel: unit => Channel.t = %raw(`
  function() {
    return {
      push: function(_event, payload) {
        globalThis.__frontmanProtocolTestPayload = payload;
        return { receive: function() { return this; } };
      }
    };
  }
`)

let _getPushedPayload: unit => JSON.t = %raw(`
  function() { return globalThis.__frontmanProtocolTestPayload; }
`)
let _clearPushedPayload: unit => unit = %raw(`
  function() { delete globalThis.__frontmanProtocolTestPayload; }
`)

afterEach(_t => {
  _clearPushedPayload()
})

describe("ACP Protocol", _t => {
  test("sendPrompt includes _meta traits in session/prompt request", t => {
    let state = ref(Client.initialState)
    let meta = JSON.Encode.object(
      Dict.fromArray([
        ("framework", JSON.Encode.string("nextjs")),
        (
          "traits",
          [JSON.Encode.string("react"), JSON.Encode.string("typescript")]->JSON.Encode.array,
        ),
      ]),
    )

    Protocol.sendPrompt(
      ~channel=_makeChannel(),
      ~state,
      ~sessionId="session-1",
      ~prompt=[],
      ~_meta=Some(meta),
      ~onMessage=None,
    )->ignore

    let request = _getPushedPayload()->JSON.Decode.object->Option.getOrThrow
    let params = request->Dict.get("params")->Option.flatMap(JSON.Decode.object)->Option.getOrThrow
    let requestMeta =
      params->Dict.get("_meta")->Option.flatMap(JSON.Decode.object)->Option.getOrThrow

    t
    ->expect(request->Dict.get("method"))
    ->Expect.toEqual(Some(JSON.Encode.string("session/prompt")))
    t
    ->expect(requestMeta->Dict.get("traits"))
    ->Expect.toEqual(
      Some([JSON.Encode.string("react"), JSON.Encode.string("typescript")]->JSON.Encode.array),
    )
  })
})
