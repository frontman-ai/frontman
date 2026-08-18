/**
 * Client__PlanExecution - Handoff from the planner agent to the executor agent.
 *
 * The planner is read-only: its turn ends once the plan text is produced.
 * This module decides when the chat can offer an "Execute plan" action and
 * which agent should run it.
 */
module Message = Client__State__Types.Message

let plannerAgentName = "planner"
let executorAgentName = "executor"

let executePrompt = "Execute the plan above."

type handoff = {executorAgentId: string}

/**
 * Returns the executor handoff when the conversation ended with a completed
 * plan from the planner agent and the agent is idle.
 */
let pendingHandoff = (
  ~messages: array<Message.t>,
  ~agentCatalog: option<array<Client__Agent.t>>,
  ~isAgentRunning: bool,
): option<handoff> => {
  switch (isAgentRunning, agentCatalog, messages->Array.last) {
  | (false, Some(catalog), Some(Message.Assistant(Message.Completed({agentId, _})))) =>
    let messageAgent = Client__Agent.findOrThrow(agentCatalog, agentId)
    switch catalog->Array.find(agent => agent.name == executorAgentName) {
    | Some(executor) if messageAgent.name == plannerAgentName =>
      Some({executorAgentId: executor.id})
    | _ => None
    }
  | _ => None
  }
}
