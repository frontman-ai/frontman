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

test(
  "finds marked DOM ancestors nearest first, including empty markers, not the selected node",
  t => {
    let element = selectedFromHtml(
      "<main data-astro-transition-persist=\"outer\"><section data-astro-transition-persist=\"\"><div><button id=\"selected\" data-astro-transition-persist=\"self\"></button></div></section></main>",
    )
    let result = Persistence.read(element, ~describeAncestor=describeKey)
    t->expect(result.ancestors)->Expect.toEqual(["", "outer"])
    t->expect(result.truncated)->Expect.toBe(false)
  },
)

test("ignores source directives and reads current markers without caching", t => {
  let element = selectedFromHtml(
    "<main transition:persist=\"audio\"><button id=\"selected\"></button></main>",
  )
  let parent = element.parentElement->Null.toOption->Option.getOrThrow->WebAPI.HTMLElement.asElement
  t->expect(Persistence.read(element, ~describeAncestor=describeKey).ancestors)->Expect.toEqual([])
  parent->WebAPI.Element.setAttribute(
    ~qualifiedName=Persistence.markerAttribute,
    ~value="runtime-key",
  )
  t
  ->expect(Persistence.read(element, ~describeAncestor=describeKey).ancestors)
  ->Expect.toEqual(["runtime-key"])
  parent->WebAPI.Element.removeAttribute(Persistence.markerAttribute)
  t->expect(Persistence.read(element, ~describeAncestor=describeKey).ancestors)->Expect.toEqual([])
})

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

test("does not mistake a shadow host for a DOM parent", t => {
  let host = selectedFromHtml("<div id=\"selected\" data-astro-transition-persist=\"host\"></div>")
  let shadow = host->WebAPI.Element.attachShadow({mode: Open})
  shadow.innerHTML = "<section data-astro-transition-persist=\"inside-shadow\"><button></button></section>"
  let element = shadow->WebAPI.ShadowRoot.querySelector("button")->Null.toOption->Option.getOrThrow
  let result = Persistence.read(element, ~describeAncestor=describeKey)
  t->expect(result.ancestors)->Expect.toEqual(["inside-shadow"])
  t->expect(result.truncated)->Expect.toBe(false)
})
