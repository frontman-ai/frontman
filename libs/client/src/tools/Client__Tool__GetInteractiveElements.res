module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool

let name = Tool.ToolNames.getInteractiveElements
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = `Discover interactive elements on the current web preview page. Returns a list of clickable/interactive elements with their ARIA roles, accessible names, CSS selectors, and visible text.

Use this tool to understand what elements are available for interaction before calling interact_with_element.

Detection methods:
- **semantic**: Elements with interactive ARIA roles (button, link, checkbox, etc.) — either from HTML semantics or explicit role attributes
- **cursor_pointer**: Elements styled with cursor:pointer (catches JS onclick handlers on divs, spans, etc.)
- **tabindex**: Elements with a tabindex attribute (focusable, likely interactive)
- **contenteditable**: Editing hosts, reported as textbox when no computed ARIA role exists

Optional filters:
- **role**: Only return elements with a specific ARIA role (e.g. "button", "link")
- **name**: Only return elements whose accessible name contains the given text
- **offset**: Skip this many matching elements (default 0)
- **limit**: Page size (default 50, clamped to 1–50)

Follow nextOffset until absent to reach every match. totalCount is the number returned in this page, not the page-wide total. Element index is local to this page; use its selector for interaction, not this index as a role/name match index.`

@schema
type input = {
  @s.describe("Filter by ARIA role (e.g. 'button', 'link', 'checkbox')")
  role: option<string>,
  @s.describe("Filter by accessible name substring (case-insensitive)")
  name: option<string>,
  @s.describe("Number of matching elements to skip (default 0, negative values treated as 0)")
  offset: option<int>,
  @s.describe("Maximum elements in this page (default 50, clamped to 1–50)")
  limit: option<int>,
}

@schema
type interactiveElement = {
  @s.describe("Position in the returned list (0-based)") @live
  index: int,
  @s.describe("ARIA role (computed from HTML semantics or explicit role attribute)") @live
  role: string,
  @s.describe("Accessible name (from aria-label, label element, text content, etc.)") @live
  name: string,
  @s.describe("HTML tag name") @live
  tag: string,
  @s.describe("CSS selector for targeting this element (absent if selector generation failed)")
  @live
  selector: option<string>,
  @s.describe(
    "How this element was detected: 'semantic', 'cursor_pointer', 'tabindex', or 'contenteditable'"
  )
  @live
  detectionMethod: string,
  @s.describe("Truncated visible text content of the element") @live
  visibleText: option<string>,
}

let maxElements = 50

@schema
type output = {
  @s.describe("Whether the discovery was performed successfully") @live
  success: bool,
  @s.describe("List of interactive elements found on the page") @live
  elements: option<array<interactiveElement>>,
  @s.describe("Total number of interactive elements returned") @live
  totalCount: option<int>,
  @s.describe("True if more matching elements exist after this page") @live
  truncated: option<bool>,
  @s.describe("Pass this offset to retrieve the next page; absent on the final page") @live
  nextOffset: option<int>,
  @s.describe("Error message if the discovery failed") @live
  error: option<string>,
}

let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

let errorResult = (error: string): Tool.MCP.CallToolResult.t =>
  Tool.structuredResult(
    {
      success: false,
      elements: None,
      totalCount: None,
      truncated: None,
      nextOffset: None,
      error: Some(error),
    },
    outputSchema,
  )

let execute = async (
  input: input,
  ~taskId as _taskId: string,
  ~toolCallId as _toolCallId: string,
): Tool.MCP.CallToolResult.t => {
  Client__Tool__PreviewContext.withPreview(
    ~onUnavailable=() => errorResult("Preview frame not available"),
    ({doc, win}) => {
      try {
        let offset = Math.Int.max(0, input.offset->Option.getOr(0))
        let limit = Math.Int.min(
          maxElements,
          Math.Int.max(1, input.limit->Option.getOr(maxElements)),
        )
        let resolved = Client__Tool__ElementQuery.queryInteractiveElements(
          ~document=doc,
          ~contentWindow=win,
          ~roleFilter=input.role,
          ~nameFilter=input.name,
          ~limit=Some(limit + 1),
          ~offset,
        )
        let truncated = resolved->Array.length > limit
        let elements =
          resolved
          ->Array.slice(~start=0, ~end=limit)
          ->Array.mapWithIndex((el, idx) => {
            let selector = switch Client__ElementInspector.findSelector(
              ~element=el.element,
              ~document=doc,
            ) {
            | Ok(selector) => Some(selector)
            | Error(_) => None
            }

            {
              index: idx,
              role: el.role,
              name: el.name,
              tag: el.tag,
              selector,
              detectionMethod: Client__Tool__ElementQuery.detectionMethodToString(
                el.detectionMethod,
              ),
              visibleText: el.visibleText,
            }
          })

        let count = elements->Array.length
        Tool.structuredResult(
          {
            success: true,
            elements: Some(elements),
            totalCount: Some(count),
            truncated: Some(truncated),
            nextOffset: switch truncated {
            | true => Some(offset + count)
            | false => None
            },
            error: None,
          },
          outputSchema,
        )
      } catch {
      | exn => errorResult(Client__Tool__PreviewContext.exnMessage(exn))
      }
    },
  )
}
