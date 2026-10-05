module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool

let name = Tool.ToolNames.interactWithElement
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.ReadWrite
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = `Interact with an element in the web preview. Supports click, hover, focus, and fill actions.

Element targeting (use one strategy):
1. **selector** (preferred): CSS selector — use when you have a selector from get_interactive_elements or the user's selected element context
2. **role + name** (both required): ARIA role and accessible name — e.g. role="button", name="Submit Order"
3. **text**: Visible text content — matches the innermost element containing the text

Actions:
- **click** (default): Click the element
- **hover**: Trigger mouseenter/mouseover events on the element
- **focus**: Focus the element
- **fill**: Replace all text in an input, textarea, or contenteditable editing host. Requires **value** (empty string clears). **text** is only for targeting. Checks observed field content after events and blur, not arbitrary application state or persistence; save separately and read back.

Examples:
- Click by selector: {"selector": "#submit-btn", "action": "click"}
- Click by role+name: {"role": "button", "name": "Submit Order", "action": "click"}
- Click by text: {"text": "Learn more", "action": "click"}
- Hover by selector: {"selector": ".dropdown-trigger", "action": "hover"}
- Focus an input: {"role": "textbox", "name": "Email", "action": "focus"}
- Fill an input: {"selector": "#email", "action": "fill", "value": "user@example.com"}
- Clear an input: {"selector": "#email", "action": "fill", "value": ""}

When multiple elements match, use the index parameter (0-based) to select which one.`

