open Vitest

module PromptInput = Client__PromptInput

let asNode = WebAPI.Element.asNode
let asDomElement = WebAPI.Prelude.unsafeConversation

let text = value =>
  WebAPI.Global.document->WebAPI.Document.createTextNode(value)->WebAPI.Text.asNode

let _body = (): WebAPI.DOMAPI.element =>
  WebAPI.Global.document->WebAPI.Document.body->Null.toOption->Option.getOrThrow

let _getTextContentOrThrow = value =>
  value->WebAPI.Node.textContent->Null.toOption->Option.getOrThrow

let _appendChildren = (parent: WebAPI.DOMAPI.element, children: array<WebAPI.DOMAPI.node>) => {
  children->Array.forEach(child =>
    parent->WebAPI.Element.asNode->WebAPI.Node.appendChild(child)->ignore
  )
  parent
}

let _makeChip = (~id: string, ~chipType: string, ~label: string) => {
  let chip = WebAPI.Global.document->WebAPI.Document.createElement("span")
  chip->WebAPI.Element.setAttribute(~qualifiedName="contenteditable", ~value="false")
  chip->WebAPI.Element.setAttribute(~qualifiedName="data-chip-id", ~value=id)
  chip->WebAPI.Element.setAttribute(~qualifiedName="data-chip-type", ~value=chipType)
  chip->WebAPI.Element.asNode->WebAPI.Node.appendChild(text(label))->ignore
  chip->asNode
}

let pasteChip = id => _makeChip(~id, ~chipType="paste", ~label="Pasted chip " ++ id)

let fileChip = id => _makeChip(~id, ~chipType="file", ~label="screenshot.png")

let br = () => WebAPI.Global.document->WebAPI.Document.createElement("br")->asNode

let div = (children: array<WebAPI.DOMAPI.node>) => {
  let el = WebAPI.Global.document->WebAPI.Document.createElement("div")
  _appendChildren(el, children)->ignore
  el->asNode
}

let editable = (children: array<WebAPI.DOMAPI.node>) => {
  let el = WebAPI.Global.document->WebAPI.Document.createElement("div")
  el->WebAPI.Element.setAttribute(~qualifiedName="contenteditable", ~value="true")
  _appendChildren(el, children)
}

let _selectionOrThrow = () => WebAPI.Global.getSelection()

let setCollapsedSelection = (node: WebAPI.DOMAPI.node, offset: int) => {
  let range = WebAPI.Global.document->WebAPI.Document.createRange
  range->WebAPI.Range.setStart(~node, ~offset)
  range->WebAPI.Range.collapse(~toStart=true)
  let selection = _selectionOrThrow()
  selection->WebAPI.Selection.removeAllRanges
  selection->WebAPI.Selection.addRange(range)
}

let setSelectionRange = (node: WebAPI.DOMAPI.node, start: int, end_: int) => {
  let range = WebAPI.Global.document->WebAPI.Document.createRange
  range->WebAPI.Range.setStart(~node, ~offset=start)
  range->WebAPI.Range.setEnd(~node, ~offset=end_)
  let selection = _selectionOrThrow()
  selection->WebAPI.Selection.removeAllRanges
  selection->WebAPI.Selection.addRange(range)
}

let makeMap = (entries: array<(string, string)>) => {
  let map: Map.t<string, string> = Map.make()
  entries->Array.forEach(entry =>
    switch entry {
    | (key, value) => map->Map.set(key, value)
    }
  )
  map
}

afterEach(() => {
  _body().innerHTML = ""
  _selectionOrThrow()->WebAPI.Selection.removeAllRanges
})

