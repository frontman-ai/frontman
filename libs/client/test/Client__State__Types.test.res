open Vitest

module Types = Client__State__Types
module ClientTypes = Client__Types
module Annotation = Client__Annotation__Types
module ACPTypes = Client__Task__Types.ACPTypes

// Helper to create a mock DOM element for testing
// Using a raw JS object that satisfies the minimal interface
let makeMockElement: unit => WebAPI.DOMAPI.element = %raw(`
  function() {
    return { tagName: "DIV" };
  }
`)

// Helper to create an annotation with source location for testing
let makeTestAnnotation = (
  ~file: string,
  ~line: int,
  ~column: int,
  ~componentName: option<string>=?,
  ~tagName: string="div",
  ~selector: option<string>=?,
  ~screenshot: option<string>=?,
  ~cssClasses: option<string>=?,
  ~nearbyText: option<string>=?,
  ~boundingBox: option<Annotation.boundingBox>=?,
): Annotation.t => {
  id: "test-annotation-id",
  element: makeMockElement(),
  comment: None,
  selector: Ok(selector),
  screenshot: Ok(screenshot),
  sourceLocation: Ok(Some({
    componentName,
    tagName,
    file,
    line,
    column,
    parent: None,
    componentProps: None,
  })),
  tagName,
  cssClasses,
  boundingBox,
  nearbyText,
  position: {xPercent: 50.0, yAbsolute: 100.0},
  timestamp: 0.0,
  enrichmentStatus: Enriched,
}

// Helper to extract _meta from an EmbeddedResource content block
let getMeta = (block: ACPTypes.contentBlock): JSON.t => {
  switch block {
  | EmbeddedResource({resource}) => resource._meta->Option.getOrThrow
  | TextContent(_) | ImageContent(_) | AudioContent(_) | ResourceLink(_) =>
    failwith("getMeta: expected EmbeddedResource content block")
  }
}

// Helper to extract the embeddedResource from an EmbeddedResource content block
let getEmbeddedResource = (block: ACPTypes.contentBlock): ACPTypes.embeddedResource => {
  switch block {
  | EmbeddedResource({resource}) => resource
  | TextContent(_) | ImageContent(_) | AudioContent(_) | ResourceLink(_) =>
    failwith("getEmbeddedResource: expected EmbeddedResource content block")
  }
}

// Helper to get a string field from _meta JSON
let getMetaString = (meta: JSON.t, field: string): string =>
  meta
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get(field))
  ->Option.flatMap(JSON.Decode.string)
  ->Option.getOrThrow

// Helper to get an int field from _meta JSON
let getMetaFloat = (meta: JSON.t, field: string): float =>
  meta
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get(field))
  ->Option.flatMap(JSON.Decode.float)
  ->Option.getOrThrow

// Helper to get a bool field from _meta JSON
let getMetaBool = (meta: JSON.t, field: string): bool =>
  meta
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get(field))
  ->Option.flatMap(JSON.Decode.bool)
  ->Option.getOrThrow

// Helper to get an object field from _meta JSON
let getMetaObject = (meta: JSON.t, field: string): Dict.t<JSON.t> =>
  meta
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get(field))
  ->Option.flatMap(JSON.Decode.object)
  ->Option.getOrThrow

// Helper to create a New task with custom annotations
let makeNewTaskWithAnnotations = (annotations: array<Annotation.t>): Types.Task.t => {
  switch Types.Task.makeNew(~previewUrl="http://localhost:3000") {
  | Types.Task.New(data) => Types.Task.New({...data, annotations})
  | other => other
  }
}

