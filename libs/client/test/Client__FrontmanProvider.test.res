open Vitest

module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

describe("FrontmanProvider history parsing", () => {
  test("preserves attachment IDs from replayed image resource URIs", t => {
    let meta = Dict.make()
    meta->Dict.set("user_image", JSON.Encode.bool(true))
    meta->Dict.set("filename", JSON.Encode.string("content.jpeg"))

    let block = ACP.EmbeddedResource({
      resource: {
        _meta: Some(JSON.Encode.object(meta)),
        annotations: None,
        resource: ACP.BlobResourceContents({
          uri: "attachment://att_6avioppil/content.jpeg",
          mimeType: Some("image/jpeg"),
          blob: "abc123",
        }),
      },
      _meta: None,
      annotations: None,
    })

    let (content, _annotations) = Client__FrontmanProvider._parseUserMessageBlocks([block])

    switch content->Array.get(0) {
    | Some(Client__Message.UserContentPart.Image({id, image, mediaType, name})) => {
        t->expect(id)->Expect.toEqual(Some("att_6avioppil"))
        t->expect(image)->Expect.toBe("data:image/jpeg;base64,abc123")
        t->expect(mediaType)->Expect.toEqual(Some("image/jpeg"))
        t->expect(name)->Expect.toEqual(Some("content.jpeg"))
      }
    | _ => JsExn.throw("Expected replayed user image content")
    }
  })
})
