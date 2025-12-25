/**
 * Client__Markdown - Direct binding to Streamdown for markdown rendering
 * 
 * Replaces the AIElements.Response wrapper with a direct binding to the 
 * streamdown library for rendering markdown content with streaming support.
 */

@module("streamdown") @react.component
external make: (
  ~children: string,
  ~className: string=?,
) => React.element = "Streamdown"

