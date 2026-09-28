open Vitest

module TiptapCore = FrontmanBindings.Bindings__Tiptap__Core

@get external contentType: TiptapCore.Content.t => string = "type"
@get external contentText: TiptapCore.Content.t => string = "text"
@get external contentAttrs: TiptapCore.Content.t => Dict.t<JSON.t> = "attrs"

describe("Tiptap content", () => {
  test("keeps HTML-like text literal", t => {
    let text = `<button data-action="save">Save & close</button>`
    let content = TiptapCore.Content.text(text)

    t->expect(content->contentType)->Expect.toBe("text")
    t->expect(content->contentText)->Expect.toBe(text)
  })

  test("constructs custom nodes with attributes", t => {
    let attrs = Dict.fromArray([("id", JSON.Encode.string("paste-1"))])
    let content = TiptapCore.Content.node(~type_="pastedText", ~attrs)

    t->expect(content->contentType)->Expect.toBe("pastedText")
    t
    ->expect(content->contentAttrs->Dict.get("id")->Option.flatMap(JSON.Decode.string))
    ->Expect.toEqual(Some("paste-1"))
  })
})
