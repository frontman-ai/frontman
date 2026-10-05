open Vitest
module Fixture = Client__FormFixture
module Discovery = Client__Tool__GetInteractiveElements

@schema
type element = {
  index: int,
  role: string,
  name: string,
  detectionMethod: string,
  selector: option<string>,
}
@schema
type page = {
  success: bool,
  elements: option<array<element>>,
  totalCount: option<int>,
  truncated: option<bool>,
  nextOffset: option<int>,
}
@schema
type response = {structuredContent: option<page>}
afterEach(Fixture.cleanup)
let mount = Fixture.mount
let discover = async json => {
  let result = await Fixture.execute(~name=Discovery.name, json)
  S.parseOrThrow(result, ~to=responseSchema).structuredContent->Option.getOrThrow
}

testAsync(
  "plain contenteditable is discoverable and role/name targetable without an explicit role",
  async t => {
    let fixture = await mount("contenteditable")
    let page = await discover(`{"role":"textbox","name":"Title"}`)
    t->expect(page.success)->Expect.toBe(true)
    let elements = page.elements->Option.getOrThrow
    t->expect(elements->Array.length)->Expect.toBe(1)
    let editor = elements->Array.get(0)->Option.getOrThrow
    t->expect(editor.role)->Expect.toBe("textbox")
    t->expect(editor.name)->Expect.toBe("Title")
    t->expect(editor.detectionMethod)->Expect.toBe("contenteditable")
    t->expect(editor.selector->Option.isSome)->Expect.toBe(true)
    let (resolved, count) = Client__Tool__ElementQuery.resolveByRoleAndName(
      ~document=fixture->Fixture.doc,
      ~contentWindow=fixture->Fixture.win,
      ~role="textbox",
      ~name="Title",
      ~index=0,
    )
    t->expect(count)->Expect.toBe(1)
    t->expect(resolved->Option.isSome)->Expect.toBe(true)
  },
)

testAsync("77 identically labelled titles are reachable through bounded pages", async t => {
  let _ = await mount("bulk")
  let first = await discover(`{"role":"textbox","name":"Title"}`)
  t->expect(first.totalCount)->Expect.toEqual(Some(50))
  t->expect(first.truncated)->Expect.toEqual(Some(true))
  t->expect(first.nextOffset)->Expect.toEqual(Some(50))
  let second = await discover(`{"role":"textbox","name":"Title","offset":50}`)
  let bounded = await discover(`{"role":"textbox","name":"Title","limit":500}`)
  t->expect(bounded.totalCount)->Expect.toEqual(Some(50))
  t->expect(second.totalCount)->Expect.toEqual(Some(27))
  t->expect(second.truncated)->Expect.toEqual(Some(false))
  t->expect(second.nextOffset)->Expect.toEqual(None)
  let firstSelectors =
    first.elements->Option.getOrThrow->Array.map(el => el.selector->Option.getOrThrow)
  let secondSelectors =
    second.elements->Option.getOrThrow->Array.map(el => el.selector->Option.getOrThrow)
  t
  ->expect(secondSelectors->Array.some(selector => firstSelectors->Array.includes(selector)))
  ->Expect.toBe(false)
  t
  ->expect((second.elements->Option.getOrThrow->Array.get(0)->Option.getOrThrow).index)
  ->Expect.toBe(0)
})

testAsync("exactly 50 results are not falsely reported as truncated", async t => {
  let fixture = await mount("native")
  let doc = fixture->Fixture.doc
  for _index in 1 to 49 {
    let input = doc->WebAPI.Document.createElement("input")
    doc.body->WebAPI.HTMLElement.appendChild((input :> WebAPI.DomTypes.node))->ignore
  }
  let page = await discover(`{"role":"textbox"}`)
  t->expect(page.totalCount)->Expect.toEqual(Some(50))
  t->expect(page.truncated)->Expect.toEqual(Some(false))
})

testAsync("page size is bounded and offsets beyond matches return an empty final page", async t => {
  let _ = await mount("native")
  let page = await discover(`{"limit":1}`)
  t->expect(page.totalCount)->Expect.toEqual(Some(1))
  t->expect(page.nextOffset)->Expect.toEqual(Some(1))
  let clamped = await discover(`{"role":"textbox","offset":-1,"limit":0}`)
  t->expect(clamped.totalCount)->Expect.toEqual(Some(1))
  t->expect(clamped.nextOffset)->Expect.toEqual(None)
  let end = await discover(`{"offset":999,"limit":500}`)
  t->expect(end.totalCount)->Expect.toEqual(Some(0))
  t->expect(end.truncated)->Expect.toEqual(Some(false))
})

testAsync(
  "editable descendants are not duplicate hosts; false and hidden hosts are excluded",
  async t => {
    let fixture = await mount("contenteditable")
    let doc = fixture->Fixture.doc
    let host = doc->WebAPI.Document.querySelector("#field")->Null.getOrThrow
    let span = doc->WebAPI.Document.createElement("span")
    span.innerHTML = "Nested text"
    host->WebAPI.Element.appendChild((span :> WebAPI.DomTypes.node))->ignore
    ["false", "true"]->Array.forEach(editable => {
      let element = doc->WebAPI.Document.createElement("div")
      element->WebAPI.Element.setAttribute(~qualifiedName="contenteditable", ~value=editable)
      element->WebAPI.Element.setAttribute(
        ~qualifiedName="style",
        ~value=switch editable {
        | "false" => "min-height:30px"
        | _ => "min-height:30px;display:none"
        },
      )
      doc.body->WebAPI.HTMLElement.appendChild((element :> WebAPI.DomTypes.node))->ignore
    })
    let page = await discover(`{"role":"textbox"}`)
    t->expect(page.totalCount)->Expect.toEqual(Some(1))
  },
)
