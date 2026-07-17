open Vitest

module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Codec = Client__ACP__MessageCodec

let resource = (~meta, resource) => ACP.EmbeddedResource({
  _meta: Some(JSON.parseOrThrow(meta)),
  annotations: None,
  resource,
})

test("parses flat annotation, screenshot, and image resources", t => {
  let blocks = [
    ACP.TextContent({text: "Look", _meta: None, annotations: None}),
    resource(
      ~meta=`{"annotation":true,"annotation_index":0,"annotation_id":"annotation-1","tag_name":"button","selector":"#submit"}`,
      ACP.TextResourceContents({uri: "annotation://annotation-1", mimeType: None, text: ""}),
    ),
    resource(
      ~meta=`{"annotation_screenshot":true,"annotation_index":0,"annotation_id":"annotation-1"}`,
      ACP.BlobResourceContents({
        uri: "annotation://annotation-1/screenshot",
        mimeType: Some("image/png"),
        blob: "c2NyZWVuc2hvdA==",
      }),
    ),
    resource(
      ~meta=`{"user_image":true,"filename":"photo.png"}`,
      ACP.BlobResourceContents({
        uri: "attachment://photo.png",
        mimeType: Some("image/png"),
        blob: "aW1hZ2U=",
      }),
    ),
  ]

  switch Codec.parseUserMessageBlocks(blocks) {
  | (
      [Client__Message.UserContentPart.Text({text}), Client__Message.UserContentPart.Image({name})],
      [annotation],
    ) => {
      t->expect(text)->Expect.toBe("Look")
      t->expect(name)->Expect.toEqual(Some("photo.png"))
      t
      ->expect(annotation.screenshot)
      ->Expect.toEqual(Ok(Some("data:image/png;base64,c2NyZWVuc2hvdA==")))
    }
  | _ => t->expect("parsed message")->Expect.toBe("missing")
  }
})
