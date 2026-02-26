// Client tool that searches for visible text on the current page.
// Like Ctrl+F — finds leaf elements containing the query string
// and returns matches with surrounding context and CSS selectors.

S.enableJson()
module Tool = FrontmanFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.searchText
let visibleToAgent = true
let description = `Search for visible text on the current web preview page. Works like Ctrl+F — finds elements whose visible text contains the query string (case-insensitive).

Returns matching elements with surrounding text context, CSS selectors for targeting, and accessibility metadata.

Optional: scope the search to a subtree using a CSS selector or XPath expression.

Examples:
- Find all mentions of "error": {"query": "error"}
- Search within a section: {"query": "price", "selector": "#product-details"}
- More context around matches: {"query": "login", "contextChars": 120}`

@schema
type input = {
  @s.describe("The text to search for (case-insensitive substring match)")
  query: string,
  @s.describe("CSS selector or XPath to scope the search to a subtree. Defaults to the entire page.")
  selector: option<string>,
  @s.describe("Maximum number of results to return. Defaults to 25.")
  maxResults: option<int>,
  @s.describe("Characters of surrounding context to include around each match. Defaults to 80.")
  contextChars: option<int>,
}

@schema
type searchMatch = {
  @s.describe("Position in the results list (0-based)")
  index: int,
  @s.describe("The matched text with surrounding context. Match is wrapped in >> and << markers.")
  text: string,
  @s.describe("CSS selector for targeting this element (absent if generation failed)")
  selector: option<string>,
  @s.describe("HTML tag name")
  tag: string,
  @s.describe("ARIA role, if any")
  role: option<string>,
  @s.describe("Accessible name, if any")
  accessibleName: option<string>,
}

@schema
type output = {
  @s.describe("Whether the search completed successfully")
  success: bool,
  @s.describe("Elements whose visible text contains the query")
  matches: option<array<searchMatch>>,
  @s.describe("Total matches found (before truncation)")
  totalCount: option<int>,
  @s.describe("True if results were capped and more matches exist")
  truncated: option<bool>,
  @s.describe("Error message if the search failed")
  error: option<string>,
}

let defaultMaxResults = 25
let defaultContextChars = 80

let errorResult = (~error: string): result<output, _> =>
  Ok({success: false, matches: None, totalCount: None, truncated: None, error: Some(error)})

let successResult = (~matches, ~totalCount, ~truncated): result<output, _> =>
  Ok({success: true, matches: Some(matches), totalCount: Some(totalCount), truncated: Some(truncated), error: None})

// Build a context snippet around the first occurrence of `query` in `text`.
// Wraps the matched portion in >> << markers.
let buildContextSnippet = (~text: string, ~query: string, ~contextChars: int): string => {
  let lowerText = text->String.toLowerCase
  let lowerQuery = query->String.toLowerCase

  switch lowerText->String.indexOf(lowerQuery) {
  | -1 => text->String.slice(~start=0, ~end=contextChars)
  | idx =>
    let matchEnd = idx + query->String.length
    let start = Math.Int.max(0, idx - contextChars / 2)
    let end = Math.Int.min(text->String.length, matchEnd + contextChars / 2)

    let prefix = switch start > 0 {
    | true => "..."
    | false => ""
    }
    let suffix = switch end < text->String.length {
    | true => "..."
    | false => ""
    }

    prefix ++
    text->String.slice(~start, ~end=idx) ++
    ">>" ++
    text->String.slice(~start=idx, ~end=matchEnd) ++
    "<<" ++
    text->String.slice(~start=matchEnd, ~end) ++
    suffix
  }
}

let execute = async (input: input): toolResult<output> => {
  switch input.query->String.trim {
  | "" => errorResult(~error="Query string cannot be empty")
  | _ =>
    Client__Tool__ElementResolver.withPreviewDoc(
      ~onUnavailable=() => errorResult(~error="Preview frame not available"),
      ({doc, win: _}) => {
        try {
          switch Client__Tool__ElementResolver.resolveRootOrBody(~doc, ~selector=input.selector) {
          | Error(msg) => errorResult(~error=msg)
          | Ok(root) =>
            let maxResults = input.maxResults->Option.getOr(defaultMaxResults)
            let contextChars = input.contextChars->Option.getOr(defaultContextChars)

            let allMatches = Client__Tool__ElementResolver.findMatchingElements(
              ~root,
              ~query=input.query,
            )

            let totalCount = allMatches->Array.length
            let truncated = totalCount > maxResults
            let matches =
              allMatches
              ->Array.slice(~start=0, ~end=maxResults)
              ->Array.mapWithIndex((el, idx) => {
                index: idx,
                text: buildContextSnippet(
                  ~text=Client__Tool__ElementResolver.getVisibleText(el),
                  ~query=input.query,
                  ~contextChars,
                ),
                selector: Client__Tool__ElementResolver.generateSelector(
                  ~element=el,
                  ~document=Some(doc),
                ),
                tag: el.tagName->String.toLowerCase,
                role: Client__Tool__ElementResolver.getOptionalRole(el),
                accessibleName: Client__Tool__ElementResolver.getOptionalAccessibleName(el),
              })

            successResult(~matches, ~totalCount, ~truncated)
          }
        } catch {
        | exn => errorResult(~error=Client__Tool__ElementResolver.exnMessage(exn))
        }
      },
    )
  }
}
