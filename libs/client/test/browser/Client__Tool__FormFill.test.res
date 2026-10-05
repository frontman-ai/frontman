open Vitest
module Fixture = Client__FormFixture
module Interact = Client__Tool__InteractWithElement

@schema type textContent = {text: string}
@schema
type response = {
  isError: option<bool>,
  structuredContent: Interact.output,
  content: array<textContent>,
}
let call = async (input: Interact.input) => {
  let json = S.decodeOrThrow(input, ~from=Interact.inputSchema, ~to=S.jsonString)
  let result = await Fixture.execute(~name=Interact.name, json)
  S.parseOrThrow(result, ~to=responseSchema)
}
let fill = (
  ~selector=Some("#field"),
  ~value,
  ~role=None,
  ~name=None,
  ~text=None,
  ~index=None,
): Interact.input => {
  selector,
  role,
  name,
  text,
  index,
  action: Some(#fill),
  value: Some(value),
}
@send external on: (WebAPI.DomTypes.element, string, unit => unit) => unit = "addEventListener"
@set external setClick: (WebAPI.DomTypes.element, unit => unit) => unit = "click"
@set external setFocus: (WebAPI.DomTypes.element, unit => unit) => unit = "focus"
@set
external setExecCommand: (
  WebAPI.DomTypes.document,
  option<(string, bool, string) => bool>,
) => unit = "execCommand"
afterEach(Fixture.cleanup)
let mount = Fixture.mount
let textOutput = result =>
  (result.content->Array.get(0)->Option.getOrThrow).text->S.decodeOrThrow(
    ~from=S.jsonString,
    ~to=Interact.outputSchema,
  )
let success = (t, result, ~action="filled") => {
  let output = result.structuredContent
  t
  ->expect((result.isError === Some(true), output.success, output.error))
  ->Expect.toEqual((false, true, None))
  t->expect(output.action)->Expect.toEqual(Some(action))
  t->expect(textOutput(result))->Expect.toEqual(output)
}
let rejected = (t, result) => {
  t->expect(result.isError)->Expect.toEqual(Some(true))
  t->expect(result.structuredContent.success)->Expect.toBe(false)
  t->expect(result.structuredContent.error->Option.isSome)->Expect.toBe(true)
  t->expect(textOutput(result))->Expect.toEqual(result.structuredContent)
}
let field = fixture =>
  fixture->Fixture.doc->WebAPI.Document.querySelector("#field")->Null.getOrThrow
let saveReload = async (t, fixture) => {
  success(
    t,
    await call({...fill(~value=""), action: Some(#click), selector: Some("#save"), value: None}),
    ~action="clicked",
  )
  await fixture->Fixture.reload
  Fixture.preview(~doc=fixture->Fixture.doc, ~win=fixture->Fixture.win)
}

/// Each row owns a different editing path, not every value x every fixture.
[
  ("native", "新しい title — café 🎯"),
  ("react", "新しい title — café 🎯"),
  ("textarea", "First line\n第二行 🎯\nThird line"),
  ("contenteditable", "First line\n第二行 🎯\nThird line"),
  ("draft", "First line\n第二行 🎯\nThird line"),
]->Array.forEach(((kind, expected)) => {
  let selector =
    kind === "draft"
      ? Some("[contenteditable=true]")
      : kind === "contenteditable"
      ? None
      : Some("#field")
  let request = value => fill(~selector, ~role=Some("textbox"), ~name=Some("Title"), ~value)
  testAsync(`${kind}: replaces, clears, and persists application state`, async t => {
    let fixture = await mount(kind)
    success(t, await call(request(expected)))
    t->expect(fixture->Fixture.value)->Expect.toBe(expected)
    t->expect(fixture->Fixture.state)->Expect.toBe(expected)
    switch kind {
    | "draft" =>
      t->expect(fixture->Fixture.changes > 0)->Expect.toBe(true)
      t->expect(fixture->Fixture.focused)->Expect.toBe(false)
    | _ => ()
    }
    await saveReload(t, fixture)
    t->expect(fixture->Fixture.value)->Expect.toBe(expected)
    t->expect(fixture->Fixture.state)->Expect.toBe(expected)
    success(t, await call(request(expected)))
    success(t, await call(request("One line replaces every old block")))
    t->expect(fixture->Fixture.value)->Expect.toBe("One line replaces every old block")
    t->expect(fixture->Fixture.state)->Expect.toBe("One line replaces every old block")
    success(t, await call(request("")))
    success(t, await call(request("")))
    t->expect(fixture->Fixture.value)->Expect.toBe("")
    t->expect(fixture->Fixture.state)->Expect.toBe("")
    await saveReload(t, fixture)
    t->expect(fixture->Fixture.value)->Expect.toBe("")
    t->expect(fixture->Fixture.state)->Expect.toBe("")
    success(t, await call(request(expected)))
    t->expect(fixture->Fixture.state)->Expect.toBe(expected)
  })
})

["react", "textarea"]->Array.forEach(kind => {
  testAsync(`${kind}: absent execCommand uses native setter and application events`, async t => {
    let fixture = await mount(kind)
    fixture->Fixture.doc->setExecCommand(None)
    let events = []
    ["input", "change", "blur"]->Array.forEach(
      type_ =>
        field(fixture)->on(
          type_,
          () => events->Array.push((type_, fixture->Fixture.value))->ignore,
        ),
    )
    success(t, await call(fill(~value="Fallback 🎯")))
    t
    ->expect(events)
    ->Expect.toEqual([
      ("input", "Fallback 🎯"),
      ("change", "Fallback 🎯"),
      ("blur", "Fallback 🎯"),
    ])
    t->expect(fixture->Fixture.state)->Expect.toBe("Fallback 🎯")
    success(t, await call(fill(~value="")))
    t->expect(fixture->Fixture.state)->Expect.toBe("")
    await saveReload(t, fixture)
    t->expect(fixture->Fixture.value)->Expect.toBe("")
    t->expect(fixture->Fixture.state)->Expect.toBe("")
  })
})

[
  ("native", "readonly", "", false),
  ("textarea", "readonly", "", false),
  ("native", "fieldset", "", false),
  ("contenteditable", "aria-readonly", "true", false),
  ("native", "inert", "", false),
  ("native", "type", "checkbox", false),
  ("native", "type", "file", false),
  ("native", "maxlength", "5", false),
  ("textarea", "maxlength", "5", false),
  ("native", "disabled", "", true),
  ("textarea", "readonly", "", true),
  ("native", "maxlength", "5", true),
  ("native", "type", "checkbox", true),
]->Array.forEach(((kind, attribute, value, onFocus)) => {
  testAsync(`${kind}: rejects ${onFocus ? "focus-time" : "static"} ${attribute}`, async t => {
    let fixture = await mount(kind)
    let el = field(fixture)
    let protect = () =>
      switch attribute {
      | "fieldset" | "inert" | "aria-readonly" =>
        let parent =
          fixture
          ->Fixture.doc
          ->WebAPI.Document.createElement(attribute === "fieldset" ? "fieldset" : "div")
        parent->WebAPI.Element.setAttribute(
          ~qualifiedName=attribute === "fieldset" ? "disabled" : attribute,
          ~value,
        )
        el.parentElement
        ->Null.getOrThrow
        ->WebAPI.HTMLElement.appendChild((parent :> WebAPI.DomTypes.node))
        ->ignore
        parent->WebAPI.Element.appendChild((el :> WebAPI.DomTypes.node))->ignore
      | _ => el->WebAPI.Element.setAttribute(~qualifiedName=attribute, ~value)
      }
    switch onFocus {
    | true => el->on("focus", protect)
    | false => protect()
    }
    let before = fixture->Fixture.value
    rejected(t, await call(fill(~value="Must not write")))
    t->expect(fixture->Fixture.value)->Expect.toBe(before)
    t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  })
})

/// Yield and callback are separate command boundaries; paste and delete use different callbacks.
[
  ("yield", "focus", "Replacement"),
  ("yield", "selection", "Replacement"),
  ("yield", "disconnect", "Replacement"),
  ("yield", "readonly", "Replacement"),
  ("callback", "focus", "Replacement"),
  ("callback", "selection", ""),
  ("callback", "disconnect", ""),
  ("callback", "readonly", "Replacement"),
]->Array.forEach(((timing, drift, value)) => {
  testAsync(`${timing} ${drift}: rejects drift before unrelated writes`, async t => {
    let fixture = await mount("contenteditable")
    let doc = fixture->Fixture.doc
    let el = field(fixture)
    let other = doc->WebAPI.Document.createElement("div")
    other->WebAPI.Element.setAttribute(~qualifiedName="contenteditable", ~value="true")
    other.innerHTML = "Unrelated title"
    doc.body->WebAPI.HTMLElement.appendChild((other :> WebAPI.DomTypes.node))->ignore
    let move = () =>
      switch drift {
      | "disconnect" => el->WebAPI.Element.remove
      | "readonly" => el->WebAPI.Element.setAttribute(~qualifiedName="aria-readonly", ~value="true")
      | _ =>
        switch drift {
        | "focus" =>
          other
          ->FrontmanBindings.Bindings__WebAPI.unsafeHtmlElementFromElement
          ->WebAPI.HTMLElement.focus
        | _ => ()
        }
        let range = doc->WebAPI.Document.createRange
        range->WebAPI.Range.selectNodeContents((other :> WebAPI.DomTypes.node))
        let selection = doc->WebAPI.Document.getSelection->Null.getOrThrow
        selection->WebAPI.Selection.removeAllRanges
        selection->WebAPI.Selection.addRange(range)
      }
    switch timing {
    | "yield" => el->on("focus", () => setTimeout(move, 0)->ignore)
    | _ => el->on(value === "" ? "keydown" : "paste", move)
    }
    rejected(t, await call(fill(~value)))
    t->expect((el :> WebAPI.DomTypes.node).textContent)->Expect.toEqual(Null.make("Original title"))
    t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
    t
    ->expect((other :> WebAPI.DomTypes.node).textContent)
    ->Expect.toEqual(Null.make("Unrelated title"))
  })
})

[("native", "Replacement"), ("textarea", "")]->Array.forEach(((kind, value)) => {
  testAsync(`${kind}: native edit remains undoable`, async t => {
    let fixture = await mount(kind)
    success(t, await call(fill(~value)))
    field(fixture)
    ->FrontmanBindings.Bindings__WebAPI.unsafeHtmlElementFromElement
    ->WebAPI.HTMLElement.focus
    t
    ->expect(FrontmanBindings.Bindings__WebAPI.execCommand(fixture->Fixture.doc, "undo", false, ""))
    ->Expect.toBe(true)
    t->expect(fixture->Fixture.value)->Expect.toBe("Original title")
    t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  })
})

testAsync(
  "editable heading preserves computed role, application state and persistence",
  async t => {
    let fixture = await mount("heading")
    success(
      t,
      await call(
        fill(~selector=None, ~role=Some("heading"), ~name=Some("Title"), ~value="New heading 🎯"),
      ),
    )
    t->expect(fixture->Fixture.value)->Expect.toBe("New heading 🎯")
    t->expect(fixture->Fixture.state)->Expect.toBe("New heading 🎯")
    await saveReload(t, fixture)
    t->expect(fixture->Fixture.value)->Expect.toBe("New heading 🎯")
  },
)

testAsync("selector/index and role/name index change only row 77 and persist it", async t => {
  let fixture = await mount("bulk")
  let selected = await call(fill(~selector=Some("input"), ~index=Some(76), ~value="Selected title"))
  success(t, selected)
  t->expect(selected.structuredContent.matchCount)->Expect.toEqual(Some(77))
  t->expect(fixture->Fixture.rowState(76))->Expect.toBe("Selected title")
  let result = await call(
    fill(
      ~selector=None,
      ~role=Some("textbox"),
      ~name=Some("Title"),
      ~index=Some(76),
      ~value="Last title",
    ),
  )
  success(t, result)
  t->expect(result.structuredContent.matchCount)->Expect.toEqual(Some(77))
  t->expect(fixture->Fixture.rowState(76))->Expect.toBe("Last title")
  for index in 0 to 75 {
    let original = `Row ${Int.toString(index + 1)}`
    t->expect(fixture->Fixture.rowState(index))->Expect.toBe(original)
    t->expect(fixture->Fixture.rowValue(index))->Expect.toBe(original)
  }
  await saveReload(t, fixture)
  t->expect(fixture->Fixture.rowValue(76))->Expect.toBe("Last title")
  for index in 0 to 75 {
    t->expect(fixture->Fixture.rowValue(index))->Expect.toBe(`Row ${Int.toString(index + 1)}`)
  }
})

testAsync("sequential fills save and reload all 77 distinct titles", ~timeout=15000, async t => {
  let fixture = await mount("bulk")
  for index in 0 to 76 {
    let title = `Title ${Int.toString(index + 1)} — café 🎯`
    success(
      t,
      await call(
        fill(
          ~selector=None,
          ~role=Some("textbox"),
          ~name=Some("Title"),
          ~index=Some(index),
          ~value=title,
        ),
      ),
    )
    t->expect(fixture->Fixture.rowState(index))->Expect.toBe(title)
  }
  await saveReload(t, fixture)
  for index in 0 to 76 {
    let title = `Title ${Int.toString(index + 1)} — café 🎯`
    t->expect(fixture->Fixture.rowState(index))->Expect.toBe(title)
    t->expect(fixture->Fixture.rowValue(index))->Expect.toBe(title)
  }
})

testAsync("text selects the innermost field, never the replacement value", async t => {
  let fixture = await mount("contenteditable")
  let request = {
    ...fill(~selector=None, ~text=Some("Original title"), ~value="Replacement"),
    value: None,
  }
  let result = await call(request)
  rejected(t, result)
  t
  ->expect(
    result.structuredContent.error->Option.getOrThrow->String.includes("'value' is required"),
  )
  ->Expect.toBe(true)
  t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  t->expect(fixture->Fixture.value)->Expect.toBe("Original title")
  success(t, await call({...request, value: Some("Replacement")}))
  t->expect(fixture->Fixture.state)->Expect.toBe("Replacement")
})

["react-revert", "draft-revert", "draft-reject-paste", "draft-readonly"]->Array.forEach(kind => {
  testAsync(`${kind}: rejected editor changes are MCP errors, not DOM-only edits`, async t => {
    let fixture = await mount(kind)
    let selector = kind === "react-revert" ? Some("#field") : Some(".public-DraftEditor-content")
    rejected(
      t,
      await call(
        fill(~selector, ~value=kind === "react-revert" ? "Rejected title" : "First\nSecond"),
      ),
    )
    t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
    t->expect(fixture->Fixture.value)->Expect.toBe("Original title")
    await saveReload(t, fixture)
    t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  })
})

testAsync("later app reverts require save/readback beyond bounded fill verification", async t => {
  let fixture = await mount("react-delayed-revert")
  success(t, await call(fill(~value="Initially accepted")))
  t->expect(fixture->Fixture.state)->Expect.toBe("Initially accepted")
  await Promise.make((resolve, _) => setTimeout(() => resolve(), 250)->ignore)
  t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  await saveReload(t, fixture)
  t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
})

testAsync("email select replaces rather than appends, with state and persistence", async t => {
  let fixture = await mount("native")
  field(fixture)->WebAPI.Element.setAttribute(~qualifiedName="type", ~value="email")
  success(t, await call(fill(~value="title@example.com")))
  t->expect(fixture->Fixture.state)->Expect.toBe("title@example.com")
  await saveReload(t, fixture)
  t->expect(fixture->Fixture.value)->Expect.toBe("title@example.com")
})

testAsync(
  "removal after blur, input sanitization and rejected focus cannot report a fill",
  async t => {
    let removed = await mount("native")
    let removedField = field(removed)
    removedField->on("blur", () => removedField->WebAPI.Element.remove)
    rejected(t, await call(fill(~value="Removed")))
    t->expect((removedField :> WebAPI.DomTypes.node).isConnected)->Expect.toBe(false)
    t->expect(removed->Fixture.state)->Expect.toBe("Removed")
    let sanitized = await mount("native")
    rejected(t, await call(fill(~value="one\ntwo")))
    t->expect(sanitized->Fixture.value)->Expect.not->Expect.toBe("one\ntwo")
    t->expect(sanitized->Fixture.state)->Expect.toBe(sanitized->Fixture.value)
    let unfocused = await mount("native")
    field(unfocused)->setFocus(() => ())
    rejected(t, await call(fill(~value="Must not write")))
    t->expect(unfocused->Fixture.state)->Expect.toBe("Original title")
    t->expect(unfocused->Fixture.value)->Expect.toBe("Original title")
  },
)

testAsync("default text click, focus and hover perform observable actions", async t => {
  let fixture = await mount("native")
  let button = fixture->Fixture.doc->WebAPI.Document.querySelector("#save")->Null.getOrThrow
  let events = []
  ["click", "focus", "mouseenter", "mouseover"]->Array.forEach(type_ =>
    button->on(type_, () => events->Array.push(type_)->ignore)
  )
  success(
    t,
    await call({...fill(~selector=None, ~text=Some("Save"), ~value=""), action: None, value: None}),
    ~action="clicked",
  )
  success(
    t,
    await call({...fill(~selector=Some("#save"), ~value=""), action: Some(#focus), value: None}),
    ~action="focused",
  )
  success(
    t,
    await call({...fill(~selector=Some("#save"), ~value=""), action: Some(#hover), value: None}),
    ~action="hovered",
  )
  t->expect(events)->Expect.toEqual(["click", "focus", "mouseenter", "mouseover"])
})

testAsync("disabled/no-op clicks and unfocusable targets are MCP errors", async t => {
  let fixture = await mount("native")
  let button = fixture->Fixture.doc->WebAPI.Document.querySelector("#save")->Null.getOrThrow
  let request = {...fill(~selector=Some("#save"), ~value=""), action: Some(#click), value: None}
  button->WebAPI.Element.setAttribute(~qualifiedName="disabled", ~value="")
  rejected(t, await call(request))
  button->WebAPI.Element.removeAttribute("disabled")
  button->setClick(() => ())
  rejected(t, await call(request))
  rejected(t, await call({...request, selector: Some("#app"), action: Some(#focus)}))
})

testAsync("invalid targets preserve structured and text MCP errors without mutation", async t => {
  let fixture = await mount("native")
  let requests = [
    {...fill(~value=""), value: None},
    fill(~selector=Some("#save"), ~value="Not editable"),
    fill(~selector=Some("#app"), ~value="Not editable"),
    fill(~selector=Some("#missing"), ~value="No target"),
    fill(~selector=Some("["), ~value="Invalid selector"),
    fill(~selector=None, ~value="No strategy"),
    fill(~selector=None, ~role=Some("button"), ~value="Incomplete role targeting"),
    fill(~index=Some(1), ~value="Out of range"),
  ]
  for index in 0 to requests->Array.length - 1 {
    rejected(t, await call(requests->Array.getUnsafe(index)))
    t->expect(fixture->Fixture.value)->Expect.toBe("Original title")
    t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  }
})
