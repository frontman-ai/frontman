module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
module Feedback = Client__CustomerFeedback__Types

let name = Tool.ToolNames.requestCustomerFeedback
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Write
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Interactive
let description = `Request optional customer feedback about Frontman at a meaningful result checkpoint. The user sees a fixed recommendation question, scores 0..10, an optional comment, and Skip. Do not ask on the first message or automatically on failure. If the user is dissatisfied, follow the server's guidance and continue helping; never request a revised score.`

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
