module MCP = FrontmanProtocol__MCP

let textResult = MCP.CallToolResult.makeText

let structuredResult = (value: 'a, schema: S.t<'a>): MCP.CallToolResult.t => {
  let json = value->S.decodeOrThrow(~from=schema, ~to=S.json->S.noValidation(true))
  MCP.CallToolResult.makeStructured(json)
}

let unstructuredResult = (value: 'a, schema: S.t<'a>): MCP.CallToolResult.t => {
  let json = value->S.decodeOrThrow(~from=schema, ~to=S.json->S.noValidation(true))
  MCP.CallToolResult.makeText(JSON.stringify(json))
}

let imageResult = MCP.CallToolResult.makeImage

type serverExecutionContext = {
  projectRoot: string,
  sourceRoot: string,
}

type executionMode = Synchronous | Interactive

type access =
  | @as("read") Read
  | @as("write") Write
  | @as("read-write") ReadWrite

let accessSchema = S.union([S.literal(Read), S.literal(Write), S.literal(ReadWrite)])

type previewContext = {
  doc: WebAPI.DomTypes.document,
  win: WebAPI.DomTypes.window,
}

module ToolNames = {
  let writeFile = "write_file"
  let readFile = "read_file"
  let listFiles = "list_files"
  let searchFiles = "search_files"
  let grep = "grep"
  let fileExists = "file_exists"
  let loadAgentInstructions = "load_agent_instructions"
  let lighthouse = "lighthouse"
  let listTree = "list_tree"

  let executeJs = "execute_js"
  let takeScreenshot = "take_screenshot"
  let setDeviceMode = "set_device_mode"
  let interactWithElement = "interact_with_element"
  let getInteractiveElements = "get_interactive_elements"
  let getDom = "get_dom"
  let searchText = "search_text"
  let question = "question"
  let getAstroAudit = "get_astro_audit"
}

module type BrowserTool = {
  let name: string
  let description: string
  let access: access
  type input
  let inputSchema: S.t<input>
  let outputJsonSchema: option<JSONSchema.t>
  let execute: (input, ~taskId: string, ~toolCallId: string) => promise<MCP.CallToolResult.t>
  let visibleToAgent: bool
  let executionMode: executionMode
}

module type ServerTool = {
  let name: string
  let description: string
  let access: access
  type input
  let inputSchema: S.t<input>
  let outputJsonSchema: option<JSONSchema.t>
  let execute: (serverExecutionContext, input) => promise<MCP.CallToolResult.t>
  let visibleToAgent: bool
}
