open Vitest
module Bindings = FrontmanBindings.Bindings__WebAPI

test("shared DOM conversions reject incompatible element types", t => {
  let document = WebAPI.DomGlobal.document
  let input = document->WebAPI.Document.createElement("input")
  let div = document->WebAPI.Document.createElement("div")
  let svg =
    document->WebAPI.Document.createElementNS(
      ~namespace="http://www.w3.org/2000/svg",
      ~qualifiedName="INPUT",
    )
  t->expect(input->Bindings.inputElementFromElement->Option.isSome)->Expect.toBe(true)
  t->expect(div->Bindings.htmlElementFromElement->Option.isSome)->Expect.toBe(true)
  t->expect(div->Bindings.inputElementFromElement)->Expect.toEqual(None)
  t->expect(svg->Bindings.htmlElementFromElement)->Expect.toEqual(None)
  t->expect(svg->Bindings.inputElementFromElement)->Expect.toEqual(None)
})
