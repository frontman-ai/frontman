// Tool execution tests using REAL file system operations
// These tests execute actual tools against the filesystem.
//
// For tests that mock LLM responses, see Agent__Mocking.test.res

open Vitest

module Part = Agent__Task__Message__Part
module ToolCallPart = Part.ToolCallPart
module ToolResultPart = Part.ToolResultPart

describe("extractToolCalls", () => {
  testAsync("extracts tool calls from assistant message with List content", async t => {
    let taskId = Agent__Id.make()
    let toolCall: ToolCallPart.t = {
      toolCallId: "call_123",
      toolName: "listFiles",
      args: JSON.parseOrThrow(`{"relative_dir": "."}`),
    }

    let message = Agent__Task__Message.Assistant({
      taskId: Some(taskId),
      content: List([ToolCall(toolCall), Text({content: "Let me list the files..."})]),
    })

    let result = Agent__Task__Message.extractToolCalls(message)

    t->expect(result->Array.length)->Expect.toBe(1)
    t->expect(result[0]->Option.map(tc => tc.toolName))->Expect.toEqual(Some("listFiles"))
  })

  testAsync("returns empty array for assistant message without tool calls", async t => {
    let taskId = Agent__Id.make()
    let message = Agent__Task__Message.Assistant({
      taskId: Some(taskId),
      content: String("Hello, I'm the assistant"),
    })

    let result = Agent__Task__Message.extractToolCalls(message)

    t->expect(result->Array.length)->Expect.toBe(0)
  })

  testAsync("returns empty array for non-assistant messages", async t => {
    let taskId = Agent__Id.make()
    let message = Agent__Task__Message.User({
      taskId,
      content: String("Hello"),
    })

    let result = Agent__Task__Message.extractToolCalls(message)

    t->expect(result->Array.length)->Expect.toBe(0)
  })
})

describe("executeSingleTool - success", () => {
  testAsync("executes ListFiles tool successfully", async t => {
    let config: Agent__Config.t = {projectRoot: ".", apiKey: ""}
    let registry = Agent__ToolsRegistry.make()
    let toolCall: ToolCallPart.t = {
      toolCallId: "call_123",
      toolName: "listFiles",
      args: JSON.parseOrThrow(`{"relative_dir": "."}`),
    }

    let result = await Agent__Effect.executeSingleTool(config, registry, toolCall)

    t->expect(result.toolCallId)->Expect.toBe("call_123")
    t->expect(result.toolName)->Expect.toBe("listFiles")

    // Should be JSON output with file list, not an error
    switch result.output {
    | JSON(_) => t->expect(true)->Expect.toBe(true)
    | ErrorText(msg) => {
        Console.error2("Unexpected error:", msg)
        t->expect(false)->Expect.toBe(true)
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("executeSingleTool - errors", () => {
  testAsync("returns error when tool not found", async t => {
    let config: Agent__Config.t = {projectRoot: ".", apiKey: ""}
    let registry = Agent__ToolsRegistry.make()
    let toolCall: ToolCallPart.t = {
      toolCallId: "call_123",
      toolName: "nonExistentTool",
      args: JSON.parseOrThrow(`{}`),
    }

    let result = await Agent__Effect.executeSingleTool(config, registry, toolCall)

    switch result.output {
    | ErrorText(msg) => t->expect(msg->String.includes("not found in registry"))->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  testAsync("returns error when arguments invalid", async t => {
    let config: Agent__Config.t = {projectRoot: ".", apiKey: ""}
    let registry = Agent__ToolsRegistry.make()
    let toolCall: ToolCallPart.t = {
      toolCallId: "call_123",
      toolName: "listFiles",
      args: JSON.parseOrThrow(`{"wrong_field": "value"}`), // Invalid schema
    }

    let result = await Agent__Effect.executeSingleTool(config, registry, toolCall)

    switch result.output {
    | ErrorText(msg) => t->expect(msg->String.includes("Invalid arguments"))->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  testAsync("returns error when tool execution fails", async t => {
    let config: Agent__Config.t = {projectRoot: ".", apiKey: ""}
    let registry = Agent__ToolsRegistry.make()
    let toolCall: ToolCallPart.t = {
      toolCallId: "call_123",
      toolName: "listFiles",
      args: JSON.parseOrThrow(`{"relative_dir": "/nonexistent/path/that/does/not/exist"}`),
    }

    let result = await Agent__Effect.executeSingleTool(config, registry, toolCall)

    switch result.output {
    | ErrorText(msg) =>
      t
      ->expect(msg->String.includes("not found") || msg->String.includes("ENOENT"))
      ->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("executeToolCalls", () => {
  testAsync("executes multiple tool calls sequentially", async t => {
    let config: Agent__Config.t = {projectRoot: ".", apiKey: ""}
    let registry = Agent__ToolsRegistry.make()
    let taskId = Agent__Id.make()
    let initialMessage = Agent__Task__Message.User({
      taskId,
      content: String("Test task"),
    })
    let task = Agent__Task.make(taskId, initialMessage)

    let toolCalls: array<ToolCallPart.t> = [
      {
        toolCallId: "call_1",
        toolName: "listFiles",
        args: JSON.parseOrThrow(`{"relative_dir": "."}`),
      },
      {
        toolCallId: "call_2",
        toolName: "listFiles",
        args: JSON.parseOrThrow(`{"relative_dir": "src"}`),
      },
    ]

    let message = await Agent__Effect.executeToolCalls(
      task,
      toolCalls,
      ~config,
      ~toolRegistry=registry,
    )

    switch message {
    | Tool({content, _}) => {
        t->expect(content->Array.length)->Expect.toBe(2)
        t->expect(content[0]->Option.map(r => r.toolCallId))->Expect.toEqual(Some("call_1"))
        t->expect(content[1]->Option.map(r => r.toolCallId))->Expect.toEqual(Some("call_2"))
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  testAsync("handles mix of successful and failed tool calls", async t => {
    let config: Agent__Config.t = {projectRoot: ".", apiKey: ""}
    let registry = Agent__ToolsRegistry.make()
    let taskId = Agent__Id.make()
    let initialMessage = Agent__Task__Message.User({
      taskId,
      content: String("Test task"),
    })
    let task = Agent__Task.make(taskId, initialMessage)

    let toolCalls: array<ToolCallPart.t> = [
      {
        toolCallId: "call_1",
        toolName: "listFiles",
        args: JSON.parseOrThrow(`{"relative_dir": "."}`), // Valid
      },
      {
        toolCallId: "call_2",
        toolName: "nonExistentTool",
        args: JSON.parseOrThrow(`{}`), // Tool not found
      },
    ]

    let message = await Agent__Effect.executeToolCalls(
      task,
      toolCalls,
      ~config,
      ~toolRegistry=registry,
    )

    switch message {
    | Tool({content, _}) => {
        t->expect(content->Array.length)->Expect.toBe(2)

        // First should be success
        switch content[0] {
        | Some({output: JSON(_), _}) => t->expect(true)->Expect.toBe(true)
        | _ => t->expect(false)->Expect.toBe(true)
        }

        // Second should be error
        switch content[1] {
        | Some({output: ErrorText(msg), _}) =>
          t
          ->expect(msg->String.includes("not found"))
          ->Expect.toBe(true)
        | _ => t->expect(false)->Expect.toBe(true)
        }
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})
