// Client tool that navigates back in browser history in the web preview
// Uses window.history.back() to go to the previous page

S.enableJson()
module Tool = FrontmanFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = "navigate_back"
let visibleToAgent = true
let description = "Navigate back to the previous page in the web preview's browser history. Equivalent to clicking the browser's back button."

@schema
type input = {
  @s.describe("Placeholder parameter (not used)")
  _placeholder: option<string>,
}

@schema
type output = {
  @s.describe("Whether the back navigation was initiated successfully")
  success: bool,
  @s.describe("Error message if navigation failed")
  error: option<string>,
}

// Raw JS function to call history.back()
let historyBack: WebAPI.DOMAPI.window => unit = %raw(`
  function(win) {
    win.history.back();
  }
`)

let execute = async (_input: input): toolResult<output> => {
  let state = FrontmanReactStatestore.StateStore.getState(Client__State__Store.store)

  // Get the current task's preview frame
  let previewFrame = Client__State__StateReducer.Selectors.previewFrame(state)

  switch previewFrame.contentWindow {
  | None => Ok({success: false, error: Some("Preview frame window not available")})
  | Some(win) =>
    try {
      historyBack(win)
      Ok({success: true, error: None})
    } catch {
    | exn =>
      let errorMsg =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error during back navigation")
      Ok({success: false, error: Some(errorMsg)})
    }
  }
}