@schema
type input = {
  @s.describe(
    "CSS selector to target the element (preferred — from get_interactive_elements or user context)"
  )
  selector: option<string>,
  @s.describe(
    "ARIA role of the target element (e.g. 'button', 'link', 'textbox'). Must be used together with 'name'."
  )
  role: option<string>,
  @s.describe(
    "Accessible name of the target element (e.g. 'Submit Order'). Must be used together with 'role'."
  )
  name: option<string>,
  @s.describe("Visible text content to match (finds the innermost element containing this text)")
  text: option<string>,
  @s.describe("Interaction type: 'click' (default), 'hover', 'focus', or 'fill'")
  action: option<[#click | #hover | #focus | #fill]>,
  @s.describe(
    "Required for fill: entire replacement text. Empty string clears. Not used for targeting."
  )
  value: option<string>,
  @s.describe("0-based index when multiple elements match (default: 0, i.e. first match)")
  index: option<int>,
}

@schema
type output = {
  @s.describe("Whether the interaction was performed successfully") @live
  success: bool,
  @s.describe("Description of the element that was interacted with") @live
  interactedElement: option<string>,
  @s.describe("The action that was performed: 'clicked', 'hovered', 'focused', or 'filled'") @live
  action: option<string>,
  @s.describe("Total number of elements that matched the targeting criteria") @live
  matchCount: option<int>,
  @s.describe("Error message if the interaction failed") @live
  error: option<string>,
}

let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

let dispatchHoverEvents = (el: WebAPI.DomTypes.element): unit => {
  let enterEvt = WebAPI.MouseEvent.make(
    ~type_="mouseenter",
    ~eventInitDict={bubbles: false, cancelable: false},
  )
  let overEvt = WebAPI.MouseEvent.make(
    ~type_="mouseover",
    ~eventInitDict={bubbles: true, cancelable: true},
  )
  let target = (el :> WebAPI.EventTypes.eventTarget)
  target->WebAPI.EventTarget.dispatchEvent(enterEvt->WebAPI.MouseEvent.asEvent)->ignore
  target->WebAPI.EventTarget.dispatchEvent(overEvt->WebAPI.MouseEvent.asEvent)->ignore
}

let actionToString = (action: [#click | #hover | #focus | #fill]): string =>
  switch action {
  | #click => "clicked"
  | #hover => "hovered"
  | #focus => "focused"
  | #fill => "filled"
  }

let performAction = async (~doc, ~win, ~el, ~action, ~value): result<unit, string> =>
  switch action {
  | #fill =>
    switch value {
    | None => Error("'value' is required for fill (use an empty string to clear)")
    | Some(value) => await Client__Tool__FillElement.fill(~doc, ~win, ~el, ~value)
    }
  | #click if Client__Tool__FillElement.unavailable(el) =>
    Error("Cannot click a disabled or inert element")
  | #click =>
    let observed = ref(false)
    let listener = _event => observed := true
    let target = (el :> WebAPI.EventTypes.eventTarget)
    target->WebAPI.EventTarget.addEventListener(Click, listener, ~options={capture: true})
    try {
      el->FrontmanBindings.Bindings__WebAPI.unsafeHtmlElementFromElement->WebAPI.HTMLElement.click
    } catch {
    | exn =>
      target->WebAPI.EventTarget.removeEventListener(Click, listener, ~options={capture: true})
      throw(exn)
    }
    target->WebAPI.EventTarget.removeEventListener(Click, listener, ~options={capture: true})
    switch observed.contents {
    | true => Ok()
    | false => Error("Element did not dispatch a click; interaction was not performed")
    }
  | #hover =>
    dispatchHoverEvents(el)
    Ok()
  | #focus =>
    el->FrontmanBindings.Bindings__WebAPI.unsafeHtmlElementFromElement->WebAPI.HTMLElement.focus
    switch el->WebAPI.Element.matches(":focus") {
    | true => Ok()
    | false => Error("Element did not accept focus")
    }
  }

type resolution =
  | Error(string)
  | Resolved({element: option<WebAPI.DomTypes.element>, matchCount: int})

let resolveTarget = (
  ~doc: WebAPI.DomTypes.document,
  ~contentWindow: WebAPI.DomTypes.window,
  ~input: input,
  ~index: int,
): resolution =>
  switch input.selector {
  | Some(selector) =>
    let (element, matchCount) = Client__Tool__SelectorResolver.resolveBySelector(
      ~doc,
      ~selector,
      ~index,
    )
    Resolved({element, matchCount})
  | None =>
    switch (input.role, input.name) {
    | (Some(role), Some(name)) =>
      let (element, matchCount) = Client__Tool__ElementQuery.resolveByRoleAndName(
        ~document=doc,
        ~contentWindow,
        ~role,
        ~name,
        ~index,
      )
      Resolved({element, matchCount})
    | (Some(_), None) | (None, Some(_)) =>
      Error("Both 'role' and 'name' are required when using role-based targeting")
    | (None, None) =>
      switch input.text {
      | Some(text) if text->String.trim === "" => Error("Text targeting cannot be empty")
      | Some(text) =>
        let matches = Client__Tool__ElementQuery.findMatchingElements(
          ~root=doc.body->WebAPI.HTMLElement.asElement,
          ~query=text,
        )
        Resolved({element: matches->Array.get(index), matchCount: matches->Array.length})
      | None =>
        Error(
          "No targeting strategy provided. Use 'selector', 'role'+'name', or 'text' to identify the element.",
        )
      }
    }
  }

let errorResult = (error: string, ~matchCount: option<int>=?): Tool.MCP.CallToolResult.t =>
  Tool.structuredResult(
    {
      success: false,
      interactedElement: None,
      action: None,
      matchCount,
      error: Some(error),
    },
    outputSchema,
    ~isError=true,
  )

let execute = async (
  input: input,
  ~taskId as _taskId: string,
  ~toolCallId as _toolCallId: string,
): Tool.MCP.CallToolResult.t => {
  let action = input.action->Option.getOr(#click)
  let index = Math.Int.max(0, input.index->Option.getOr(0))

  await Client__Tool__PreviewContext.withPreview(
    ~onUnavailable=async () => errorResult("Preview frame document not available"),
    async ({doc, win}) => {
      try {
        switch resolveTarget(~doc, ~contentWindow=win, ~input, ~index) {
        | Error(msg) => errorResult(msg)
        | Resolved({element: None, matchCount: 0}) =>
          errorResult("No element found matching the given criteria", ~matchCount=0)
        | Resolved({element: None, matchCount}) =>
          errorResult(
            `Index ${Int.toString(index)} out of range. Found ${Int.toString(
                matchCount,
              )} element(s) matching the given criteria`,
            ~matchCount,
          )
        | Resolved({element: Some(el), matchCount}) =>
          switch await performAction(~doc, ~win, ~el, ~action, ~value=input.value) {
          | Error(message) => errorResult(message, ~matchCount)
          | Ok() =>
            let role = Client__Tool__ElementQuery.effectiveRole(el)
            Tool.structuredResult(
              {
                success: true,
                interactedElement: Some(
                  switch FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(el) {
                  | "" => role
                  | name => `${role} '${name}'`
                  },
                ),
                action: Some(actionToString(action)),
                matchCount: Some(matchCount),
                error: None,
              },
              outputSchema,
            )
          }
        }
      } catch {
      | exn => errorResult(Client__Tool__PreviewContext.exnMessage(exn))
      }
    },
  )
}
