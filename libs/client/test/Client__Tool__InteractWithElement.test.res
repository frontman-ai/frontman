open Vitest
module Interact = Client__Tool__InteractWithElement
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP
module Task = Client__State__Types.Task

@send
external createFrame: (
  WebAPI.DomTypes.document,
  @as("iframe") _,
) => WebAPI.DomTypes.htmliFrameElement = "createElement"
@get external value: WebAPI.DomTypes.element => string = "value"
@set external setValue: (WebAPI.DomTypes.element, string) => unit = "value"
@send external on: (WebAPI.DomTypes.element, string, unit => unit) => unit = "addEventListener"
@send external remove: WebAPI.DomTypes.element => unit = "remove"
type bounds = {@live width: float, @live height: float}
@set external setBounds: (WebAPI.DomTypes.element, unit => bounds) => unit = "getBoundingClientRect"
@set external setClick: (WebAPI.DomTypes.element, unit => unit) => unit = "click"
@set external setFocus: (WebAPI.DomTypes.element, unit => unit) => unit = "focus"
@schema type textContent = {text: string}
@schema
type response = {
  isError: option<bool>,
  structuredContent: Interact.output,
  content: array<textContent>,
}

let originalState = StateStore.getState(Client__State__Store.store)
let showPage = html => {
  let frame = WebAPI.DomGlobal.document->createFrame
  WebAPI.DomGlobal.document.body
  ->WebAPI.HTMLElement.appendChild((frame :> WebAPI.DomTypes.node))
  ->ignore
  let doc = frame->WebAPI.HTMLIFrameElement.contentDocument->Option.getOrThrow
  let win = frame->WebAPI.HTMLIFrameElement.contentWindow->Option.getOrThrow
  doc.body.innerHTML = html
  let task =
    Task.makeNew(~previewUrl="about:blank")->Client__Task__Reducer.Lens.setPreviewFrame(
      ~contentDocument=Some(doc),
      ~contentWindow=Some(win),
    )
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    {...originalState, currentTask: Task.New(task)},
  )
  doc->WebAPI.Document.querySelector("#field")->Null.getOrThrow
}

afterEach(() => {
  WebAPI.DomGlobal.document.body.innerHTML = ""
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    originalState,
  )
})

let input: Interact.input = {
  selector: Some("#field"),
  role: None,
  name: None,
  text: None,
  action: Some(#fill),
  value: Some("new"),
  index: None,
}
let execute = async input => {
  module T = unpack(
    Client__ToolRegistry.forFramework(Wordpress).tools
    ->Array.find(tool => {
      module T = unpack(tool)
      T.name === Interact.name
    })
    ->Option.getOrThrow
  )
  let parsed = input->S.decodeOrThrow(~from=Interact.inputSchema, ~to=T.inputSchema)
  let result = await T.execute(parsed, ~taskId="task", ~toolCallId="call")
  result
  ->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json)
  ->S.parseOrThrow(~to=responseSchema)
}
let expectError = (t, response) => {
  t->expect(response.isError)->Expect.toEqual(Some(true))
  t->expect(response.structuredContent.success)->Expect.toBe(false)
  t->expect(response.structuredContent.error->Option.isSome)->Expect.toBe(true)
  let serialized =
    (response.content->Array.getUnsafe(0)).text->S.decodeOrThrow(
      ~from=S.jsonString,
      ~to=Interact.outputSchema,
    )
  t->expect(serialized)->Expect.toEqual(response.structuredContent)
}

["<input id='field' value='old'>", "<textarea id='field'>old</textarea>"]->Array.forEach(html => {
  testAsync(`replaces and clears entire field, with application events: ${html}`, async t => {
    let field = showPage(html)
    let events = []
    ["input", "change", "blur"]->Array.forEach(
      type_ => field->on(type_, () => events->Array.push((type_, value(field)))->ignore),
    )
    let response = await execute(input)
    t->expect(response.isError)->Expect.toEqual(None)
    t->expect(response.structuredContent.success)->Expect.toBe(true)
    t->expect(response.structuredContent.action)->Expect.toEqual(Some("filled"))
    t->expect(value(field))->Expect.toBe("new")
    t->expect(events)->Expect.toEqual([("input", "new"), ("change", "new"), ("blur", "new")])
    let cleared = await execute({...input, value: Some("")})
    t->expect(cleared.structuredContent.success)->Expect.toBe(true)
    t->expect(value(field))->Expect.toBe("")
  })
})

testAsync("textarea preserves Unicode and multiline content", async t => {
  let field = showPage("<textarea id='field'>old</textarea>")
  let expected = "第一行 🎯\nline 2 — café"
  let response = await execute({...input, value: Some(expected)})
  t->expect(response.structuredContent.success)->Expect.toBe(true)
  t->expect(value(field))->Expect.toBe(expected)
})

