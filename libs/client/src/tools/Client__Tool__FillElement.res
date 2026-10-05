type field = TextControl | Editable

type constructor
type prototype
type descriptor
type setter

@get external inputConstructor: WebAPI.DomTypes.window => constructor = "HTMLInputElement"
@get external textareaConstructor: WebAPI.DomTypes.window => constructor = "HTMLTextAreaElement"
@get external prototype: constructor => prototype = "prototype"
@scope("Object") @val
external getDescriptor: (prototype, string) => option<descriptor> = "getOwnPropertyDescriptor"
@get external setter: descriptor => option<setter> = "set"
@send external setValue: (setter, WebAPI.DomTypes.element, string) => unit = "call"
@get external value: WebAPI.DomTypes.element => string = "value"
@get external inputType: WebAPI.DomTypes.element => string = "type"
@get external readOnly: WebAPI.DomTypes.element => bool = "readOnly"
@get external maxLength: WebAPI.DomTypes.element => int = "maxLength"
@get external isContentEditable: WebAPI.DomTypes.element => bool = "isContentEditable"
@send external focus: WebAPI.DomTypes.element => unit = "focus"
@send external blur: WebAPI.DomTypes.element => unit = "blur"
@send external select: WebAPI.DomTypes.element => unit = "select"
@send
external execCommand: (WebAPI.DomTypes.document, string, bool, string) => bool = "execCommand"
type command
type inputEventInit = {bubbles: bool, inputType: string, data: string}
@get external hasExecCommand: WebAPI.DomTypes.document => option<command> = "execCommand"
@get external inputEventConstructor: WebAPI.DomTypes.window => constructor = "InputEvent"
@get external eventConstructor: WebAPI.DomTypes.window => constructor = "Event"
@scope("Reflect") @val
external inputEvent: (constructor, (string, inputEventInit)) => WebAPI.EventTypes.event =
  "construct"
type transfer
@get external transferConstructor: WebAPI.DomTypes.window => constructor = "DataTransfer"
@get external clipboardConstructor: WebAPI.DomTypes.window => constructor = "ClipboardEvent"
@scope("Reflect") @val external transfer: (constructor, array<string>) => transfer = "construct"
@send external setData: (transfer, string, string) => unit = "setData"
type clipboardInit = {bubbles: bool, cancelable: bool, clipboardData: transfer}
@scope("Reflect") @val
external clipboardEvent: (constructor, (string, clipboardInit)) => WebAPI.EventTypes.event =
  "construct"

type keyInit = {
  bubbles: bool,
  cancelable: bool,
  key: string,
  code: string,
  keyCode: int,
  which: int,
}
@get external keyboardConstructor: WebAPI.DomTypes.window => constructor = "KeyboardEvent"
@scope("Reflect") @val
external keyboardEvent: (constructor, (string, keyInit)) => WebAPI.EventTypes.event = "construct"

type eventInit = {bubbles: bool}
@scope("Reflect") @val
external event: (constructor, (string, eventInit)) => WebAPI.EventTypes.event = "construct"

let attribute = (el, name) => el->WebAPI.Element.getAttribute(name)->Null.toOption

let unavailable = (el: WebAPI.DomTypes.element): bool =>
  el->WebAPI.Element.matches(":disabled") ||
    el->WebAPI.Element.closest("[inert], [aria-disabled='true']")->Null.toOption->Option.isSome

let classify = (el: WebAPI.DomTypes.element): result<field, string> =>
  switch true {
  | _ if unavailable(el) => Error("Cannot fill a disabled or inert element")
  | _ if el->WebAPI.Element.closest("[aria-readonly='true']")->Null.toOption->Option.isSome =>
    Error("Cannot fill a read-only element")
  | _ if el.tagName === "INPUT" || el.tagName === "TEXTAREA" =>
    switch true {
    | _ if readOnly(el) => Error("Cannot fill a read-only element")
    | _ if el.tagName === "TEXTAREA" => Ok(TextControl)
    | _ =>
      switch inputType(el) {
      | "text" | "search" | "email" | "url" | "tel" | "password" => Ok(TextControl)
      | type_ => Error(`Unsupported input type for fill: ${type_}`)
      }
    }
  | _ =>
    switch (attribute(el, "contenteditable"), isContentEditable(el)) {
    | (Some("" | "true" | "plaintext-only"), true) => Ok(Editable)
    | _ => Error("Fill requires a text input, textarea, or contenteditable editing host")
    }
  }

let read = (el, field) =>
  switch field {
  | TextControl => value(el)
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
  focus(el)
  switch el->WebAPI.Element.matches(":focus") {
  | false => Error("Element did not accept focus; no content was filled")
  | true if read(el, field) === value => Ok()
  | true =>
    switch field {
    | TextControl =>
      select(el)
      let edited = switch hasExecCommand(doc) {
      | Some(_) => execCommand(doc, value === "" ? "delete" : "insertText", false, value)
      | None => false
      }
      switch edited {
      | true => Ok()
      | false =>
        let constructor = el.tagName === "INPUT" ? inputConstructor(win) : textareaConstructor(win)
        constructor
        ->prototype
        ->getDescriptor("value")
        ->Option.getOrThrow
        ->setter
        ->Option.getOrThrow
        ->setValue(el, value)
        (el :> WebAPI.EventTypes.eventTarget)
        ->WebAPI.EventTarget.dispatchEvent(
          inputEvent(
            inputEventConstructor(win),
            (
              "input",
              {
                bubbles: true,
                inputType: value === "" ? "deleteContentBackward" : "insertText",
                data: value,
              },
            ),
          ),
        )
        ->ignore
        Ok()
      }
    | Editable =>
      switch hasExecCommand(doc) {
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
              keyboardEvent(
                keyboardConstructor(win),
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
          let data = transfer(transferConstructor(win), [])
          setData(data, "text/plain", value)
          !(
            (el :> WebAPI.EventTypes.eventTarget)->WebAPI.EventTarget.dispatchEvent(
              clipboardEvent(
                clipboardConstructor(win),
                ("paste", {bubbles: true, cancelable: true, clipboardData: data}),
              ),
            )
          )
        }
        switch handled || execCommand(doc, value === "" ? "delete" : "insertText", false, value) {
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
  | Ok(TextControl) if maxLength(el) >= 0 && value->String.length > maxLength(el) =>
    Error("Fill value exceeds the field's maxlength; no content was filled")
  | Ok(field) =>
    switch await edit(~doc, ~win, ~el, ~field, ~value) {
    | Error(message) => Error(message)
    | Ok() =>
      switch field {
      | TextControl =>
        (el :> WebAPI.EventTypes.eventTarget)
        ->WebAPI.EventTarget.dispatchEvent(
          event(eventConstructor(win), ("change", {bubbles: true})),
        )
        ->ignore
      | Editable => ()
      }
      blur(el)
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
