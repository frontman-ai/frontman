// Client tool that navigates in the web preview
// Supports: goto URL, back, forward, refresh

S.enableJson()
module Tool = FrontmanFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.navigate
let visibleToAgent = true
let description = `Navigate in the web preview. Supports multiple navigation actions:

- **goto**: Navigate to a specific URL. Pass {"action": "goto", "url": "/path"}
- **back**: Go back in browser history. Pass {"action": "back"}
- **forward**: Go forward in browser history. Pass {"action": "forward"}
- **refresh**: Reload the current page. Pass {"action": "refresh"}

Examples:
- Navigate to about page: {"action": "goto", "url": "/about"}
- Go back: {"action": "back"}
- Go forward: {"action": "forward"}
- Refresh: {"action": "refresh"}`

@schema
type input = {
  @s.describe("Navigation action: 'goto', 'back', 'forward', or 'refresh'")
  action: [#goto | #back | #forward | #refresh],
  @s.describe("URL to navigate to (required for 'goto' action)")
  url: option<string>,
}

@schema
type output = {
  @s.describe("Whether the navigation was initiated successfully")
  success: bool,
  @s.describe("The URL navigated to (only for goto action)")
  navigatedTo: option<string>,
  @s.describe("The action performed: 'goto', 'back', 'forward', or 'refresh'")
  action: string,
  @s.describe("Error message if navigation failed")
  error: option<string>,
}

// Raw JS function to set location href
let setLocationHref: (WebAPI.DOMAPI.window, string) => unit = %raw(`
  function(win, url) {
    win.location.href = url;
  }
`)

// Raw JS function to call history.back()
let historyBack: WebAPI.DOMAPI.window => unit = %raw(`
  function(win) {
    win.history.back();
  }
`)

// Raw JS function to call history.forward()
let historyForward: WebAPI.DOMAPI.window => unit = %raw(`
  function(win) {
    win.history.forward();
  }
`)

// Raw JS function to call location.reload()
let locationReload: WebAPI.DOMAPI.window => unit = %raw(`
  function(win) {
    win.location.reload();
  }
`)

let execute = async (input: input): toolResult<output> => {
  let state = FrontmanReactStatestore.StateStore.getState(Client__State__Store.store)

  // Get the current task's preview frame
  let previewFrame = Client__State__StateReducer.Selectors.previewFrame(state)

  switch previewFrame.contentWindow {
  | None =>
    Ok({success: false, navigatedTo: None, action: "unknown", error: Some("Preview frame window not available")})
  | Some(win) =>
    try {
      switch input.action {
      | #goto =>
        switch input.url {
        | Some(url) =>
          setLocationHref(win, url)
          Ok({success: true, navigatedTo: Some(url), action: "goto", error: None})
        | None =>
          Ok({success: false, navigatedTo: None, action: "goto", error: Some("URL is required for goto action")})
        }
      | #back =>
        historyBack(win)
        Ok({success: true, navigatedTo: None, action: "back", error: None})
      | #forward =>
        historyForward(win)
        Ok({success: true, navigatedTo: None, action: "forward", error: None})
      | #refresh =>
        locationReload(win)
        Ok({success: true, navigatedTo: None, action: "refresh", error: None})
      }
    } catch {
    | exn =>
      Ok({success: false, navigatedTo: None, action: "unknown", error: Some(Client__Tool__ElementResolver.exnMessage(exn))})
    }
  }
}
