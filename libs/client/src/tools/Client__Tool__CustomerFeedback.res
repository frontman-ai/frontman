module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
module Feedback = Client__CustomerFeedback__Types

let name = Tool.ToolNames.requestCustomerFeedback
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Write
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Interactive
let description = `After completing and verifying a useful change, call this tool before your final response, even during the first turn. Do not request feedback on a greeting alone, before doing useful work, or while blocked. The user sees a fixed recommendation question about Frontman, scores 0..10, an optional comment, and Skip. After the user answers or skips, continue according to the server's guidance. Never request another rating in the same task or a revised score.`

type input = unit
let inputSchema = S.object(_ => ())->S.strict
let outputJsonSchema = Some(Feedback.outputSchema->S.toJSONSchema)

let execute = async (
  _input: input,
  ~taskId: string,
  ~toolCallId: string,
): Tool.MCP.CallToolResult.t => {
  let result = await Promise.make((resolve, _reject) => {
    Client__State.Actions.customerFeedbackReceived(
      ~taskId,
      ~toolCallId,
      ~resolveOk=json => resolve(Ok(json)),
      ~resolveError=message => resolve(Error(message)),
    )
  })
  switch result {
  | Ok(json) =>
    Tool.structuredResult(json->S.parseOrThrow(~to=Feedback.outputSchema), Feedback.outputSchema)
  | Error(message) => Tool.MCP.CallToolResult.makeError(message)
  }
}
