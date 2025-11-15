let clientTools: array<module(Client__Tool.T)> = [module(Client__Tool__GetErrors)]

let getTool = (toolName: string): option<module(Client__Tool.T)> => {
  clientTools->Array.find(toolModule => {
    module Tool = unpack(toolModule)
    Tool.name == toolName
  })
}

let isClientTool = (toolName: string): bool => {
  getTool(toolName)->Option.isSome
}

let execute = async (~state: Client__State__Types.state, ~toolName: string, ~args: JSON.t): result<
  JSON.t,
  string,
> => {
  switch getTool(toolName) {
  | None => Error(`Unknown client tool: ${toolName}`)
  | Some(toolModule) => {
      module Tool = unpack(toolModule)

      switch Tool.decodeInput(args) {
      | Error(error) => Error(`Invalid input: ${error.message}`)
      | Ok(input) =>
        switch await Tool.execute(state, input) {
        | Error(msg) => Error(msg)
        | Ok(output) => Ok(Tool.encodeOutput(output))
        }
      }
    }
  }
}