testAsync("text is targeting only: missing value fails without mutation", async t => {
  let field = showPage("<input id='field' value='old'>")
  let response = await execute({...input, text: Some("not a value"), value: None})
  expectError(t, response)
  t
  ->expect(
    response.structuredContent.error->Option.getOrThrow->String.includes("'value' is required"),
  )
  ->Expect.toBe(true)
  t->expect(value(field))->Expect.toBe("old")
})

[
  "<input id='field' disabled value='old'>",
  "<fieldset disabled><input id='field' value='old'></fieldset>",
  "<input id='field' readonly value='old'>",
  "<input id='field' aria-readonly='true' value='old'>",
  "<div inert><input id='field' value='old'></div>",
  "<input id='field' type='checkbox' value='old'>",
  "<input id='field' type='file'>",
  "<div id='field'>old</div>",
]->Array.forEach(html =>
  testAsync(`rejects protected or unsupported targets: ${html}`, async t => {
    let field = showPage(html)
    let before = field.outerHTML
    let response = await execute(input)
    expectError(t, response)
    t->expect(field.outerHTML)->Expect.toBe(before)
  })
)

testAsync("reports application state reverting the fill after input", async t => {
  let field = showPage("<input id='field' value='old'>")
  field->on("input", () => setTimeout(() => setValue(field, "old"), 0)->ignore)
  let response = await execute(input)
  expectError(t, response)
  t
  ->expect(response.structuredContent.error->Option.getOrThrow->String.includes("not accepted"))
  ->Expect.toBe(true)
})

testAsync("reports removed fields, sanitized values, and rejected focus", async t => {
  let field = showPage("<input id='field' value='old'>")
  field->on("blur", () => remove(field))
  expectError(t, await execute(input))
  let _ = showPage("<input id='field'>")
  expectError(t, await execute({...input, value: Some("one\ntwo")}))
  let field = showPage("<input id='field'>")
  field->setFocus(() => ())
  expectError(t, await execute(input))
})

testAsync("retains selector/index and role/name targeting", async t => {
  let first = showPage(
    "<input id='field' aria-label='Title' value='first'><input aria-label='Title' value='second'>",
  )
  let {doc} = Client__Tool__PreviewContext.get()->Option.getOrThrow
  doc
  ->WebAPI.Document.querySelectorAll("input")
  ->WebAPI.NodeList.toArray
  ->Array.forEach(field => field->setBounds(() => {width: 100.0, height: 30.0}))
  let response = await execute({...input, selector: Some("input"), index: Some(1)})
  t->expect(response.structuredContent.matchCount)->Expect.toEqual(Some(2))
  t->expect(value(first))->Expect.toBe("first")
  let response = await execute({
    ...input,
    selector: None,
    role: Some("textbox"),
    name: Some("Title"),
    index: Some(1),
    value: Some("last"),
  })
  t->expect(response.structuredContent.success)->Expect.toBe(true)
  t->expect(response.structuredContent.matchCount)->Expect.toEqual(Some(2))
  let second = doc->WebAPI.Document.querySelector("input:last-child")->Null.getOrThrow
  t->expect(value(second))->Expect.toBe("last")
})

testAsync("retains text/default click and focus/hover actions", async t => {
  let field = showPage("<button id='field'>Save</button>")
  field->setBounds(() => {width: 100.0, height: 30.0})
  let clicks = ref(0)
  field->on("click", () => clicks := clicks.contents + 1)
  let clicked = await execute({
    ...input,
    selector: None,
    text: Some("Save"),
    action: None,
    value: None,
  })
  t->expect(clicked.structuredContent.action)->Expect.toEqual(Some("clicked"))
  t->expect(clicks.contents)->Expect.toBe(1)
  t
  ->expect((await execute({...input, action: Some(#focus)})).structuredContent.action)
  ->Expect.toEqual(Some("focused"))
  t
  ->expect((await execute({...input, action: Some(#hover)})).structuredContent.action)
  ->Expect.toEqual(Some("hovered"))
})

testAsync("does not report disabled/no-op clicks or unfocusable targets as successful", async t => {
  let _ = showPage("<button id='field' disabled>Save</button>")
  expectError(t, await execute({...input, action: Some(#click)}))
  let _ = showPage("<div id='field'>Text</div>")
  expectError(t, await execute({...input, action: Some(#focus)}))
  let field = showPage("<button id='field'>Save</button>")
  field->setClick(() => ())
  expectError(t, await execute({...input, action: Some(#click)}))
})

testAsync("missing targets and invalid selectors preserve structured MCP errors", async t => {
  let _ = showPage("<input id='field'>")
  let requests = [
    {...input, selector: Some("#missing")},
    {...input, selector: Some("[")},
    {...input, selector: None},
    {...input, selector: None, role: Some("button")},
  ]
  for index in 0 to requests->Array.length - 1 {
    expectError(t, await execute(requests->Array.getUnsafe(index)))
  }
})
