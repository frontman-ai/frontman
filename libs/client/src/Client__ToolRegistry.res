// Registry of client-side tools that can be imported in the browser
module Agent = AskTheLlmAgent.Agent
module Tool = AskTheLlmAgent.Agent__Tool
module ToolExecutionContext = AskTheLlmAgent.Agent__ToolExecutionContext
module GetPageTitle = AskTheLlmAgent.Agent__Tool__Client__GetPageTitle

// Array of available client tool modules
let clientTools: array<module(Tool.T)> = [module(GetPageTitle)]

// Check if a tool name is a client-side tool
let isClientTool = (toolName: string): bool => {
  clientTools->Array.some(toolModule => {
    module Tool = unpack(toolModule)
    Tool.name == toolName
  })
}

// Execute a client tool by name
let execute = async (~toolName: string, ~args: JSON.t): result<JSON.t, string> => {
  // Find the tool module by name
  let toolOption = clientTools->Array.find(toolModule => {
    module Tool = unpack(toolModule)
    Tool.name == toolName
  })

  switch toolOption {
  | None => Error(`Unknown client tool: ${toolName}`)
  | Some(toolModule) => {
      module Tool = unpack(toolModule)

      // Decode input
      switch Tool.decodeInput(args) {
      | Error(error) => Error(`Invalid input: ${error.message}`)
      | Ok(input) => {
          let ctx: ToolExecutionContext.t = {projectRoot: "/"}
          switch await Tool.execute(ctx, input) {
          | Error(msg) => Error(msg)
          | Ok(output) => Ok(Tool.encodeOutput(output))
          }
        }
      }
    }
  }
}
