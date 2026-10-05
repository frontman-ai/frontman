module Dom = FrontmanBindings.Bindings__WebAPI
module Object = FrontmanBindings.Bindings__Object

type field =
  | Input(WebAPI.DomTypes.htmlInputElement)
  | TextArea(WebAPI.DomTypes.htmlTextAreaElement)
  | Editable

let unavailable = (el: WebAPI.DomTypes.element): bool =>
  el->WebAPI.Element.matches(":disabled") ||
    el->WebAPI.Element.closest("[inert], [aria-disabled='true']")->Null.toOption->Option.isSome

let classify = (el: WebAPI.DomTypes.element, ~value=""): result<field, string> => {
  let field = switch true {
  | _ if unavailable(el) => Error("Cannot fill a disabled or inert element")
  | _
    if el->WebAPI.Element.matches("input[readonly], textarea[readonly]") ||
      el->WebAPI.Element.closest("[aria-readonly='true']")->Null.toOption->Option.isSome =>
    Error("Cannot fill a read-only element")
  | _ if el.tagName === "INPUT" =>
    let input = el->Dom.unsafeInputElementFromElement
    switch input.type_ {
    | "text" | "search" | "email" | "url" | "tel" | "password" => Ok(Input(input))
    | type_ => Error(`Unsupported input type for fill: ${type_}`)
    }
  | _ if el.tagName === "TEXTAREA" => Ok(TextArea(el->Dom.unsafeTextAreaElementFromElement))
  | _ if Client__Tool__ElementQuery.isEditingHost(el) => Ok(Editable)
  | _ => Error("Fill requires a text input, textarea, or contenteditable editing host")
  }
  switch field {
  | Ok(Input({maxLength})) | Ok(TextArea({maxLength}))
    if maxLength >= 0 && value->String.length > maxLength =>
    Error("Fill value exceeds the field's maxlength; no content was filled")
  | result => result
  }
}

let read = (el, field) =>
  switch field {
  | Input({value}) | TextArea({value}) => value
  | Editable =>
    let text = Client__Tool__ElementQuery.getVisibleText(el)->String.replaceAll("\r\n", "\n")
    switch text === "\n" &&
    (el :> WebAPI.DomTypes.node).textContent->Null.toOption === Some("") &&
    el->WebAPI.Element.querySelectorAll("br")->WebAPI.NodeList.toArray->Array.length === 1 {
    | true => ""
    | false => text
    }
  }

let dispatch = (el: WebAPI.DomTypes.element, event) =>
  (el :> WebAPI.EventTypes.eventTarget)->WebAPI.EventTarget.dispatchEvent(event)

/// Focus, selection and editor callbacks can change the target before a document-wide command.
let validate = (~doc, ~el, ~value, ~selection=false) =>
  classify(el, ~value)->Result.flatMap(field =>
    switch field {
    | _ if !(el :> WebAPI.DomTypes.node).isConnected || !(el->WebAPI.Element.matches(":focus")) =>
      Error("Element lost connection or focus; no content was filled")
    | Editable if selection =>
      switch doc->WebAPI.Document.getSelection->Null.toOption {
      | Some(selection)
        if selection.rangeCount === 1 &&
          (el :> WebAPI.DomTypes.node)->WebAPI.Node.contains(
            (selection->WebAPI.Selection.getRangeAt(0)).commonAncestorContainer,
          ) =>
        Ok()
      | _ => Error("Selection left the editing host; no native edit was applied")
      }
    | Input(_) | TextArea(_) | Editable => Ok()
    }
  )

let edit = async (~doc, ~win, ~el: WebAPI.DomTypes.element, ~field, ~value) => {
  let constructor = switch field {
  | Input(input) =>
    input->WebAPI.HTMLInputElement.select
    Some(Dom.inputConstructor(win))
  | TextArea(textarea) =>
    textarea->WebAPI.HTMLTextAreaElement.select
    Some(Dom.textareaConstructor(win))
  | Editable =>
    let selection = doc->WebAPI.Document.getSelection->Null.toOption->Option.getOrThrow
    let range = doc->WebAPI.Document.createRange
    range->WebAPI.Range.selectNodeContents((el :> WebAPI.DomTypes.node))
    selection->WebAPI.Selection.removeAllRanges
    selection->WebAPI.Selection.addRange(range)
    /// Draft must synchronize its selection before receiving paste/delete.
    await Promise.make((resolve, _) => setTimeout(() => resolve(), 0)->ignore)
    None
  }
  validate(~doc, ~el, ~value, ~selection=true)->Result.flatMap(_ => {
    let handled = switch constructor {
    | Some(_) => false
    | None =>
      let event = switch value === "" {
      | true =>
        let eventInit: WebAPI.UiEventsTypes.keyboardEventInit = {
          bubbles: true,
          cancelable: true,
          key: "Backspace",
          code: "Backspace",
          keyCode: 8,
          which: 8,
        }
        Dom.keyboardEvent(Dom.keyboardConstructor(win), ("keydown", eventInit))
      | false =>
        let data = Dom.transfer(Dom.transferConstructor(win), [])
        data->WebAPI.DataTransfer.setData(~format="text/plain", ~data=value)
        let eventInit: WebAPI.UiEventsTypes.clipboardEventInit = {
          bubbles: true,
          cancelable: true,
          clipboardData: Null.make(data),
        }
        Dom.clipboardEvent(Dom.clipboardConstructor(win), ("paste", eventInit))
      }
      !dispatch(el, event)
    }
    switch handled {
    | true => Ok()
    | false =>
      validate(~doc, ~el, ~value, ~selection=true)->Result.flatMap(_ => {
        switch doc->Dom.hasExecCommand {
        | Some(_) if Dom.execCommand(doc, value === "" ? "delete" : "insertText", false, value) =>
          Ok()
        | None | Some(_) =>
          switch constructor {
          | None =>
            Error("Browser rejected native contenteditable editing; no DOM fallback was applied")
          | Some(constructor) =>
            validate(~doc, ~el, ~value)->Result.map(
              _ => {
                constructor
                ->Object.prototype
                ->Object.getOwnPropertyDescriptor("value")
                ->Option.getOrThrow
                ->Object.setter
                ->Option.getOrThrow
                ->Object.callSetter(el, value)
                let eventInit: WebAPI.UiEventsTypes.inputEventInit = {
                  bubbles: true,
                  inputType: value === "" ? "deleteContentBackward" : "insertText",
                  data: Null.make(value),
                }
                dispatch(
                  el,
                  Dom.inputEvent(Dom.inputEventConstructor(win), ("input", eventInit)),
                )->ignore
              },
            )
          }
        }
      })
    }
  })
}

/// ponytail: 50ms catches immediate reverts; save/readback verifies delayed changes and persistence.
let fill = async (
  ~doc: WebAPI.DomTypes.document,
  ~win: WebAPI.DomTypes.window,
  ~el: WebAPI.DomTypes.element,
  ~value: string,
): result<unit, string> => {
  switch classify(el, ~value) {
  | Error(message) => Error(message)
  | Ok(field) =>
    el->Dom.unsafeHtmlElementFromElement->WebAPI.HTMLElement.focus
    let result = switch validate(~doc, ~el, ~value) {
    | Error(message) => Error(message)
    | Ok() if read(el, field) === value => Ok()
    | Ok() => await edit(~doc, ~win, ~el, ~field, ~value)
    }
    switch result {
    | Error(message) => Error(message)
    | Ok() =>
      switch field {
      | Input(_) | TextArea(_) =>
        dispatch(el, Dom.event(Dom.eventConstructor(win), ("change", {bubbles: true})))->ignore
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
