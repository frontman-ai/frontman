open Vitest

module PromptInput = Client__PromptInput

let asNode = WebAPI.Element.asNode
let asDomElement = WebAPI.Prelude.unsafeConversation

let text = value =>
  WebAPI.Global.document->WebAPI.Document.createTextNode(value)->WebAPI.Text.asNode

let body = (): WebAPI.DOMAPI.element =>
  WebAPI.Global.document->WebAPI.Document.body->Null.toOption->Option.getOrThrow

let getTextContentOrThrow = value =>
  value->WebAPI.Node.textContent->Null.toOption->Option.getOrThrow

let appendChildren = (parent: WebAPI.DOMAPI.element, children: array<WebAPI.DOMAPI.node>) => {
  children->Array.forEach(child =>
    parent->WebAPI.Element.asNode->WebAPI.Node.appendChild(child)->ignore
  )
  parent
}

let fileChip = id => {
  let chip = WebAPI.Global.document->WebAPI.Document.createElement("span")
  chip->WebAPI.Element.setAttribute(~qualifiedName="contenteditable", ~value="false")
  chip->WebAPI.Element.setAttribute(~qualifiedName="data-chip-id", ~value=id)
  chip->WebAPI.Element.setAttribute(~qualifiedName="data-chip-type", ~value="file")
  chip->WebAPI.Element.asNode->WebAPI.Node.appendChild(text("screenshot.png"))->ignore
  chip->asNode
}

let br = () => WebAPI.Global.document->WebAPI.Document.createElement("br")->asNode

let div = (children: array<WebAPI.DOMAPI.node>) => {
  let el = WebAPI.Global.document->WebAPI.Document.createElement("div")
  appendChildren(el, children)->ignore
  el->asNode
}

let editable = (children: array<WebAPI.DOMAPI.node>) => {
  let el = WebAPI.Global.document->WebAPI.Document.createElement("div")
  el->WebAPI.Element.setAttribute(~qualifiedName="contenteditable", ~value="true")
  appendChildren(el, children)
}

let selectionOrThrow = () => WebAPI.Global.getSelection()

let setCollapsedSelection = (node: WebAPI.DOMAPI.node, offset: int) => {
  let range = WebAPI.Global.document->WebAPI.Document.createRange
  range->WebAPI.Range.setStart(~node, ~offset)
  range->WebAPI.Range.collapse(~toStart=true)
  let selection = selectionOrThrow()
  selection->WebAPI.Selection.removeAllRanges
  selection->WebAPI.Selection.addRange(range)
}

let setSelectionRange = (node: WebAPI.DOMAPI.node, start: int, end_: int) => {
  let range = WebAPI.Global.document->WebAPI.Document.createRange
  range->WebAPI.Range.setStart(~node, ~offset=start)
  range->WebAPI.Range.setEnd(~node, ~offset=end_)
  let selection = selectionOrThrow()
  selection->WebAPI.Selection.removeAllRanges
  selection->WebAPI.Selection.addRange(range)
}

afterEach(() => {
  body().innerHTML = ""
  selectionOrThrow()->WebAPI.Selection.removeAllRanges
})

describe("getTextFromEditable", () => {
  test("returns plain text", t => {
    let el = editable([text("Hello world")])
    t->expect(PromptInput.getTextFromEditable(el->asDomElement))->Expect.toBe("Hello world")
  })

  test("skips file attachment chips", t => {
    let el = editable([text("text before "), fileChip("f1"), text(" text after")])
    t
    ->expect(PromptInput.getTextFromEditable(el->asDomElement))
    ->Expect.toBe("text before  text after")
  })

  test("handles BR elements as newlines", t => {
    let el = editable([text("line1"), br(), text("line2")])
    t->expect(PromptInput.getTextFromEditable(el->asDomElement))->Expect.toBe("line1\nline2")
  })

  test("handles DIV-wrapped lines", t => {
    let el = editable([div([text("first line")]), div([text("second line")])])
    t
    ->expect(PromptInput.getTextFromEditable(el->asDomElement))
    ->Expect.toBe("first line\nsecond line")
  })

  test("handles nested elements", t => {
    let span = WebAPI.Global.document->WebAPI.Document.createElement("span")
    span->WebAPI.Element.asNode->WebAPI.Node.appendChild(text("nested text"))->ignore
    let p = WebAPI.Global.document->WebAPI.Document.createElement("p")
    p->WebAPI.Element.asNode->WebAPI.Node.appendChild(span->asNode)->ignore
    let el = editable([p->asNode])
    t->expect(PromptInput.getTextFromEditable(el->asDomElement))->Expect.toBe("nested text")
  })
})

describe("insertNodeAtCursor", () => {
  test("inserts plain text at the current caret position", t => {
    let existingText = text("Hello ")
    let el = editable([existingText])
    body()->WebAPI.Element.asNode->WebAPI.Node.appendChild(el->asNode)->ignore

    setCollapsedSelection(existingText, existingText->getTextContentOrThrow->String.length)
    PromptInput.insertNodeAtCursor(text("world"))

    t->expect(el->asNode->getTextContentOrThrow)->Expect.toBe("Hello world")
    t->expect(PromptInput.getTextFromEditable(el->asDomElement))->Expect.toBe("Hello world")
  })

  test("inserts clipboard HTML as literal text, not rich content", t => {
    let existingText = text("Before after")
    let el = editable([existingText])
    body()->WebAPI.Element.asNode->WebAPI.Node.appendChild(el->asNode)->ignore

    setSelectionRange(existingText, 7, 12)
    PromptInput.insertNodeAtCursor(text("<b>bold</b>"))

    t->expect(el->WebAPI.Element.querySelector("b")->Null.toOption)->Expect.toBeNone
    t->expect(el->asNode->getTextContentOrThrow)->Expect.toBe("Before <b>bold</b>")
  })
})
