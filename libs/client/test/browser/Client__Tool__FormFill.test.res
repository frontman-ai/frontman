open Vitest
module Fixture = Client__FormFixture
module Interact = Client__Tool__InteractWithElement

@schema
type request = {
  @live selector: option<string>,
  @live role: option<string>,
  @live name: option<string>,
  @live text: option<string>,
  @live index: option<int>,
  @live action: string,
  @live value: option<string>,
}
@schema
type response = {
  isError: option<bool>,
  structuredContent: option<Interact.output>,
}
let call = async request => {
  let json = S.decodeOrThrow(request, ~from=requestSchema, ~to=S.jsonString)
  let result = await Fixture.execute(~name=Interact.name, json)
  S.parseOrThrow(result, ~to=responseSchema)
}
let fill = (~selector=Some("#field"), ~value, ~role=None, ~name=None, ~text=None, ~index=None) => {
  selector,
  role,
  name,
  text,
  index,
  action: "fill",
  value: Some(value),
}
afterEach(Fixture.cleanup)
let mount = Fixture.mount
let success = (t, result) => {
  let output = result.structuredContent->Option.getOrThrow
  t
  ->expect((result.isError === Some(true), output.success, output.error))
  ->Expect.toEqual((false, true, None))
  t->expect(output.action)->Expect.toEqual(Some("filled"))
}
let saveReload = async fixture => {
  let _ = await call({
    ...fill(~value=""),
    action: "click",
    selector: Some("#save"),
    value: None,
  })
  await fixture->Fixture.reload
  Fixture.preview(~doc=fixture->Fixture.doc, ~win=fixture->Fixture.win)
}

["native", "react", "textarea", "contenteditable", "draft"]->Array.forEach(kind => {
  let selector = kind === "draft" ? Some("[contenteditable=true]") : Some("#field")
  testAsync(`${kind}: replaces Unicode, updates application state, saves and reloads`, async t => {
    let fixture = await mount(kind)
    let expected = "新しい title — café 🎯"
    let result = await call(fill(~selector, ~value=expected))
    success(t, result)
    t->expect(fixture->Fixture.value)->Expect.toBe(expected)
    t->expect(fixture->Fixture.state)->Expect.toBe(expected)
    switch kind {
    | "draft" =>
      t->expect(fixture->Fixture.changes > 0)->Expect.toBe(true)
      t->expect(fixture->Fixture.focused)->Expect.toBe(false)
    | _ => ()
    }
    await saveReload(fixture)
    t->expect(fixture->Fixture.value)->Expect.toBe(expected)
    t->expect(fixture->Fixture.state)->Expect.toBe(expected)
    success(t, await call(fill(~selector, ~value=expected)))
    t->expect(fixture->Fixture.state)->Expect.toBe(expected)
    let result = await call(fill(~selector, ~value="Second replacement"))
    success(t, result)
    t->expect(fixture->Fixture.state)->Expect.toBe("Second replacement")
  })
  testAsync(`${kind}: empty string clears and stays empty after save/reload`, async t => {
    let fixture = await mount(kind)
    let result = await call(fill(~selector, ~value=""))
    success(t, result)
    success(t, await call(fill(~selector, ~value="")))
    t->expect(fixture->Fixture.value)->Expect.toBe("")
    t->expect(fixture->Fixture.state)->Expect.toBe("")
    await saveReload(fixture)
    t->expect(fixture->Fixture.value)->Expect.toBe("")
    t->expect(fixture->Fixture.state)->Expect.toBe("")
  })
})

["textarea", "contenteditable", "draft"]->Array.forEach(kind => {
  testAsync(`${kind}: preserves line breaks through application state and persistence`, async t => {
    let fixture = await mount(kind)
    let expected = "First line\n第二行 🎯\nThird line"
    let selector = kind === "draft" ? Some("[contenteditable=true]") : Some("#field")
    let result = await call(fill(~selector, ~value=expected))
    success(t, result)
    t->expect(fixture->Fixture.state)->Expect.toBe(expected)
    await saveReload(fixture)
    t->expect(fixture->Fixture.value)->Expect.toBe(expected)
    t->expect(fixture->Fixture.state)->Expect.toBe(expected)
    success(t, await call(fill(~selector, ~value="")))
    t->expect(fixture->Fixture.state)->Expect.toBe("")
    success(t, await call(fill(~selector, ~value=expected)))
    t->expect(fixture->Fixture.state)->Expect.toBe(expected)
    success(t, await call(fill(~selector, ~value="One line replaces every old block")))
    t->expect(fixture->Fixture.state)->Expect.toBe("One line replaces every old block")
    success(t, await call(fill(~selector, ~value="")))
    success(t, await call(fill(~selector, ~value="")))
    t->expect(fixture->Fixture.state)->Expect.toBe("")
  })
})

["readonly", "disabled"]->Array.forEach(attribute => {
  testAsync(`rejects ${attribute} without changing field or application state`, async t => {
    let fixture = await mount("native")
    let field = fixture->Fixture.doc->WebAPI.Document.querySelector("#field")->Null.getOrThrow
    field->WebAPI.Element.setAttribute(~qualifiedName=attribute, ~value="")
    let result = await call(fill(~value="Must not write"))
    t->expect(result.isError)->Expect.toEqual(Some(true))
    t->expect((result.structuredContent->Option.getOrThrow).success)->Expect.toBe(false)
    t->expect(fixture->Fixture.value)->Expect.toBe("Original title")
    t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  })
})

