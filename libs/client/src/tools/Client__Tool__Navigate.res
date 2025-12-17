// Client tool that navigates to a URL in the web preview
// Uses window.location.href to navigate the previewFrame

S.enableJson()
module Tool = AskTheLlmFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = "navigate"
let description = "Navigate the web preview to a specified relative URL. Changes the current page in the preview frame. Only relative paths should be passed (e.g., '/about', '/products/123')."

@schema
type input = {
  @s.describe("The relative URL to navigate to. Only relative paths should be passed (e.g., '/about', '/products/123')")
  url: string,
}

@schema
type output = {
  @s.describe("Whether the navigation was initiated successfully")
  success: bool,
  @s.describe("The URL that was navigated to")
  navigatedTo: option<string>,
  @s.describe("Error message if navigation failed")
  error: option<string>,
}

// Raw JS function to set location href
let setLocationHref: (WebAPI.DOMAPI.window, string) => unit = %raw(`
  function(win, url) {
    win.location.href = url;
  }
`)

let execute = async (input: input): toolResult<output> => {
  let state = AskTheLlmReactStatestore.StateStore.getState(Client__State__Store.store)

  // Get the current task's preview frame
  let previewFrame =
    state.currentTaskId
    ->Option.flatMap(taskId => Dict.get(state.tasks, taskId))
    ->Option.map(task => task.previewFrame)

  switch previewFrame {
  | None => Ok({success: false, navigatedTo: None, error: Some("No active task with preview frame")})
  | Some({contentWindow: None, _}) =>
    Ok({success: false, navigatedTo: None, error: Some("Preview frame window not available")})
  | Some({contentWindow: Some(win), _}) =>
    try {
      setLocationHref(win, input.url)
      Ok({success: true, navigatedTo: Some(input.url), error: None})
    } catch {
    | exn =>
      let errorMsg =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error during navigation")
      Ok({success: false, navigatedTo: None, error: Some(errorMsg)})
    }
  }
}












