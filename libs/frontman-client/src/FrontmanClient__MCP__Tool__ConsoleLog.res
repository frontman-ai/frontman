// console_log MCP tool - logs messages to browser console

let name = "console_log"
let description = "Logs a message to the browser console"

@schema
type input = {message: string}

@schema
type output = {logged: bool}

let execute = async (input: input): FrontmanClient__MCP__Tool.toolResult<output> => {
  Console.log(`[MCP Tool] ${input.message}`)
  Ok({logged: true})
}