testAsync("role/name index changes only row 77 and persists it after save/reload", async t => {
  let fixture = await mount("bulk")
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
  t->expect((result.structuredContent->Option.getOrThrow).matchCount)->Expect.toEqual(Some(77))
  t->expect(fixture->Fixture.rowValue(76))->Expect.toBe("Last title")
  t->expect(fixture->Fixture.rowState(76))->Expect.toBe("Last title")
  for index in 0 to 75 {
    t->expect(fixture->Fixture.rowState(index))->Expect.toBe(`Row ${Int.toString(index + 1)}`)
  }
  await saveReload(fixture)
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
  for index in 0 to 76 {
    t
    ->expect(fixture->Fixture.rowState(index))
    ->Expect.toBe(`Title ${Int.toString(index + 1)} — café 🎯`)
  }
  await saveReload(fixture)
  for index in 0 to 76 {
    let title = `Title ${Int.toString(index + 1)} — café 🎯`
    t->expect(fixture->Fixture.rowState(index))->Expect.toBe(title)
    t->expect(fixture->Fixture.rowValue(index))->Expect.toBe(title)
  }
})

testAsync("text selects the field; it is not the replacement value", async t => {
  let fixture = await mount("contenteditable")
  let result = await call(fill(~selector=None, ~text=Some("Original title"), ~value="Replacement"))
  success(t, result)
  t->expect(fixture->Fixture.state)->Expect.toBe("Replacement")
})

let rejected = (t, result) => {
  t->expect(result.isError)->Expect.toEqual(Some(true))
  let output = result.structuredContent->Option.getOrThrow
  t->expect(output.success)->Expect.toBe(false)
  t->expect(output.error->Option.isSome)->Expect.toBe(true)
}

["react-revert", "draft-revert"]->Array.forEach(kind => {
  testAsync(`${kind}: asynchronous application rejection is an MCP error`, async t => {
    let fixture = await mount(kind)
    let selector = kind === "draft-revert" ? Some("[contenteditable=true]") : Some("#field")
    rejected(t, await call(fill(~selector, ~value="Rejected title")))
    t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
    t->expect(fixture->Fixture.value)->Expect.toBe("Original title")
    await saveReload(fixture)
    t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  })
})

testAsync("Draft handled-but-rejected paste never falls back to a DOM-only edit", async t => {
  let fixture = await mount("draft-reject-paste")
  rejected(t, await call(fill(~selector=Some("[contenteditable=true]"), ~value="First\nSecond")))
  t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  t->expect(fixture->Fixture.value)->Expect.toBe("Original title")
})

testAsync("genuine Draft readonly editor rejects mutation", async t => {
  let fixture = await mount("draft-readonly")
  rejected(
    t,
    await call(fill(~selector=Some(".public-DraftEditor-content"), ~value="Must not write")),
  )
  t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
})

testAsync("later app reverts require save/readback beyond bounded fill verification", async t => {
  let fixture = await mount("react-delayed-revert")
  success(t, await call(fill(~value="Initially accepted")))
  t->expect(fixture->Fixture.state)->Expect.toBe("Initially accepted")
  await Promise.make((resolve, _) => setTimeout(() => resolve(), 250)->ignore)
  t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  await saveReload(fixture)
  t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
})

testAsync("email select replaces rather than appends, with state and persistence", async t => {
  let fixture = await mount("native")
  fixture
  ->Fixture.doc
  ->WebAPI.Document.querySelector("#field")
  ->Null.getOrThrow
  ->WebAPI.Element.setAttribute(~qualifiedName="type", ~value="email")
  success(t, await call(fill(~value="title@example.com")))
  t->expect(fixture->Fixture.state)->Expect.toBe("title@example.com")
  await saveReload(fixture)
  t->expect(fixture->Fixture.value)->Expect.toBe("title@example.com")
})

testAsync("maxlength rejection does not partially edit or bypass the constraint", async t => {
  let fixture = await mount("native")
  fixture
  ->Fixture.doc
  ->WebAPI.Document.querySelector("#field")
  ->Null.getOrThrow
  ->WebAPI.Element.setAttribute(~qualifiedName="maxlength", ~value="5")
  rejected(t, await call(fill(~value="Too long")))
  t->expect(fixture->Fixture.state)->Expect.toBe("Original title")
  t->expect(fixture->Fixture.value)->Expect.toBe("Original title")
})

testAsync("missing value, unsupported controls and missing targets produce MCP errors", async t => {
  let _ = await mount("native")
  let requests = [
    {...fill(~value=""), value: None},
    fill(~selector=Some("#save"), ~value="Not editable"),
    fill(~selector=Some("#missing"), ~value="No target"),
  ]
  for index in 0 to requests->Array.length - 1 {
    let result = await call(requests->Array.getUnsafe(index))
    t->expect(result.isError)->Expect.toEqual(Some(true))
  }
})
