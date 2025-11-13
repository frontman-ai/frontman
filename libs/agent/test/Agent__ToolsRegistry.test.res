// Tests for tool registry and client tool execution
open Vitest

// Import Agent first to ensure S.enableJson() is called
module Agent = AskTheLlmAgent.Agent
module Part = Agent__Task__Message__Part
module ToolResultPart = Part.ToolResultPart

describe("Agent__ToolsRegistry - client tool execution", () => {
  testAsync("registerClientExecution adds to pending executions", async t => {
    let registry = Agent__ToolsRegistry.make()

    // Register a client execution
    let resultPromise = registry->Agent__ToolsRegistry.registerClientExecution(
      ~toolCallId="test-call-123",
      ~toolName="getPageTitle",
      ~timeoutMs=5000,
      ~onTimeout=() => {
        {
          toolCallId: "test-call-123",
          toolName: "getPageTitle",
          output: ToolResultPart.Output.ErrorText("Timeout"),
          providerOptions: None,
        }
      },
    )

    // Check that pending count is 1
    let pendingCount = registry->Agent__ToolsRegistry.getPendingCount
    Agent__Logger.Log.info(`Pending count after registration: ${pendingCount->Int.toString}`)
    t->expect(pendingCount)->Expect.toBe(1)

    // Clean up - resolve the promise to avoid hanging test
    let result: ToolResultPart.t = {
      toolCallId: "test-call-123",
      toolName: "getPageTitle",
      output: ToolResultPart.Output.JSON(JSON.parseOrThrow(`{"title": "Test Page"}`)),
      providerOptions: None,
    }
    let resolved = registry->Agent__ToolsRegistry.resolveClientExecution(result)
    t->expect(resolved)->Expect.toBe(true)

    // Wait for promise to resolve
    let _ = await resultPromise

    // Verify pending count is now 0
    let finalCount = registry->Agent__ToolsRegistry.getPendingCount
    t->expect(finalCount)->Expect.toBe(0)
  })

  testAsync("resolveClientExecution resolves the correct promise", async t => {
    let registry = Agent__ToolsRegistry.make()

    // Register a client execution
    let resultPromise = registry->Agent__ToolsRegistry.registerClientExecution(
      ~toolCallId="test-call-456",
      ~toolName="getPageTitle",
      ~timeoutMs=5000,
      ~onTimeout=() => {
        {
          toolCallId: "test-call-456",
          toolName: "getPageTitle",
          output: ToolResultPart.Output.ErrorText("Timeout"),
          providerOptions: None,
        }
      },
    )

    // Resolve with result
    let result: ToolResultPart.t = {
      toolCallId: "test-call-456",
      toolName: "getPageTitle",
      output: ToolResultPart.Output.JSON(JSON.parseOrThrow(`{"title": "My Test Page"}`)),
      providerOptions: None,
    }

    let resolved = registry->Agent__ToolsRegistry.resolveClientExecution(result)
    t->expect(resolved)->Expect.toBe(true)

    // Wait for and verify the promise resolved with our result
    let receivedResult = await resultPromise
    t->expect(receivedResult.toolCallId)->Expect.toBe("test-call-456")
    t->expect(receivedResult.toolName)->Expect.toBe("getPageTitle")

    // Verify it's the exact result we passed
    switch receivedResult.output {
    | JSON(_) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  testAsync("resolveClientExecution returns false for non-existent toolCallId", async t => {
    let registry = Agent__ToolsRegistry.make()

    // Try to resolve a non-existent execution
    let result: ToolResultPart.t = {
      toolCallId: "non-existent-call",
      toolName: "getPageTitle",
      output: ToolResultPart.Output.JSON(JSON.parseOrThrow(`{"title": "Test"}`)),
      providerOptions: None,
    }

    let resolved = registry->Agent__ToolsRegistry.resolveClientExecution(result)
    t->expect(resolved)->Expect.toBe(false)
  })
})
