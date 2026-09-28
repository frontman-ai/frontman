open Vitest

module Inspector = Client__ElementInspector

let document = WebAPI.DomGlobal.document

afterEach(() => document.body.innerHTML = "")

test(
  "includes caller-supplied attributes only when requested, using shared escaping and limits",
  t => {
    document.body.innerHTML = `<main id="inspection-parent" data-boundary="outer"><div id="inspection-root" data-boundary="a&amp;&quot;b"><span data-boundary=""></span></div></main>`
    let element =
      document->WebAPI.Document.querySelector("#inspection-root")->Null.toOption->Option.getOrThrow
    let inspect = (~additionalAttributes=?) =>
      Inspector.inspect(~element, ~document, ~maxDepth=1, ~maxNodes=20, ~additionalAttributes?)
    t->expect(inspect().html->String.includes("data-boundary"))->Expect.toBe(false)
    let result = inspect(~additionalAttributes=["data-boundary"])
    [
      "data-boundary=\"outer\"",
      "data-boundary=\"a&\\\"b\"",
      "data-boundary=\"\"",
    ]->Array.forEach(field => t->expect(result.html->String.includes(field))->Expect.toBe(true))
    let ancestor = Inspector.describeAncestor(
      ~element=element.parentElement
      ->Null.toOption
      ->Option.getOrThrow
      ->WebAPI.HTMLElement.asElement,
      ~document,
      ~additionalAttributes=["data-boundary"],
    )
    t->expect(ancestor->String.includes("ancestor tag=\"main\""))->Expect.toBe(true)
    t
    ->expect(ancestor->String.includes("data-boundary=\"outer\" selector=\"#inspection-parent\""))
    ->Expect.toBe(true)
    element->WebAPI.Element.setAttribute(
      ~qualifiedName="data-boundary",
      ~value="é"->String.repeat(40_000),
    )
    let bounded = inspect(~additionalAttributes=["data-boundary"])
    t
    ->expect(bounded.html->String.includes(`data-boundary="${"é"->String.repeat(80)}..."`))
    ->Expect.toBe(true)
    t->expect(WebAPI.Blob.make(~blobParts=[String(bounded.html)]).size <= 30_000)->Expect.toBe(true)
  },
)
