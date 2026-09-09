open Vitest

module Persistence = FrontmanAstroBrowser__Persistence

let selectedFromHtml = html => {
  let document =
    WebAPI.DomGlobal.document.implementation->WebAPI.DOMImplementation.createHTMLDocument(~title="")
  document.body.innerHTML = html
  document->WebAPI.Document.querySelector("#selected")->Null.toOption->Option.getOrThrow
}

let describeKey = element =>
  element
  ->WebAPI.Element.getAttribute(Persistence.markerAttribute)
  ->Null.toOption
  ->Option.getOrThrow

let nested = (count, ~marked) => {
  let opening = switch marked {
  | true => "<div data-astro-transition-persist=\"boundary\">"
  | false => "<div>"
  }
  opening->String.repeat(count) ++
  "<button id=\"selected\"></button>" ++
  "</div>"->String.repeat(count)
}

test("bounds parent traversal and distinguishes truncated empty results", t => {
  let element = selectedFromHtml(
    "<main data-astro-transition-persist=\"outside-limit\">" ++
    nested(50, ~marked=false) ++ "</main>",
  )
  let result = Persistence.read(element, ~describeAncestor=describeKey)
  t->expect(result.ancestors)->Expect.toEqual([])
  t->expect(result.truncated)->Expect.toBe(true)
})

test("caps marked ancestors at ten", t => {
  let result = Persistence.read(
    selectedFromHtml(nested(11, ~marked=true)),
    ~describeAncestor=describeKey,
  )
  t->expect(result.ancestors->Array.length)->Expect.toBe(10)
  t->expect(result.truncated)->Expect.toBe(true)
})

test("caps serialized UTF-8 context including JSON escaping without partial descriptors", t => {
  let element = selectedFromHtml(nested(3, ~marked=true))
  let description = "é\""->String.repeat(600)
  let result = Persistence.read(element, ~describeAncestor=_ => description)
  t->expect(result.ancestors)->Expect.toEqual([description])
  t->expect(result.truncated)->Expect.toBe(true)
  let json =
    result
    ->S.decodeOrThrow(~from=Persistence.schema, ~to=S.json)
    ->JSON.stringifyAny
    ->Option.getOrThrow
  t
  ->expect(WebAPI.Blob.make(~blobParts=[String(json)]).size <= Persistence.maxOutputBytes)
  ->Expect.toBe(true)
  let oversized = Persistence.read(element, ~describeAncestor=_ => "x"->String.repeat(4096))
  t->expect(oversized.ancestors)->Expect.toEqual([])
  t->expect(oversized.truncated)->Expect.toBe(true)
})
