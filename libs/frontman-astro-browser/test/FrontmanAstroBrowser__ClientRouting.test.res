open Vitest

module ClientRouting = FrontmanAstroBrowser__ClientRouting

@module("jsdom") @new
external makeDom: string => {"window": {"document": WebAPI.DomTypes.document}} = "JSDOM"

let documentFromHtml = html => makeDom(html)["window"]["document"]

describe("FrontmanAstroBrowser__ClientRouting", _t => {
  test("detects the ClientRouter marker", t => {
    let document = documentFromHtml(
      "<meta name=\"astro-view-transitions-enabled\" content=\"true\">",
    )
    t->expect(ClientRouting.read(Some(document)))->Expect.toBe(ClientRouting.Enabled)
  })

  test("matches Astro's presence check regardless of marker content", t => {
    let document = documentFromHtml(
      "<meta name=\"astro-view-transitions-enabled\" content=\"false\">",
    )
    t->expect(ClientRouting.read(Some(document)))->Expect.toBe(ClientRouting.Enabled)
  })

  test("reports disabled without the routing marker", t => {
    let document = documentFromHtml(
      "<meta name=\"astro-view-transitions-fallback\" content=\"animate\"><div transition:persist></div>",
    )
    t->expect(ClientRouting.read(Some(document)))->Expect.toBe(ClientRouting.Disabled)
  })

  test("distinguishes an unavailable document from disabled routing", t => {
    t->expect(ClientRouting.read(None))->Expect.toBe(ClientRouting.Unavailable)
  })

  test("reads the current document without caching routing status", t => {
    let document = documentFromHtml(
      "<meta name=\"astro-view-transitions-enabled\" content=\"true\">",
    )
    t->expect(ClientRouting.read(Some(document)))->Expect.toBe(ClientRouting.Enabled)
    let marker =
      document
      ->WebAPI.Document.querySelector("[name=\"astro-view-transitions-enabled\"]")
      ->Null.toOption
      ->Option.getOrThrow
    marker->WebAPI.Element.remove
    t->expect(ClientRouting.read(Some(document)))->Expect.toBe(ClientRouting.Disabled)
  })
})
