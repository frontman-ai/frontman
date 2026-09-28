open Vitest

module PromptEditor = Client__PromptEditor

let stringJson = value => value->JSON.Encode.string

describe("serializePromptEditorContent", () => {
  test("serializes normal text", t => {
    let result = PromptEditor.serializePromptEditorContent({
      type_: "doc",
      content: [{type_: "paragraph", content: [{type_: "text", text: "Hello world"}]}],
    })

    t->expect(result)->Expect.toEqual({PromptEditor.text: "Hello world", fileAttachments: []})
  })

  test("expands pasted-text pills into prompt text", t => {
    let result = PromptEditor.serializePromptEditorContent({
      type_: "doc",
      content: [
        {
          type_: "paragraph",
          content: [
            {type_: "text", text: "Before "},
            {
              type_: "pastedText",
              attrs: Dict.fromArray([
                ("id", stringJson("p1")),
                ("text", stringJson("line 1\nline 2")),
                ("label", stringJson("Pasted ~2 lines")),
              ]),
            },
            {type_: "text", text: " after"},
          ],
        },
      ],
    })

    t
    ->expect(result)
    ->Expect.toEqual({PromptEditor.text: "Before line 1\nline 2 after", fileAttachments: []})
  })

  test("extracts file pills without adding label text", t => {
    let result = PromptEditor.serializePromptEditorContent({
      type_: "doc",
      content: [
        {
          type_: "paragraph",
          content: [
            {type_: "text", text: "see "},
            {
              type_: "fileAttachment",
              attrs: Dict.fromArray([
                ("id", stringJson("f1")),
                ("name", stringJson("screenshot.png")),
                ("mediaType", stringJson("image/png")),
                ("dataUrl", stringJson("data:image/png;base64,abc")),
              ]),
            },
            {type_: "text", text: " now"},
          ],
        },
      ],
    })

    t
    ->expect(result)
    ->Expect.toEqual({
      PromptEditor.text: "see  now",
      fileAttachments: [
        {
          PromptEditor.id: "f1",
          name: "screenshot.png",
          mediaType: "image/png",
          dataUrl: "data:image/png;base64,abc",
        },
      ],
    })
  })
})

describe("prompt editor file types", () => {
  test("exposes accepted file picker types", t => {
    t
    ->expect(PromptEditor.acceptedPromptFileTypesString)
    ->Expect.toBe("image/png,image/jpeg,image/gif,image/webp,application/pdf")
  })

  test("parses accepted media types", t => {
    t
    ->expect(PromptEditor.parseAcceptedMediaType("image/png"))
    ->Expect.toEqual(Some(PromptEditor.Png))
    t
    ->expect(PromptEditor.parseAcceptedMediaType("image/jpeg"))
    ->Expect.toEqual(Some(PromptEditor.Jpeg))
    t
    ->expect(PromptEditor.parseAcceptedMediaType("image/gif"))
    ->Expect.toEqual(Some(PromptEditor.Gif))
    t
    ->expect(PromptEditor.parseAcceptedMediaType("image/webp"))
    ->Expect.toEqual(Some(PromptEditor.Webp))
    t
    ->expect(PromptEditor.parseAcceptedMediaType("application/pdf"))
    ->Expect.toEqual(Some(PromptEditor.Pdf))
  })

  test("rejects unsupported media types", t => {
    t->expect(PromptEditor.parseAcceptedMediaType("text/plain"))->Expect.toBeNone
  })
})

describe("prompt paste handling", () => {
  test("treats short paste text as plain text", t => {
    t->expect(PromptEditor.isLongPromptPasteText("short pasted text"))->Expect.toBe(false)
    t->expect(PromptEditor.isLongPromptPasteText("line 1\nline 2"))->Expect.toBe(false)
  })

  test("treats three lines or more as long paste text", t => {
    t->expect(PromptEditor.isLongPromptPasteText("line 1\nline 2\nline 3"))->Expect.toBe(true)
  })

  test("treats more than 150 characters as long paste text", t => {
    t->expect(PromptEditor.isLongPromptPasteText("x"->String.repeat(151)))->Expect.toBe(true)
    t->expect(PromptEditor.isLongPromptPasteText("x"->String.repeat(150)))->Expect.toBe(false)
  })
})
