module Dom = FrontmanBindings.Bindings__WebAPI
module Object = FrontmanBindings.Bindings__Object

type field =
  | Input(WebAPI.DomTypes.htmlInputElement)
  | TextArea(WebAPI.DomTypes.htmlTextAreaElement)
  | Editable

let attribute = (el, name) => el->WebAPI.Element.getAttribute(name)->Null.toOption

let unavailable = (el: WebAPI.DomTypes.element): bool =>
  el->WebAPI.Element.matches(":disabled") ||
    el->WebAPI.Element.closest("[inert], [aria-disabled='true']")->Null.toOption->Option.isSome

let classify = (el: WebAPI.DomTypes.element): result<field, string> =>
  switch true {
  | _ if unavailable(el) => Error("Cannot fill a disabled or inert element")
  | _ if el->WebAPI.Element.closest("[aria-readonly='true']")->Null.toOption->Option.isSome =>
    Error("Cannot fill a read-only element")
  | _ if el.tagName === "INPUT" =>
    let input = el->Dom.unsafeInputElementFromElement
    switch input.readOnly {
    | true => Error("Cannot fill a read-only element")
    | false =>
      switch input.type_ {
      | "text" | "search" | "email" | "url" | "tel" | "password" => Ok(Input(input))
      | type_ => Error(`Unsupported input type for fill: ${type_}`)
      }
    }
  | _ if el.tagName === "TEXTAREA" =>
    let textarea = el->Dom.unsafeTextAreaElementFromElement
    switch textarea.readOnly {
    | true => Error("Cannot fill a read-only element")
    | false => Ok(TextArea(textarea))
    }
  | _ =>
    switch (
      attribute(el, "contenteditable"),
      (el->Dom.unsafeHtmlElementFromElement).isContentEditable,
    ) {
    | (Some("" | "true" | "plaintext-only"), true) => Ok(Editable)
    | _ => Error("Fill requires a text input, textarea, or contenteditable editing host")
    }
  }

let read = (el, field) =>
  switch field {
  | Input(input) => input.value
  | TextArea(textarea) => textarea.value
  | Editable =>
    let text = Client__Tool__ElementQuery.getVisibleText(el)->String.replaceAll("\r\n", "\n")
    switch text === "\n" &&
    (el :> WebAPI.DomTypes.node).textContent->Null.toOption === Some("") &&
    el->WebAPI.Element.querySelectorAll("br")->WebAPI.NodeList.toArray->Array.length === 1 {
    | true => ""
    | false => text
    }
  }

let edit = async (~doc, ~win, ~el, ~field, ~value) => {
  el->Dom.unsafeHtmlElementFromElement->WebAPI.HTMLElement.focus
  switch el->WebAPI.Element.matches(":focus") {
  | false => Error("Element did not accept focus; no content was filled")
  | true if read(el, field) === value => Ok()
  | true =>
    switch field {
    | Input(_) | TextArea(_) =>
      switch field {
      | Input(input) => input->WebAPI.HTMLInputElement.select
      | TextArea(textarea) => textarea->WebAPI.HTMLTextAreaElement.select
      | Editable => ()
      }
      let edited = switch doc->Dom.hasExecCommand {
      | Some(_) => Dom.execCommand(doc, value === "" ? "delete" : "insertText", false, value)
      | None => false
      }
      switch edited {
      | true => Ok()
      | false =>
        let constructor =
          el.tagName === "INPUT" ? Dom.inputConstructor(win) : Dom.textareaConstructor(win)
        constructor
        ->Object.prototype
        ->Object.getOwnPropertyDescriptor("value")
        ->Option.getOrThrow
        ->Object.setter
        ->Option.getOrThrow
        ->Object.callSetter(el, value)
        (el :> WebAPI.EventTypes.eventTarget)
        ->WebAPI.EventTarget.dispatchEvent(
          Dom.inputEvent(
            Dom.inputEventConstructor(win),
            (
              "input",
              {
                bubbles: true,
                inputType: value === "" ? "deleteContentBackward" : "insertText",
                data: Null.make(value),
              },
            ),
          ),
        )
        ->ignore
        Ok()
      }
    | Editable =>
      switch doc->Dom.hasExecCommand {
      | None => Error("This browser does not provide native contenteditable editing")
      | Some(_) =>
        let selection = doc->WebAPI.Document.getSelection->Null.toOption->Option.getOrThrow
        let range = doc->WebAPI.Document.createRange
        range->WebAPI.Range.selectNodeContents((el :> WebAPI.DomTypes.node))
        selection->WebAPI.Selection.removeAllRanges
        selection->WebAPI.Selection.addRange(range)
        await Promise.make((resolve, _) => setTimeout(() => resolve(), 0)->ignore)
        let handled = switch value === "" {
        | true =>
          !(
            (el :> WebAPI.EventTypes.eventTarget)->WebAPI.EventTarget.dispatchEvent(
              Dom.keyboardEvent(
                Dom.keyboardConstructor(win),
                (
                  "keydown",
                  {
                    bubbles: true,
                    cancelable: true,
                    key: "Backspace",
                    code: "Backspace",
                    keyCode: 8,
                    which: 8,
                  },
                ),
              ),
            )
          )

        | false =>
          let data = Dom.transfer(Dom.transferConstructor(win), [])
          data->WebAPI.DataTransfer.setData(~format="text/plain", ~data=value)
          !(
            (el :> WebAPI.EventTypes.eventTarget)->WebAPI.EventTarget.dispatchEvent(
              Dom.clipboardEvent(
                Dom.clipboardConstructor(win),
                ("paste", {bubbles: true, cancelable: true, clipboardData: Null.make(data)}),
              ),
            )
          )
        }
        switch handled ||
        Dom.execCommand(doc, value === "" ? "delete" : "insertText", false, value) {
        | true => Ok()
        | false =>
          Error("Browser rejected native contenteditable editing; no DOM fallback was applied")
        }
      }
    }
  }
}

/// ponytail: 50ms catches immediate reverts; save/readback verifies delayed changes and persistence.
let fill = async (~doc, ~win, ~el, ~value): result<unit, string> => {
  switch classify(el) {
  | Error(message) => Error(message)
  | Ok(Input(input)) if input.maxLength >= 0 && value->String.length > input.maxLength =>
    Error("Fill value exceeds the field's maxlength; no content was filled")
  | Ok(TextArea(textarea))
    if textarea.maxLength >= 0 && value->String.length > textarea.maxLength =>
    Error("Fill value exceeds the field's maxlength; no content was filled")
  | Ok(field) =>
    switch await edit(~doc, ~win, ~el, ~field, ~value) {
    | Error(message) => Error(message)
    | Ok() =>
      switch field {
      | Input(_) | TextArea(_) =>
        (el :> WebAPI.EventTypes.eventTarget)
        ->WebAPI.EventTarget.dispatchEvent(
          Dom.event(Dom.eventConstructor(win), ("change", {bubbles: true})),
        )
        ->ignore
      | Editable => ()
      }
      el->Dom.unsafeHtmlElementFromElement->WebAPI.HTMLElement.blur
      await Promise.make((resolve, _reject) => {
        setTimeout(() => resolve(), 50)->ignore
      })
      switch (el :> WebAPI.DomTypes.node).isConnected && read(el, field) === value {
      | true => Ok()
      | false =>
        Error(
          "Filled value was not accepted after input/change and blur; persistence is not verified",
        )
      }
    }
  }
}
