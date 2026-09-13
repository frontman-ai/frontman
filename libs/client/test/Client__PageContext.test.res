open Vitest

module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview
module TaskTypes = Client__Task__Types

let page: Preview.pageContext = {
  url: "https://preview.example/actual-page",
  title: "Child title",
  viewportWidth: 844,
  viewportHeight: 390,
  devicePixelRatio: 2.0,
  scrollY: 72,
  colorScheme: #dark,
}

let metadata = block =>
  switch block {
  | TaskTypes.ContentBlock.EmbeddedResource({_meta: Some(meta)}) =>
    S.parseOrThrow(meta, ~to=TaskTypes.pageMetadataSchema)
  | _ => JsError.throwWithMessage("Expected page metadata")
  }

describe("pure page context formatting", _ => {
  test("preserves child metadata and parent device emulation", t => {
    let block = TaskTypes.currentPageToContentBlock(
      page,
      ~deviceMode=DevicePreset({
        name: "Test phone",
        category: "Phones",
        width: 390,
        height: 844,
        dpr: 2.0,
      }),
      ~orientation=Landscape,
    )
    let meta = metadata(block)
    t->expect(meta.url)->Expect.toBe(page.url)
    t->expect(meta.title)->Expect.toEqual(Some("Child title"))
    t->expect(meta.scroll_y)->Expect.toBe(72)
    t->expect(meta.color_scheme)->Expect.toEqual(Some(#dark))
    t->expect(meta.viewport_width)->Expect.toBe(844)
    t
    ->expect(meta.device_emulation)
    ->Expect.toEqual(
      Some({
        active: true,
        width: Some(844),
        height: Some(390),
        name: "Test phone",
        orientation: "landscape",
        dpr: Some(2.0),
      }),
    )
    switch block {
    | EmbeddedResource({resource: TextResourceContents({uri, text})}) =>
      t->expect(uri)->Expect.toBe(`page://${page.url}`)
      t->expect(text->String.includes("Title: Child title"))->Expect.toBe(true)
    | _ => JsError.throwWithMessage("Expected page text resource")
    }
  })

  test("omits unsupported color scheme, empty title, and inactive emulation", t => {
    let meta =
      TaskTypes.currentPageToContentBlock(
        {...page, title: "", colorScheme: #unsupported},
        ~deviceMode=Responsive,
        ~orientation=Portrait,
      )->metadata
    t->expect(meta.title)->Expect.toEqual(None)
    t->expect(meta.color_scheme)->Expect.toEqual(None)
    t->expect(meta.device_emulation)->Expect.toEqual(None)
  })
})