describe("Client__State__Types", () => {
  describe("annotationToContentBlocks", () => {
    test("strips file:// prefix from file path in _meta", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///home/user/project/src/Component.tsx",
        ~line=42,
        ~column=5,
        ~componentName="TestComponent",
        ~selector="div.test",
      )

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)

      // Should produce at least 1 block (resource with annotation metadata)
      t->expect(blocks->Array.length >= 1)->Expect.toBe(true)

      let meta = getMeta(blocks->Array.getUnsafe(0))

      // The file should be an absolute path, not a file:// URI
      t->expect(getMetaString(meta, "file"))->Expect.toBe("/home/user/project/src/Component.tsx")
    })

    test("annotation _meta contains all required fields", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///home/user/project/src/Component.tsx",
        ~line=42,
        ~column=5,
        ~componentName="TestComponent",
        ~selector="div.test",
      )

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)
      let meta = getMeta(blocks->Array.getUnsafe(0))

      t->expect(getMetaBool(meta, "annotation"))->Expect.toBe(true)
      t->expect(getMetaFloat(meta, "annotation_index"))->Expect.toBe(0.0)
      t->expect(getMetaString(meta, "annotation_id"))->Expect.toBe("test-annotation-id")
      t->expect(getMetaString(meta, "tag_name"))->Expect.toBe("div")
      t->expect(getMetaString(meta, "component_name"))->Expect.toBe("TestComponent")
      t->expect(getMetaFloat(meta, "line"))->Expect.toBe(42.0)
      t->expect(getMetaFloat(meta, "column"))->Expect.toBe(5.0)
    })

    test("handles Windows-style file:// URIs", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///C:/Users/dev/project/src/Component.tsx",
        ~line=10,
        ~column=1,
        ~componentName="TestComponent",
        ~selector="div.test",
      )

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)
      let meta = getMeta(blocks->Array.getUnsafe(0))

      // Windows paths should have the drive letter preserved
      t->expect(getMetaString(meta, "file"))->Expect.toBe("C:/Users/dev/project/src/Component.tsx")
    })

    test("uri in text resource uses cleaned file path", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///home/user/project/src/Component.tsx",
        ~line=42,
        ~column=5,
        ~componentName="TestComponent",
        ~selector="div.test",
      )

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)
      let block = blocks->Array.getUnsafe(0)
      let embeddedResource = getEmbeddedResource(block)

      switch embeddedResource.resource {
      | TextResourceContents(textResource) =>
        // The URI should use file:// with cleaned path and line:col
        t
        ->expect(textResource.uri)
        ->Expect.toBe("file:///home/user/project/src/Component.tsx:42:5")
      | _ => JsExn.throw("Expected TextResourceContents")
      }
    })

    test("includes screenshot blob when annotation has screenshot", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///home/user/project/src/Component.tsx",
        ~line=42,
        ~column=5,
        ~screenshot="data:image/jpeg;base64,/9j/4AAQ",
      )

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)

      // Should produce 2 blocks: resource + screenshot
      t->expect(blocks->Array.length)->Expect.toBe(2)

      // Second block should be screenshot blob
      let screenshotBlock = blocks->Array.getUnsafe(1)
      let screenshotResource = getEmbeddedResource(screenshotBlock)
      let screenshotMeta = screenshotResource._meta->Option.getOrThrow

      t->expect(getMetaBool(screenshotMeta, "annotation_screenshot"))->Expect.toBe(true)
      t->expect(getMetaString(screenshotMeta, "annotation_id"))->Expect.toBe("test-annotation-id")

      switch screenshotResource.resource {
      | BlobResourceContents(blobResource) =>
        t->expect(blobResource.mimeType)->Expect.toEqual(Some("image/jpeg"))
        t->expect(blobResource.blob)->Expect.toBe("/9j/4AAQ")
      | _ => JsExn.throw("Expected BlobResourceContents")
      }
    })

    test("produces 1 block when annotation has no screenshot", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///home/user/project/src/Component.tsx",
        ~line=42,
        ~column=5,
      )

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)
      t->expect(blocks->Array.length)->Expect.toBe(1)
    })

    test("fallback to selector when no source location", t => {
      let annotation: Annotation.t = {
        id: "test-no-source",
        element: makeMockElement(),
        comment: None,
        selector: Ok(Some("div.my-class")),
        screenshot: Ok(None),
        sourceLocation: Ok(None),
        tagName: "div",
        cssClasses: None,
        boundingBox: None,
        nearbyText: None,
        position: {xPercent: 50.0, yAbsolute: 100.0},
        timestamp: 0.0,
        enrichmentStatus: Enriched,
      }

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)
      let block = blocks->Array.getUnsafe(0)
      let embeddedResource = getEmbeddedResource(block)

      switch embeddedResource.resource {
      | TextResourceContents(textResource) =>
        t->expect(textResource.uri)->Expect.toBe("selector://div.my-class")
      | _ => JsExn.throw("Expected TextResourceContents")
      }
    })

    test("includes css_classes and nearby_text in _meta when present", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///home/user/project/src/Component.tsx",
        ~line=42,
        ~column=5,
        ~cssClasses="btn btn-primary",
        ~nearbyText="Click me",
      )

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)
      let meta = getMeta(blocks->Array.getUnsafe(0))

      t->expect(getMetaString(meta, "css_classes"))->Expect.toBe("btn btn-primary")
      t->expect(getMetaString(meta, "nearby_text"))->Expect.toBe("Click me")
    })

    test("includes bounding_box in _meta when present", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///home/user/project/src/Component.tsx",
        ~line=42,
        ~column=5,
        ~boundingBox={x: 10.5, y: 20.0, width: 200.0, height: 50.0},
      )

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)
      let meta = getMeta(blocks->Array.getUnsafe(0))

      let bb = getMetaObject(meta, "bounding_box")
      t
      ->expect(bb->Dict.get("x")->Option.flatMap(JSON.Decode.float)->Option.getOrThrow)
      ->Expect.toBe(10.5)
      t
      ->expect(bb->Dict.get("y")->Option.flatMap(JSON.Decode.float)->Option.getOrThrow)
      ->Expect.toBe(20.0)
      t
      ->expect(bb->Dict.get("width")->Option.flatMap(JSON.Decode.float)->Option.getOrThrow)
      ->Expect.toBe(200.0)
      t
      ->expect(bb->Dict.get("height")->Option.flatMap(JSON.Decode.float)->Option.getOrThrow)
      ->Expect.toBe(50.0)
    })

    test("omits bounding_box from _meta when not present", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///home/user/project/src/Component.tsx",
        ~line=42,
        ~column=5,
      )

      let blocks = Types.annotationToContentBlocks(annotation, ~index=0)
      let meta = getMeta(blocks->Array.getUnsafe(0))

      let metaObj = meta->JSON.Decode.object->Option.getOrThrow
      t->expect(metaObj->Dict.get("bounding_box")->Option.isNone)->Expect.toBe(true)
    })
  })

  describe("taskToContentBlocks", () => {
    test("returns empty array for Unloaded task", t => {
      let task = Types.Task.Unloaded({
        id: "test",
        title: "test",
        createdAt: 0.0,
        updatedAt: 0.0,
      })

      let blocks = Types.taskToContentBlocks(task)
      t->expect(blocks->Array.length)->Expect.toBe(0)
    })

    test("returns annotation blocks for New task with annotations", t => {
      let annotation = makeTestAnnotation(
        ~file="file:///home/user/project/src/Component.tsx",
        ~line=42,
        ~column=5,
        ~screenshot="data:image/jpeg;base64,/9j/4AAQ",
      )

      let task = makeNewTaskWithAnnotations([annotation])

      let blocks = Types.taskToContentBlocks(task)
      // 1 current_page block + 1 annotation with screenshot (2 blocks) = 3 blocks
      t->expect(blocks->Array.length)->Expect.toBe(3)
    })

    test("returns blocks for multiple annotations", t => {
      let ann1 = makeTestAnnotation(
        ~file="file:///home/user/project/src/A.tsx",
        ~line=1,
        ~column=1,
      )
      let ann2 = makeTestAnnotation(
        ~file="file:///home/user/project/src/B.tsx",
        ~line=2,
        ~column=2,
        ~screenshot="data:image/png;base64,iVBORw0K",
      )

      let task = makeNewTaskWithAnnotations([ann1, ann2])

      let blocks = Types.taskToContentBlocks(task)
      // 1 current_page block + ann1: 1 block (no screenshot) + ann2: 2 blocks (with screenshot) = 4 total
      t->expect(blocks->Array.length)->Expect.toBe(4)

      // blocks[0] is current_page; annotation blocks start at index 1
      // Verify first annotation has index 0
      let meta0 = getMeta(blocks->Array.getUnsafe(1))
      t->expect(getMetaFloat(meta0, "annotation_index"))->Expect.toBe(0.0)

      // Verify second annotation has index 1
      let meta1 = getMeta(blocks->Array.getUnsafe(2))
      t->expect(getMetaFloat(meta1, "annotation_index"))->Expect.toBe(1.0)
    })
  })
})

