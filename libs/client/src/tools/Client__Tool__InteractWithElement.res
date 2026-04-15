// Client tool that interacts with elements in the web preview.
// Supports click, hover, and focus actions.
// Elements can be targeted by CSS selector, role+name, or text content.

S.enableJson()
module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.interactWithElement
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = `Interact with an element in the web preview. Supports click, hover, and focus actions.

Element targeting (use one strategy):
1. **selector** (preferred): CSS selector — use when you have a selector from get_interactive_elements or the user's selected element context
2. **role + name** (both required): ARIA role and accessible name — e.g. role="button", name="Submit Order"
3. **text**: Visible text content — matches the innermost element containing the text

Actions:
- **click** (default): Click the element
- **hover**: Trigger mouseenter/mouseover events on the element
- **focus**: Focus the element

Examples:
- Click by selector: {"selector": "#submit-btn", "action": "click"}
- Click by role+name: {"role": "button", "name": "Submit Order", "action": "click"}
- Click by text: {"text": "Learn more", "action": "click"}
- Hover by selector: {"selector": ".dropdown-trigger", "action": "hover"}
- Focus an input: {"role": "textbox", "name": "Email", "action": "focus"}

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
  @s.describe("Interaction type: 'click' (default), 'hover', or 'focus'")
  action: option<[#click | #hover | #focus]>,
  @s.describe("0-based index when multiple elements match (default: 0, i.e. first match)")
  index: option<int>,
}

@schema
type output = {
  @s.describe("Whether the interaction was performed successfully")
  success: bool,
  @s.describe("Description of the element that was interacted with")
  interactedElement: option<string>,
  @s.describe("The action that was performed: 'clicked', 'hovered', or 'focused'")
  action: option<string>,
  @s.describe("Total number of elements that matched the targeting criteria")
  matchCount: option<int>,
  @s.describe("Error message if the interaction failed")
  error: option<string>,
}

// Dispatch hover events (mouseenter + mouseover) on an element
let dispatchHoverEvents = (el: WebAPI.DOMAPI.element): unit => {
  let enterEvt = WebAPI.MouseEvent.make(
    ~type_="mouseenter",
    ~eventInitDict={bubbles: false, cancelable: false},
  )
  let overEvt = WebAPI.MouseEvent.make(
    ~type_="mouseover",
    ~eventInitDict={bubbles: true, cancelable: true},
  )
  let target = (el :> WebAPI.EventAPI.eventTarget)
  target->WebAPI.EventTarget.dispatchEvent(enterEvt->WebAPI.MouseEvent.asEvent)->ignore
  target->WebAPI.EventTarget.dispatchEvent(overEvt->WebAPI.MouseEvent.asEvent)->ignore
}

// Click an element (using HTMLElement.click() for proper event dispatch).
// Cast to htmlElement since click() lives on HTMLElement, not Element.
let clickElement = (el: WebAPI.DOMAPI.element): unit => {
  let htmlEl: WebAPI.DOMAPI.htmlElement = el->Obj.magic
  htmlEl->WebAPI.HTMLElement.click
}

// Focus an element.
// Cast to htmlElement since focus() lives on HTMLElement, not Element.
let focusElement = (el: WebAPI.DOMAPI.element): unit => {
  let htmlEl: WebAPI.DOMAPI.htmlElement = el->Obj.magic
  htmlEl->WebAPI.HTMLElement.focus
}

let actionToString = (action: [#click | #hover | #focus]): string =>
  switch action {
  | #click => "clicked"
  | #hover => "hovered"
  | #focus => "focused"
  }

let performAction = (el: WebAPI.DOMAPI.element, action: [#click | #hover | #focus]): unit =>
  switch action {
  | #click => clickElement(el)
  | #hover => dispatchHoverEvents(el)
  | #focus => focusElement(el)
  }

// Result of element resolution: either an error string, or a resolved element + match count.
type resolution =
  | Error(string)
  | Resolved({element: option<WebAPI.DOMAPI.element>, matchCount: int})

// Resolve the target element using the first applicable strategy:
// 1. CSS selector / XPath  2. role + name  3. text content
let resolveTarget = (~doc: WebAPI.DOMAPI.document, ~input: input, ~index: int): resolution =>
  switch input.selector {
  | Some(selector) =>
    let (element, matchCount) = Client__Tool__ElementResolver.resolveBySelector(
      ~doc,
      ~selector,
      ~index,
    )
    Resolved({element, matchCount})
  | None =>
    switch (input.role, input.name) {
    | (Some(role), Some(name)) =>
      let (element, matchCount) = Client__Tool__ElementResolver.resolveByRoleAndName(
        ~document=doc,
        ~role,
        ~name,
        ~index,
      )
      Resolved({element, matchCount})
    | (Some(_), None) | (None, Some(_)) =>
      Error("Both 'role' and 'name' are required when using role-based targeting")
    | (None, None) =>
      switch input.text {
      | Some(text) =>
        let (element, matchCount) = Client__Tool__ElementResolver.resolveByText(
          ~document=doc,
          ~text,
          ~index,
        )
        Resolved({element, matchCount})
      | None =>
        Error(
          "No targeting strategy provided. Use 'selector', 'role'+'name', or 'text' to identify the element.",
        )
      }
    }
  }

let errorResult = (error: string, ~matchCount: option<int>=?): result<output, _> => Ok({
  success: false,
  interactedElement: None,
  action: None,
  matchCount,
  error: Some(error),
})

let execute = async (
  input: input,
  ~taskId as _taskId: string,
  ~toolCallId as _toolCallId: string,
): toolResult<output> => {
  let action = input.action->Option.getOr(#click)
  let index = Math.Int.max(0, input.index->Option.getOr(0))

  Client__Tool__ElementResolver.withPreviewDoc(
    ~onUnavailable=() => errorResult("Preview frame document not available"),
    ({doc, win: _}) => {
      try {
        switch resolveTarget(~doc, ~input, ~index) {
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
          performAction(el, action)
          Ok({
            success: true,
            interactedElement: Some(Client__Tool__ElementResolver.describeElement(el)),
            action: Some(actionToString(action)),
            matchCount: Some(matchCount),
            error: None,
          })
        }
      } catch {
      | exn => errorResult(Client__Tool__ElementResolver.exnMessage(exn))
      }
    },
  )
}
