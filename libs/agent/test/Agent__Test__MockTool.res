// Test helper for creating mock tools with fixed outputs
// This allows tests to be deterministic and not depend on actual file system state

S.enableJson()

// Type to track tool executions
type execution = {
  input: JSON.t,
  timestamp: float,
}

type toolWithTracking = {
  tool: module(Agent__Tool.T),
  executions: ref<array<execution>>,
}

// Create a mock tool that always returns a fixed JSON value
let makeMockTool = (
  ~name: string,
  ~description: string,
  ~fixedOutput: JSON.t,
): toolWithTracking => {
  let executions = ref([])

  module MockTool: Agent__Tool.T = {
    let name = name
    let description = description

    @schema
    type input = JSON.t

    type output = JSON.t

    let decodeInput = (json: JSON.t): result<input, S.error> => {
      Ok(json)
    }

    let encodeOutput = (output: output): JSON.t => {
      output
    }

    let execute = async (_ctx: Agent__ToolExecutionContext.t, input: input): Agent__Tool.toolResult<
      output,
    > => {
      // Track this execution
      executions := Array.concat(
        executions.contents,
        [{input: input, timestamp: Date.now()}],
      )
      // Always return the fixed output
      Ok(fixedOutput)
    }
  }

  {tool: module(MockTool), executions: executions}
}

// Create a mock tool that returns different outputs based on call count
let makeStatefulMockTool = (
  ~name: string,
  ~description: string,
  ~outputs: array<JSON.t>,
): toolWithTracking => {
  let callCount = ref(0)
  let executions = ref([])

  module MockTool: Agent__Tool.T = {
    let name = name
    let description = description

    @schema
    type input = JSON.t

    type output = JSON.t

    let decodeInput = (json: JSON.t): result<input, S.error> => {
      Ok(json)
    }

    let encodeOutput = (output: output): JSON.t => {
      output
    }

    let execute = async (_ctx: Agent__ToolExecutionContext.t, input: input): Agent__Tool.toolResult<
      output,
    > => {
      let currentCount = callCount.contents
      callCount := currentCount + 1

      // Track this execution
      executions := Array.concat(
        executions.contents,
        [{input: input, timestamp: Date.now()}],
      )

      // Return the output for this call, or the last one if we've run out
      let output = outputs[currentCount]->Option.getOr(outputs[outputs->Array.length - 1]->Option.getOrThrow)
      Ok(output)
    }
  }

  {tool: module(MockTool), executions: executions}
}

// Create a registry with mock tools
let makeRegistry = (tools: array<toolWithTracking>): Agent__ToolsRegistry.t => {
  tools->Array.map(({tool}) => tool)
}