// ============================================================================
// MessageAnnotation Tests (Issue #466)
// ============================================================================

module MessageAnnotation = Client__Message.MessageAnnotation

describe("MessageAnnotation.fromAnnotation", () => {
  test("snapshots all annotation fields", t => {
    let annotation = makeTestAnnotation(
      ~file="file:///home/user/src/Button.tsx",
      ~line=42,
      ~column=5,
      ~componentName="Button",
      ~tagName="button",
      ~selector=".btn-submit",
      ~cssClasses="btn-submit primary",
      ~nearbyText="Submit",
      ~boundingBox={x: 10.0, y: 20.0, width: 100.0, height: 50.0},
    )
    // Add a comment and screenshot to the annotation
    let annotation = {...annotation, comment: Some("This is broken"), screenshot: Ok(Some("data:image/jpeg;base64,abc123"))}

    let snapshot = MessageAnnotation.fromAnnotation(annotation)

    t->expect(snapshot.id)->Expect.toBe("test-annotation-id")
    t->expect(snapshot.selector)->Expect.toEqual(Ok(Some(".btn-submit")))
    t->expect(snapshot.tagName)->Expect.toBe("button")
    t->expect(snapshot.cssClasses)->Expect.toEqual(Some("btn-submit primary"))
    t->expect(snapshot.comment)->Expect.toEqual(Some("This is broken"))
    t->expect(snapshot.screenshot)->Expect.toEqual(Ok(Some("data:image/jpeg;base64,abc123")))
    t->expect(snapshot.nearbyText)->Expect.toEqual(Some("Submit"))
  })

  test("converts source location correctly", t => {
    let annotation = makeTestAnnotation(
      ~file="file:///home/user/src/Header.tsx",
      ~line=10,
      ~column=3,
      ~componentName="Header",
      ~tagName="div",
    )

    let snapshot = MessageAnnotation.fromAnnotation(annotation)

    switch snapshot.sourceLocation {
    | Ok(Some(loc)) =>
      t->expect(loc.file)->Expect.toBe("file:///home/user/src/Header.tsx")
      t->expect(loc.line)->Expect.toBe(10)
      t->expect(loc.column)->Expect.toBe(3)
      t->expect(loc.componentName)->Expect.toEqual(Some("Header"))
    | _ => t->expect("sourceLocation")->Expect.toBe("should be Ok(Some(...))")
    }
  })

  test("converts bounding box correctly", t => {
    let annotation = makeTestAnnotation(
      ~file="src/App.tsx",
      ~line=1,
      ~column=1,
      ~boundingBox={x: 5.5, y: 10.5, width: 200.0, height: 100.0},
    )

    let snapshot = MessageAnnotation.fromAnnotation(annotation)

    switch snapshot.boundingBox {
    | Some(bb) =>
      t->expect(bb.x)->Expect.toBe(5.5)
      t->expect(bb.y)->Expect.toBe(10.5)
      t->expect(bb.width)->Expect.toBe(200.0)
      t->expect(bb.height)->Expect.toBe(100.0)
    | None => t->expect("boundingBox")->Expect.toBe("should be Some")
    }
  })

  test("handles None fields gracefully", t => {
    let annotation: Annotation.t = {
      id: "test-minimal",
      element: makeMockElement(),
      comment: None,
      selector: Ok(None),
      screenshot: Ok(None),
      sourceLocation: Ok(None),
      tagName: "span",
      cssClasses: None,
      boundingBox: None,
      nearbyText: None,
      position: {xPercent: 0.0, yAbsolute: 0.0},
      timestamp: 0.0,
      enrichmentStatus: Enriched,
    }

    let snapshot = MessageAnnotation.fromAnnotation(annotation)

    t->expect(snapshot.id)->Expect.toBe("test-minimal")
    t->expect(snapshot.tagName)->Expect.toBe("span")
    t->expect(snapshot.selector)->Expect.toEqual(Ok(None))
    t->expect(snapshot.comment)->Expect.toEqual(None)
    t->expect(snapshot.screenshot)->Expect.toEqual(Ok(None))
    t->expect(snapshot.sourceLocation)->Expect.toEqual(Ok(None))
    t->expect(snapshot.boundingBox)->Expect.toEqual(None)
    t->expect(snapshot.nearbyText)->Expect.toEqual(None)
  })
})

