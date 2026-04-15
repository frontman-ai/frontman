// Client tool that discovers interactive elements on the current page.
// Returns a snapshot of clickable/interactive elements with their roles,
// accessible names, and CSS selectors for use by interact_with_element.

S.enableJson()
module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.getInteractiveElements
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = `Discover interactive elements on the current web preview page. Returns a list of clickable/interactive elements with their ARIA roles, accessible names, CSS selectors, and visible text.

Use this tool to understand what elements are available for interaction before calling interact_with_element.

Detection methods:
- **semantic**: Elements with interactive ARIA roles (button, link, checkbox, etc.) — either from HTML semantics or explicit role attributes
- **cursor_pointer**: Elements styled with cursor:pointer (catches JS onclick handlers on divs, spans, etc.)
- **tabindex**: Elements with a tabindex attribute (focusable, likely interactive)

Optional filters:
- **role**: Only return elements with a specific ARIA role (e.g. "button", "link")
- **name**: Only return elements whose accessible name contains the given text`

@schema
type input = {
  @s.describe("Filter by ARIA role (e.g. 'button', 'link', 'checkbox')")
  role: option<string>,
  @s.describe("Filter by accessible name substring (case-insensitive)")
  name: option<string>,
}

@schema
type interactiveElement = {
  @s.describe("Position in the returned list (0-based)")
  index: int,
  @s.describe("ARIA role (computed from HTML semantics or explicit role attribute)")
  role: string,
  @s.describe("Accessible name (from aria-label, label element, text content, etc.)")
  name: string,
  @s.describe("HTML tag name")
  tag: string,
  @s.describe("CSS selector for targeting this element (absent if selector generation failed)")
  selector: option<string>,
  @s.describe(
    "How this element was detected as interactive: 'semantic', 'cursor_pointer', or 'tabindex'"
  )
  detectionMethod: string,
  @s.describe("Truncated visible text content of the element")
  visibleText: option<string>,
}

let maxElements = 50

@schema
type output = {
  @s.describe("Whether the discovery was performed successfully")
  success: bool,
  @s.describe("List of interactive elements found on the page")
  elements: option<array<interactiveElement>>,
  @s.describe("Total number of interactive elements returned")
  totalCount: option<int>,
  @s.describe("True if results were capped at the limit and more elements may exist on the page")
  truncated: option<bool>,
  @s.describe("Error message if the discovery failed")
  error: option<string>,
}

let execute = async (
  input: input,
  ~taskId as _taskId: string,
  ~toolCallId as _toolCallId: string,
): toolResult<output> => {
  Client__Tool__ElementResolver.withPreviewDoc(
    ~onUnavailable=() => Ok({
      success: false,
      elements: None,
      totalCount: None,
      truncated: None,
      error: Some("Preview frame not available"),
    }),
    ({doc, win}) => {
      try {
        let resolved = Client__Tool__ElementResolver.collectInteractiveElements(
          ~document=doc,
          ~contentWindow=win,
          ~roleFilter=?input.role,
          ~nameFilter=?input.name,
          ~maxElements,
        )

        let elements = resolved->Array.mapWithIndex((el, idx) => {
          let selector = Client__Tool__ElementResolver.generateSelector(
            ~element=el.element,
            ~document=Some(doc),
          )

          {
            index: idx,
            role: el.role,
            name: el.name,
            tag: el.tag,
            selector,
            detectionMethod: Client__Tool__ElementResolver.detectionMethodToString(
              el.detectionMethod,
            ),
            visibleText: el.visibleText,
          }
        })

        let count = elements->Array.length
        Ok({
          success: true,
          elements: Some(elements),
          totalCount: Some(count),
          truncated: Some(count >= maxElements),
          error: None,
        })
      } catch {
      | exn =>
        Ok({
          success: false,
          elements: None,
          totalCount: None,
          truncated: None,
          error: Some(Client__Tool__ElementResolver.exnMessage(exn)),
        })
      }
    },
  )
}
