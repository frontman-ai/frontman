open Vitest

module Types = Client__State__Types
module ClientTypes = Client__Types

// Helper to create a mock DOM element for testing
// Using a raw JS object that satisfies the minimal interface
let makeMockElement: unit => WebAPI.DOMAPI.element = %raw(`
  function() {
    return { tagName: "DIV" };
  }
`)

describe("Client__State__Types", () => {
  describe("selectedElementToContentBlock", () => {
    test("strips file:// prefix from file path", t => {
      let sourceLocation: ClientTypes.SourceLocation.t = {
        componentName: Some("TestComponent"),
        tagName: "div",
        file: "file:///home/user/project/src/Component.tsx",
        line: 42,
        column: 5,
        parent: None,
        componentProps: None,
      }

      let selectedElement: Types.SelectedElement.t = {
        element: makeMockElement(),
        selector: Some("div.test"),
        screenshot: None,
        sourceLocation: Some(sourceLocation),
      }

      let result = Types.selectedElementToContentBlock(selectedElement)

      // Should have a result
      t->expect(result->Option.isSome)->Expect.toBe(true)

      let contentBlock = result->Option.getOrThrow

      // Extract _meta from the embedded resource
      let embeddedResource = contentBlock.resource->Option.getOrThrow
      let meta = embeddedResource._meta->Option.getOrThrow

      // Get the file from _meta - it should NOT have the file:// prefix
      let fileValue =
        meta
        ->JSON.Decode.object
        ->Option.flatMap(obj => obj->Dict.get("file"))
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOrThrow

      // The file should be an absolute path, not a file:// URI
      t->expect(fileValue)->Expect.toBe("/home/user/project/src/Component.tsx")
    })

    test("preserves absolute paths without file:// prefix", t => {
      let sourceLocation: ClientTypes.SourceLocation.t = {
        componentName: Some("TestComponent"),
        tagName: "div",
        file: "file:///home/user/project/src/Component.tsx",
        line: 42,
        column: 5,
        parent: None,
        componentProps: None,
      }

      let selectedElement: Types.SelectedElement.t = {
        element: makeMockElement(),
        selector: Some("div.test"),
        screenshot: None,
        sourceLocation: Some(sourceLocation),
      }

      let result = Types.selectedElementToContentBlock(selectedElement)
      let contentBlock = result->Option.getOrThrow
      let embeddedResource = contentBlock.resource->Option.getOrThrow
      let meta = embeddedResource._meta->Option.getOrThrow

      let fileValue =
        meta
        ->JSON.Decode.object
        ->Option.flatMap(obj => obj->Dict.get("file"))
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOrThrow

      // Already an absolute path, should be preserved
      t->expect(fileValue)->Expect.toBe("/home/user/project/src/Component.tsx")
    })

    test("handles Windows-style file:// URIs", t => {
      // Windows file URIs have format file:///C:/path/to/file
      let sourceLocation: ClientTypes.SourceLocation.t = {
        componentName: Some("TestComponent"),
        tagName: "div",
        file: "file:///C:/Users/dev/project/src/Component.tsx",
        line: 10,
        column: 1,
        parent: None,
        componentProps: None,
      }

      let selectedElement: Types.SelectedElement.t = {
        element: makeMockElement(),
        selector: Some("div.test"),
        screenshot: None,
        sourceLocation: Some(sourceLocation),
      }

      let result = Types.selectedElementToContentBlock(selectedElement)
      let contentBlock = result->Option.getOrThrow
      let embeddedResource = contentBlock.resource->Option.getOrThrow
      let meta = embeddedResource._meta->Option.getOrThrow

      let fileValue =
        meta
        ->JSON.Decode.object
        ->Option.flatMap(obj => obj->Dict.get("file"))
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOrThrow

      // Windows paths should have the drive letter preserved
      t->expect(fileValue)->Expect.toBe("C:/Users/dev/project/src/Component.tsx")
    })

    test("uri in text resource also strips file:// prefix", t => {
      let sourceLocation: ClientTypes.SourceLocation.t = {
        componentName: Some("TestComponent"),
        tagName: "div",
        file: "file:///home/user/project/src/Component.tsx",
        line: 42,
        column: 5,
        parent: None,
        componentProps: None,
      }

      let selectedElement: Types.SelectedElement.t = {
        element: makeMockElement(),
        selector: Some("div.test"),
        screenshot: None,
        sourceLocation: Some(sourceLocation),
      }

      let result = Types.selectedElementToContentBlock(selectedElement)
      let contentBlock = result->Option.getOrThrow
      let embeddedResource = contentBlock.resource->Option.getOrThrow

      // Extract the text resource to check the URI
      switch embeddedResource.resource {
      | TextResourceContents(textResource) =>
        // The URI should use the cleaned file path
        t
        ->expect(textResource.uri)
        ->Expect.toBe("file:///home/user/project/src/Component.tsx:42:5")
      | _ => JsExn.throw("Expected TextResourceContents")
      }
    })
  })
})
