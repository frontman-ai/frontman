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

// Browser tool - executes in browser, no context needed
module type BrowserTool = {
  let name: string
  let description: string
  type input
  type output
  let inputSchema: S.t<input>
  let outputSchema: S.t<output>
  let execute: input => promise<toolResult<output>>
  //some tools we want to execute manually, and never have the llm see them
  let visibleToAgent: bool
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
