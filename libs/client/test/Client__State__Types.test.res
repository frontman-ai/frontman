open Vitest

module Types = Client__State__Types
module ContentBlock = Client__Task__Types.ContentBlock
module MessageAnnotation = Client__Message.MessageAnnotation

let getMeta = (block: ContentBlock.t): JSON.t =>
  switch block {
  | EmbeddedResource({_meta}) => _meta->Option.getOrThrow
  | TextContent(_) | ImageContent(_) | AudioContent(_) | ResourceLink(_) =>
    failwith("Expected embedded resource")
  }

let getResource = (block: ContentBlock.t): ContentBlock.embeddedResourceResource =>
  switch block {
  | EmbeddedResource({resource}) => resource
  | TextContent(_) | ImageContent(_) | AudioContent(_) | ResourceLink(_) =>
    failwith("Expected embedded resource")
  }

let getString = (json: JSON.t, field: string): string =>
  json
  ->JSON.Decode.object
  ->Option.getOrThrow
  ->Dict.get(field)
  ->Option.getOrThrow
  ->JSON.Decode.string
  ->Option.getOrThrow

describe("messageAnnotationsToContentBlocks", () => {
  test("uses Elementor context and appends its edit hint", t => {
    let annotation: MessageAnnotation.t = {
      id: "annotation-1",
      selector: Ok(Some(".elementor-element-abc12345")),
      elementContext: Ok(None),
      tagName: "h2",
      cssClasses: Some("elementor-heading-title"),
      comment: Some("remove"),
      screenshot: Ok(None),
      sourceLocation: Ok(None),
      boundingBox: None,
      nearbyText: Some("Hero title"),
      elementorContext: Some({
        postId: Some(42),
        elementId: "abc12345",
        elementType: Some("widget"),
        widgetType: Some("heading"),
        documentType: Some("wp-page"),
        editHint: "Use Elementor tools",
      }),
    }

    let block = Types.messageAnnotationsToContentBlocks([annotation])->Array.getUnsafe(0)
    let nearbyText = getMeta(block)->getString("nearby_text")

    t->expect(nearbyText->String.includes("Hero title"))->Expect.toBe(true)
    t->expect(nearbyText->String.includes("post_id=42"))->Expect.toBe(true)
    t->expect(nearbyText->String.includes("element_id=abc12345"))->Expect.toBe(true)
    switch getResource(block) {
    | TextResourceContents(resource) =>
      t->expect(resource.uri)->Expect.toBe("elementor://post/42/element/abc12345")
    | _ => failwith("Expected text resource")
    }
  })
})
