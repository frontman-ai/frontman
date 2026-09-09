open Vitest

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module GetDom = FrontmanAiFrontmanProtocol.FrontmanProtocol__GetDom
module AstroGetDom = FrontmanAstroBrowser__Tool__GetDom

@schema
type result = {structuredContent: AstroGetDom.output}

@schema
type errorResponse = {isError: bool}

describe("FrontmanAstroBrowser__Tool__GetDom", _t => {
  testAsync("rejects unavailable previews before calling the inspector", async t => {
    module T = unpack(
      AstroGetDom.make(
        ~getPreviewDoc=() => None,
        ~inspect=(_, _) => JsExn.throw("Inspector must not run without a preview"),
        ~description="Shared DOM inspection",
      )
    )
    let input = S.parseOrThrow(JSON.parseOrThrow("{\"selector\":\"#page\"}"), ~to=T.inputSchema)
    let response = await T.execute(input, ~taskId="task", ~toolCallId="call")
    let json = response->S.decodeOrThrow(~from=Tool.MCP.CallToolResult.schema, ~to=S.json)
    t->expect(S.parseOrThrow(json, ~to=errorResponseSchema).isError)->Expect.toBe(true)
  })

  testAsync("uses the injected inspector and the same preview for routing", async t => {
    let doc =
      WebAPI.DomGlobal.document.implementation->WebAPI.DOMImplementation.createHTMLDocument(
        ~title="",
      )
    doc.head.innerHTML = "<meta name=\"astro-view-transitions-enabled\">"
    let preview: Tool.previewContext = {doc, win: WebAPI.Window.current}
    let previewReads = ref(0)
    let inspections = ref(0)
    let inspected: GetDom.output = {
      url: "https://preview.test/page",
      html: "<main id=\"page\">Page</main>",
      nodeCount: 1,
      byteSize: 27,
      hint: Some("Inspection hint"),
    }
    module T = unpack(
      AstroGetDom.make(
        ~getPreviewDoc=() => {
          previewReads := previewReads.contents + 1
          Some(preview)
        },
        ~inspect=(input, context) => {
          inspections := inspections.contents + 1
          t->expect(input.selector)->Expect.toBe("#page")
          t->expect(context)->Expect.toBe(preview)
          Ok(inspected)
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
    t->expect(output.html)->Expect.toEqual(inspected.html)
    t->expect(output.nodeCount)->Expect.toEqual(inspected.nodeCount)
    t->expect(output.byteSize)->Expect.toEqual(inspected.byteSize)
    t->expect(output.hint)->Expect.toEqual(inspected.hint)
  })
})