describe("messageAnnotationsToContentBlocks", () => {
  test("produces resource blocks from MessageAnnotation array", t => {
    let annotations: array<MessageAnnotation.t> = [
      {
        id: "ann-1",
        selector: Ok(Some(".submit")),
        tagName: "button",
        cssClasses: Some("submit"),
        comment: Some("Fix this"),
        screenshot: Ok(None),
        sourceLocation: Ok(Some({
          componentName: Some("Form"),
          tagName: "button",
          file: "/src/Form.tsx",
          line: 42,
          column: 5,
          parent: None,
          componentProps: None,
        })),
        boundingBox: None,
        nearbyText: Some("Submit"),
      },
    ]

    let blocks = Types.messageAnnotationsToContentBlocks(annotations)

    // 1 annotation without screenshot = 1 block
    t->expect(blocks->Array.length)->Expect.toBe(1)

    let meta = getMeta(blocks->Array.getUnsafe(0))
    t->expect(getMetaBool(meta, "annotation"))->Expect.toBe(true)
    t->expect(getMetaFloat(meta, "annotation_index"))->Expect.toBe(0.0)
    t->expect(getMetaString(meta, "annotation_id"))->Expect.toBe("ann-1")
    t->expect(getMetaString(meta, "tag_name"))->Expect.toBe("button")
    t->expect(getMetaString(meta, "comment"))->Expect.toBe("Fix this")
  })

  test("produces screenshot blocks when screenshot is present", t => {
    let annotations: array<MessageAnnotation.t> = [
      {
        id: "ann-1",
        selector: Ok(None),
        tagName: "div",
        cssClasses: None,
        comment: None,
        screenshot: Ok(Some("data:image/jpeg;base64,abc123")),
        sourceLocation: Ok(None),
        boundingBox: None,
        nearbyText: None,
      },
    ]

    let blocks = Types.messageAnnotationsToContentBlocks(annotations)

    // 1 annotation with screenshot = 2 blocks
    t->expect(blocks->Array.length)->Expect.toBe(2)
  })

  test("empty annotations array produces no blocks", t => {
    let blocks = Types.messageAnnotationsToContentBlocks([])
    t->expect(blocks->Array.length)->Expect.toBe(0)
  })
})
