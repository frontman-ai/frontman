external asKeyboardEvent: WebAPI.EventTypes.event => WebAPI.UiEventsTypes.keyboardEvent =
  "%identity"

@get external eventTarget: WebAPI.EventTypes.event => Nullable.t<WebAPI.DomTypes.element> = "target"
@send external focus: WebAPI.DomTypes.element => unit = "focus"
@send external contains: (WebAPI.DomTypes.element, WebAPI.DomTypes.element) => bool = "contains"
@send
external removeAttribute: (WebAPI.DomTypes.element, string) => unit = "removeAttribute"

let isEditable: WebAPI.DomTypes.element => bool = %raw(`
  function(el) {
    const blocked = new Set(["SCRIPT","STYLE","INPUT","TEXTAREA","SELECT","OPTION","IFRAME","IMG","VIDEO","AUDIO","CANVAS","SVG","BR","HR"]);
    if (blocked.has(el.tagName) || el.closest("svg")) return false;
    for (let n = el.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === 3 && n.textContent.trim() !== "") return true;
    }
    return false;
  }
`)

type editing = {element: WebAPI.DomTypes.element, originalText: string}

// Clicking a text element makes it contenteditable;
// committing (blur/Enter/click elsewhere) records the edit as an annotation.
@react.component
let make = (~document: WebAPI.DomTypes.document) => {
  let editingRef: React.ref<option<editing>> = React.useRef(None)

  React.useEffect(() => {
    let doc = document

    let stopEditing = (~commit) => {
      switch editingRef.current {
      | Some({element, originalText}) =>
        editingRef.current = None
        element->removeAttribute("contenteditable")
        let newText = element.textContent->Null.getOr("")
        switch (commit, newText != originalText) {
        | (true, true) =>
          Client__State.Actions.addTextEditAnnotation(
            ~element,
            ~tagName=element.tagName,
            ~originalText,
            ~newText,
          )
        | (true, false) => ()
        | (false, _) => element.textContent = Value(originalText)
        }
      | None => ()
      }
    }

    let startEditing = element => {
      editingRef.current = Some({element, originalText: element.textContent->Null.getOr("")})
      element->WebAPI.Element.setAttribute(
        ~qualifiedName="contenteditable",
        ~value="plaintext-only",
      )
      element->focus
    }

    let isInsideEditing = target =>
      switch editingRef.current {
      | Some({element}) => element->contains(target)
      | None => false
      }

    let suppress = ev => {
      WebAPI.Event.preventDefault(ev)
      WebAPI.Event.stopImmediatePropagation(ev)
    }

    // Block the app's own mouse handling everywhere except inside the element
    // being edited (native mousedown there places the caret).
    let onMouseDown = ev => {
      switch ev->eventTarget->Nullable.toOption {
      | Some(target) if isInsideEditing(target) => ()
      | Some(_) | None => suppress(ev)
      }
    }

    let onClick = ev => {
      switch ev->eventTarget->Nullable.toOption {
      | Some(target) if isInsideEditing(target) => ()
      | Some(target) =>
        suppress(ev)
        stopEditing(~commit=true)
        switch isEditable(target) {
        | true => startEditing(target)
        | false => ()
        }
      | None =>
        suppress(ev)
        stopEditing(~commit=true)
      }
    }

    let onFocusOut = ev => {
      switch (ev->eventTarget->Nullable.toOption, editingRef.current) {
      | (Some(target), Some({element})) if target === element => stopEditing(~commit=true)
      | _ => ()
      }
    }

    let onKeyDown = ev => {
      let kbEv = ev->asKeyboardEvent
      switch (kbEv.key, kbEv.shiftKey, editingRef.current) {
      | ("Escape", _, Some(_)) =>
        suppress(ev)
        stopEditing(~commit=false)
      | ("Escape", _, None) => Client__State.Actions.toggleTextEditMode()
      | ("Enter", false, Some(_)) =>
        suppress(ev)
        stopEditing(~commit=true)
      | (_, _, Some(_)) =>
        WebAPI.Event.stopPropagation(ev)
      | _ => ()
      }
    }

    let styleEl = WebAPI.Document.createElement(doc, "style")
    WebAPI.Element.setAttribute(styleEl, ~qualifiedName="data-frontman-text-cursor", ~value="true")
    styleEl.textContent = Value("* { cursor: text !important; }")
    doc.head->WebAPI.HTMLHeadElement.appendChild(styleEl)->ignore

    WebAPI.Document.addEventListener(doc, Custom("mousedown"), onMouseDown, ~options={capture: true})
    WebAPI.Document.addEventListener(doc, Custom("click"), onClick, ~options={capture: true})
    WebAPI.Document.addEventListener(doc, Custom("focusout"), onFocusOut, ~options={capture: true})
    WebAPI.Document.addEventListener(doc, Custom("keydown"), onKeyDown, ~options={capture: true})
    let windowTarget = WebAPI.Window.current->WebAPI.Window.asEventTarget
    windowTarget->WebAPI.EventTarget.addEventListener(Keydown, onKeyDown)

    Some(
      () => {
        stopEditing(~commit=true)
        WebAPI.Document.removeEventListener(
          doc,
          Custom("mousedown"),
          onMouseDown,
          ~options={capture: true},
        )
        WebAPI.Document.removeEventListener(doc, Custom("click"), onClick, ~options={capture: true})
        WebAPI.Document.removeEventListener(
          doc,
          Custom("focusout"),
          onFocusOut,
          ~options={capture: true},
        )
        WebAPI.Document.removeEventListener(
          doc,
          Custom("keydown"),
          onKeyDown,
          ~options={capture: true},
        )
        windowTarget->WebAPI.EventTarget.removeEventListener(Keydown, onKeyDown)
        styleEl->WebAPI.Element.remove
      },
    )
  }, [document])

  React.null
}
