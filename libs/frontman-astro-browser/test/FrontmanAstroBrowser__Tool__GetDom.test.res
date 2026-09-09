open Vitest

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module GetDom = FrontmanAiFrontmanProtocol.FrontmanProtocol__GetDom
module AstroGetDom = FrontmanAstroBrowser__Tool__GetDom

@schema
type result = {structuredContent: AstroGetDom.output}

describe("FrontmanAstroBrowser__Tool__GetDom", _t => {
  testAsync("uses the injected inspector and the same preview for routing", async t => {
    let doc =
      WebAPI.DomGlobal.document.implementation->WebAPI.DOMImplementation.createHTMLDocument(
        ~title="",
      )
    doc.head.innerHTML = "<meta name=\"astro-view-transitions-enabled\">"
    let preview = Some(({doc, win: WebAPI.Window.current}: Tool.previewContext))
    let previewReads = ref(0)
    let inspections = ref(0)
    let inspected: GetDom.output = {
      url: Some("https://preview.test/page"),
      success: true,
      html: Some("<main id=\"page\">Page</main>"),
      nodeCount: Some(1),
      byteSize: Some(27),
      hint: Some("Inspection hint"),
      error: None,
    }
    module T = unpack(
      AstroGetDom.make(
        ~getPreviewDoc=() => {
          previewReads := previewReads.contents + 1
          preview
        },
        ~inspect=(input, context) => {
          inspections := inspections.contents + 1
          t->expect(input.selector)->Expect.toBe("#page")
          t->expect(context)->Expect.toBe(preview)
          inspected
        },
        ~description="Shared DOM inspection",
      )
    )
    let input = S.parseOrThrow(JSON.parseOrThrow("{\"selector\":\"#page\"}"), ~to=T.inputSchema)
    let response = await T.execute(input, ~taskId="task", ~toolCallId="call")
    let json = response->S.decodeOrThrow(~from=Tool.MCP.CallToolResult.schema, ~to=S.json)
    let output = S.parseOrThrow(json, ~to=resultSchema).structuredContent
    t->expect(T.name)->Expect.toBe("get_dom")
    t->expect(previewReads.contents)->Expect.toBe(1)
    t->expect(inspections.contents)->Expect.toBe(1)
    t->expect(output.astro_client_routing)->Expect.toBe(FrontmanAstroBrowser__ClientRouting.Enabled)
    t->expect(output.url)->Expect.toEqual(inspected.url)
    t->expect(output.success)->Expect.toBe(inspected.success)
    t->expect(output.html)->Expect.toEqual(inspected.html)
    t->expect(output.nodeCount)->Expect.toEqual(inspected.nodeCount)
    t->expect(output.byteSize)->Expect.toEqual(inspected.byteSize)
    t->expect(output.hint)->Expect.toEqual(inspected.hint)
    t->expect(output.error)->Expect.toEqual(inspected.error)
  })
})