describe("getExpandedTextFromEditable", () => {
  describe("happy path", () => {
    test(
      "returns plain text when there are no chips",
      t => {
        let el = editable([text("Hello world")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, makeMap([])))
        ->Expect.toBe("Hello world")
      },
    )

    test(
      "expands a single pasted-text chip inline",
      t => {
        let el = editable([text("Look at this: "), pasteChip("p1"), text(" What do you think?")])
        let map = makeMap([("p1", "def greet():\n  print('hi')")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("Look at this: def greet():\n  print('hi') What do you think?")
      },
    )

    test(
      "preserves ordering with chip between two text segments",
      t => {
        let el = editable([text("Before "), pasteChip("c1"), text(" After")])
        let map = makeMap([("c1", "MIDDLE CONTENT")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("Before MIDDLE CONTENT After")
      },
    )

    test(
      "handles multiple pasted-text chips in correct order",
      t => {
        let el = editable([text("A "), pasteChip("p1"), text(" B "), pasteChip("p2"), text(" C")])
        let map = makeMap([("p1", "FIRST"), ("p2", "SECOND")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("A FIRST B SECOND C")
      },
    )

    test(
      "handles chip at the very start",
      t => {
        let el = editable([pasteChip("p1"), text(" trailing text")])
        let map = makeMap([("p1", "LEADING")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("LEADING trailing text")
      },
    )

    test(
      "handles chip at the very end",
      t => {
        let el = editable([text("leading text "), pasteChip("p1")])
        let map = makeMap([("p1", "TRAILING")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("leading text TRAILING")
      },
    )

    test(
      "handles only a pasted-text chip with no typed text",
      t => {
        let el = editable([pasteChip("p1")])
        let map = makeMap([("p1", "just pasted content")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("just pasted content")
      },
    )

    test(
      "handles consecutive chips with no text between them",
      t => {
        let el = editable([pasteChip("p1"), pasteChip("p2")])
        let map = makeMap([("p1", "AAA"), ("p2", "BBB")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("AAABBB")
      },
    )
  })

  describe("file chip handling", () => {
    test(
      "skips file attachment chips entirely",
      t => {
        let el = editable([text("text before "), fileChip("f1"), text(" text after")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, makeMap([])))
        ->Expect.toBe("text before  text after")
      },
    )

    test(
      "expands paste chips but skips file chips in mixed content",
      t => {
        let el = editable([text("A "), fileChip("f1"), text(" B "), pasteChip("p1"), text(" C")])
        let map = makeMap([("p1", "PASTED")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("A  B PASTED C")
      },
    )
  })

  describe("edge cases", () => {
    test(
      "returns empty string for empty editable",
      t => {
        let el = editable([])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, makeMap([])))
        ->Expect.toBe("")
      },
    )

    test(
      "handles BR elements as newlines",
      t => {
        let el = editable([text("line1"), br(), text("line2")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, makeMap([])))
        ->Expect.toBe("line1\nline2")
      },
    )

    test(
      "handles DIV-wrapped lines (browser contentEditable behavior)",
      t => {
        let el = editable([div([text("first line")]), div([text("second line")])])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, makeMap([])))
        ->Expect.toBe("first line\nsecond line")
      },
    )

    test(
      "handles paste chip inside a DIV wrapper",
      t => {
        let el = editable([div([text("before "), pasteChip("p1"), text(" after")])])
        let map = makeMap([("p1", "INLINE")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("before INLINE after")
      },
    )

    test(
      "handles chip with missing map entry (not in map) — treated as skipped",
      t => {
        let el = editable([text("before "), pasteChip("orphan"), text(" after")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, makeMap([])))
        ->Expect.toBe("before  after")
      },
    )

    test(
      "handles multiline pasted content preserving internal newlines",
      t => {
        let el = editable([text("intro "), pasteChip("p1"), text(" outro")])
        let map = makeMap([("p1", "line 1\nline 2\nline 3")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("intro line 1\nline 2\nline 3 outro")
      },
    )

    test(
      "handles whitespace-only typed text around chips",
      t => {
        let el = editable([text("  "), pasteChip("p1"), text("  ")])
        let map = makeMap([("p1", "content")])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, map))
        ->Expect.toBe("  content  ")
      },
    )

    test(
      "handles deeply nested elements (P > span > text)",
      t => {
        let span = WebAPI.Global.document->WebAPI.Document.createElement("span")
        span->WebAPI.Element.asNode->WebAPI.Node.appendChild(text("nested text"))->ignore
        let p = WebAPI.Global.document->WebAPI.Document.createElement("p")
        p->WebAPI.Element.asNode->WebAPI.Node.appendChild(span->asNode)->ignore
        let el = editable([p->asNode])
        t
        ->expect(PromptInput.getExpandedTextFromEditable(el->asDomElement, makeMap([])))
        ->Expect.toBe("nested text")
      },
    )
  })
})

describe("getTextFromEditable", () => {
  test("extracts plain text and skips all chip types", t => {
    let el = editable([
      text("Hello "),
      pasteChip("p1"),
      text(" World "),
      fileChip("f1"),
      text(" End"),
    ])
    t->expect(PromptInput.getTextFromEditable(el->asDomElement))->Expect.toBe("Hello  World  End")
  })

  test("returns empty string for empty editable", t => {
    let el = editable([])
    t->expect(PromptInput.getTextFromEditable(el->asDomElement))->Expect.toBe("")
  })

  test("handles BR as newline", t => {
    let el = editable([text("a"), br(), text("b")])
    t->expect(PromptInput.getTextFromEditable(el->asDomElement))->Expect.toBe("a\nb")
  })

  test("handles DIV line wrapping", t => {
    let el = editable([div([text("line 1")]), div([text("line 2")])])
    t->expect(PromptInput.getTextFromEditable(el->asDomElement))->Expect.toBe("line 1\nline 2")
  })
})

describe("insertNodeAtCursor", () => {
  test("inserts plain text at the current caret position", t => {
    let existingText = text("Hello ")
    let el = editable([existingText])
    _body()->WebAPI.Element.asNode->WebAPI.Node.appendChild(el->asNode)->ignore

    setCollapsedSelection(existingText, existingText->_getTextContentOrThrow->String.length)
    PromptInput.insertNodeAtCursor(text("world"))

    t->expect(el->asNode->_getTextContentOrThrow)->Expect.toBe("Hello world")
    t->expect(PromptInput.getTextFromEditable(el->asDomElement))->Expect.toBe("Hello world")
  })

  test("inserts clipboard HTML as literal text, not rich content", t => {
    let existingText = text("Before after")
    let el = editable([existingText])
    _body()->WebAPI.Element.asNode->WebAPI.Node.appendChild(el->asNode)->ignore

    setSelectionRange(existingText, 7, 12)
    PromptInput.insertNodeAtCursor(text("<b>bold</b>"))

    t->expect(el->WebAPI.Element.querySelector("b")->Null.toOption)->Expect.toBeNone
    t->expect(el->asNode->_getTextContentOrThrow)->Expect.toBe("Before <b>bold</b>")
  })
})
