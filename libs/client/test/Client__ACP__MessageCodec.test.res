open Vitest

module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock
module Codec = Client__ACP__MessageCodec
module MessageAnnotation = Client__Message.MessageAnnotation

let resource = (~meta, resource) => ContentBlock.EmbeddedResource({
  _meta: Some(JSON.parseOrThrow(meta)->JSON.Decode.object->Option.getOrThrow),
  annotations: None,
  resource,
})

test("parses flat annotation, screenshot, and image resources", t => {
  let blocks = [
    ContentBlock.TextContent({text: "Look", _meta: None, annotations: None}),
    resource(
      ~meta=`{"annotation":true,"annotation_index":0,"annotation_id":"annotation-1","tag_name":"button","selector":"#submit","element_context":"context"}`,
      ContentBlock.TextResourceContents({
        uri: "annotation://annotation-1",
        mimeType: None,
        text: "",
        _meta: None,
      }),
    ),
    resource(
      ~meta=`{"annotation_screenshot":true,"annotation_index":0,"annotation_id":"annotation-1"}`,
      ContentBlock.BlobResourceContents({
        uri: "annotation://annotation-1/screenshot",
        mimeType: Some("image/png"),
        blob: "c2NyZWVuc2hvdA==",
        _meta: None,
      }),
    ),
    resource(
      ~meta=`{"user_image":true,"filename":"photo.png"}`,
      ContentBlock.BlobResourceContents({
        uri: "attachment://photo.png",
        mimeType: Some("image/png"),
        blob: "aW1hZ2U=",
        _meta: None,
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
      t->expect(annotation.elementContext)->Expect.toEqual(Ok(Some("context")))
    }
  | _ => t->expect("parsed message")->Expect.toBe("missing")
  }
})

test("round-trips annotation context, ancestry, screenshot, and source errors", t => {
  let sourceLocation: MessageAnnotation.sourceLocation = {
    componentName: Some("Button"),
    tagName: "button",
    file: "file:///home/user/src/Button.tsx",
    line: 42,
    column: 5,
    componentProps: None,
    parent: Some({
      componentName: Some("Form"),
      tagName: "form",
      file: "src/Form.tsx",
      line: 10,
      column: 3,
      componentProps: None,
      parent: Some({
        componentName: Some("Page"),
        tagName: "main",
        file: "src/Page.tsx",
        line: 2,
        column: 1,
        componentProps: None,
        parent: None,
      }),
    }),
  }
  let successful: MessageAnnotation.t = {
    id: "annotation-success",
    selector: Ok(Some("#submit")),
    elementContext: Ok(Some("button context")),
    tagName: "button",
    cssClasses: Some("primary"),
    comment: Some("Fix this"),
    screenshot: Ok(Some("data:image/jpeg;base64,abc123")),
    sourceLocation: Ok(Some(sourceLocation)),
    boundingBox: Some({x: 10.0, y: 20.0, width: 100.0, height: 50.0}),
    nearbyText: Some("Submit"),
    elementorContext: None,
  }
  let failed: MessageAnnotation.t = {
    id: "annotation-error",
    selector: Ok(Some("#missing")),
    elementContext: Ok(None),
    tagName: "div",
    cssClasses: None,
    comment: None,
    screenshot: Ok(None),
    sourceLocation: Error("Source map position could not be resolved"),
    boundingBox: None,
    nearbyText: None,
    elementorContext: None,
  }
  let blocks = Client__Task__Types.messageAnnotationsToContentBlocks([successful, failed])

  switch Codec.parseUserMessageBlocks(blocks) {
  | (_, [decodedSuccessful, decodedFailed]) => {
      t->expect(decodedSuccessful.elementContext)->Expect.toEqual(successful.elementContext)
      t->expect(decodedSuccessful.screenshot)->Expect.toEqual(successful.screenshot)
      switch decodedSuccessful.sourceLocation {
      | Ok(Some(location)) => {
          t->expect(location.file)->Expect.toBe("/home/user/src/Button.tsx")
          switch location.parent {
          | Some(parent) => {
              t->expect(parent.file)->Expect.toBe("src/Form.tsx")
              t->expect(parent.componentName)->Expect.toEqual(Some("Form"))
              t
              ->expect(parent.parent->Option.map(parent => parent.file))
              ->Expect.toEqual(Some("src/Page.tsx"))
            }
          | None => t->expect("source ancestry")->Expect.toBe("missing")
          }
        }
      | _ => t->expect("source location")->Expect.toBe("missing")
      }
      t
      ->expect(decodedFailed.sourceLocation)
      ->Expect.toEqual(Error("Source map position could not be resolved"))
    }
  | _ => t->expect("parsed annotation")->Expect.toBe("missing")
  }
})

test("rejects annotation metadata with source coordinates and an error", t => {
  let blocks = [
    resource(
      ~meta=`{"annotation":true,"annotation_index":0,"annotation_id":"annotation-1","tag_name":"button","file":"/src/Form.tsx","line":42,"column":5,"source_location_error":"Source map position could not be resolved"}`,
      ContentBlock.TextResourceContents({
        uri: "annotation://annotation-1",
        mimeType: None,
        text: "",
        _meta: None,
      }),
    ),
  ]

  Expect.toThrow(t->expect(() => Codec.parseUserMessageBlocks(blocks)->ignore))
})
