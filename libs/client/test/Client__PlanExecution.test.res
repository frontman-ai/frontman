open Vitest

module Message = Client__State__Types.Message
module AssistantContentPart = Client__State__Types.AssistantContentPart
module PlanExecution = Client__PlanExecution
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

let planner: ACP.agentCatalogEntry = {
  id: "planner-id",
  name: "planner",
  displayName: "Planner",
  description: "Plans work",
  color: "#F59E0B",
}

let executor: ACP.agentCatalogEntry = {
  id: "executor-id",
  name: "executor",
  displayName: "Executor",
  description: "Executes work",
  color: "#985DF7",
}

let catalog = [planner, executor]

let completed = (~agentId, ~content) => Message.Assistant(
  Message.Completed({id: "assistant-1", content, agentId}),
)

let plannerPlan = completed(~agentId="planner-id", ~content=[AssistantContentPart.text("1. Do X")])

describe("Client__PlanExecution.pendingHandoff", () => {
  test("returns executor handoff when planner completed a plan and agent is idle", t => {
    let handoff = PlanExecution.pendingHandoff(
      ~messages=[plannerPlan],
      ~agentCatalog=Some(catalog),
      ~isAgentRunning=false,
    )
    t->expect(handoff)->Expect.toEqual(Some({PlanExecution.executorAgentId: "executor-id"}))
  })

  test("returns None while agent is running", t => {
    let handoff = PlanExecution.pendingHandoff(
      ~messages=[plannerPlan],
      ~agentCatalog=Some(catalog),
      ~isAgentRunning=true,
    )
    t->expect(handoff)->Expect.toEqual(None)
  })

  test("returns None when catalog is not loaded", t => {
    let handoff = PlanExecution.pendingHandoff(
      ~messages=[plannerPlan],
      ~agentCatalog=None,
      ~isAgentRunning=false,
    )
    t->expect(handoff)->Expect.toEqual(None)
  })

  test("returns None when last message is not from planner", t => {
    let handoff = PlanExecution.pendingHandoff(
      ~messages=[completed(~agentId="executor-id", ~content=[AssistantContentPart.text("Done")])],
      ~agentCatalog=Some(catalog),
      ~isAgentRunning=false,
    )
    t->expect(handoff)->Expect.toEqual(None)
  })
})
