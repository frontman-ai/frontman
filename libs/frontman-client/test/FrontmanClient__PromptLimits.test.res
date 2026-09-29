open Vitest
module Protocol = FrontmanClient__ACP__Protocol
module Client = FrontmanClient__ACP__Client
module Block = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock

let image = (blob, ~mimeType="image/png") => Block.EmbeddedResource({
  resource: BlobResourceContents({
    uri: "attachment://fixture/image",
    mimeType: Some(mimeType),
    blob,
  }),
  _meta: None,
  annotations: None,
})
let validate = blocks =>
  Protocol.validatePrompt(~text="Describe this", ~additionalBlocks=blocks, ~_meta=None)

describe("bounded prompt submission", () => {
  test("counts aggregate base64, metadata, Unicode and JSON overhead", t => {
    t->expect(validate([image("AAAA")]))->Expect.toEqual(Ok())
    t
    ->expect(validate([image("A"->String.repeat(14_000_000))]))
    ->Expect.toEqual(Error(Protocol.promptSizeError))
    let individuallyValid = image("A"->String.repeat(4_000_000))
    t->expect(validate([individuallyValid]))->Expect.toEqual(Ok())
    t
    ->expect(validate([individuallyValid, individuallyValid]))
    ->Expect.toEqual(Error(Protocol.promptSizeError))
    t
    ->expect(
      Protocol.validatePrompt(
        ~text="😀"->String.repeat(2_000_000),
        ~additionalBlocks=[],
        ~_meta=None,
      ),
    )
    ->Expect.toEqual(Error(Protocol.promptSizeError))
    t
    ->expect(
      Protocol.validatePrompt(
        ~text="ok",
        ~additionalBlocks=[],
        ~_meta=Some(JSON.Encode.string("A"->String.repeat(8_000_000))),
      ),
    )
    ->Expect.toEqual(Error(Protocol.promptSizeError))
  })

  test("accepts the byte boundary and rejects one byte above it", t => {
    t
    ->expect(
      Protocol.validateMessageSize(
        JSON.Encode.string("A"->String.repeat(Protocol.maxMessageBytes - 2)),
      ),
    )
    ->Expect.toEqual(Ok())
    t
    ->expect(
      Protocol.validateMessageSize(
        JSON.Encode.string("A"->String.repeat(Protocol.maxMessageBytes - 1)),
      ),
    )
    ->Expect.toEqual(Error(Protocol.promptSizeError))
  })

  test("rejects documents including tagged text resources but preserves context resources", t => {
    ["application/pdf", "text/plain", "application/octet-stream"]->Array.forEach(
      mimeType =>
        t
        ->expect(validate([image("AAAA", ~mimeType)]))
        ->Expect.toEqual(Error(Protocol.unsupportedAttachmentError)),
    )
    let resource = Block.TextResourceContents({
      uri: "attachment://fixture/document",
      mimeType: Some("application/pdf"),
      text: "document",
    })
    t
    ->expect(
      validate([
        Block.EmbeddedResource({
          resource,
          _meta: Some(JSON.parseOrThrow(`{"user_image":true}`)),
          annotations: None,
        }),
      ]),
    )
    ->Expect.toEqual(Error(Protocol.unsupportedAttachmentError))
    t
    ->expect(validate([Block.EmbeddedResource({resource, _meta: None, annotations: None})]))
    ->Expect.toEqual(Ok())
  })

  testAsync(
    "rejects repeated oversized requests before push, pending registration or timers",
    async t => {
      let channel = %raw(`({topic: "task:fixture", push() { throw new Error("must not push"); }})`)
      let state = ref(Client.initialState)
      for _ in 1 to 2 {
        let result = await Protocol.sendRequest(
          ~channel,
          ~state,
          ~method=#"session/prompt",
          ~params=Some(JSON.Encode.string("😀"->String.repeat(2_000_000))),
          ~parseResult=_ => Ok(),
        )
        t
        ->expect(result)
        ->Expect.toEqual(Error(Client.requestErrorFromMessage(Protocol.promptSizeError)))
        t->expect(state.contents)->Expect.toEqual(Client.initialState)
      }
    },
  )
})
