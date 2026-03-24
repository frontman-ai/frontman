// Tool module types for browser and server tools

type toolResult<'a> = result<'a, string>

// Execution context for server-side tools
type serverExecutionContext = {
  // projectRoot: where the app lives (for finding pages, routes, etc.)
  projectRoot: string,
  // sourceRoot: root for resolving file paths from framework source annotations
  // In a monorepo, this is typically the monorepo root. Defaults to projectRoot.
  sourceRoot: string,
}

// How a browser tool delivers its result back to the MCP caller.
// - Synchronous: execute returns a resolved promise (normal flow).
// - Interactive: execute returns a promise that blocks until user input is provided
//   (e.g. question tool waits for user to answer before resolving).
type executionMode = Synchronous | Interactive

// Well-known tool names — used by both server (frontman-core) and client (frontman-client)
// to avoid fragile string comparisons across packages.
module ToolNames = {
  // Server tools (frontman-core)
  let writeFile = "write_file"
  let readFile = "read_file"
  let listFiles = "list_files"
  let searchFiles = "search_files"
  let grep = "grep"
  let fileExists = "file_exists"
  let loadAgentInstructions = "load_agent_instructions"
  let lighthouse = "lighthouse"
  let listTree = "list_tree"

  // Browser tools (client)
  let executeJs = "execute_js"
  let takeScreenshot = "take_screenshot"
  let setDeviceMode = "set_device_mode"
  let interactWithElement = "interact_with_element"
  let getInteractiveElements = "get_interactive_elements"
  let getDom = "get_dom"
  let searchText = "search_text"
  let question = "question"
}

// Browser tool - executes in browser, no context needed
module type BrowserTool = {
  let name: string
  let description: string
  type input
  type output
  let inputSchema: S.t<input>
  let outputSchema: S.t<output>
  let execute: (input, ~taskId: string, ~toolCallId: string) => promise<toolResult<output>>
  //some tools we want to execute manually, and never have the llm see them
  let visibleToAgent: bool
  let executionMode: executionMode
}

// Server tool - executes on server with context
module type ServerTool = {
  let name: string
  let description: string
  type input
  type output
  let inputSchema: S.t<input>
  let outputSchema: S.t<output>
  let execute: (serverExecutionContext, input) => promise<toolResult<output>>
  //some tools we want to execute manually, and never have the llm see them
  let visibleToAgent: bool
}
