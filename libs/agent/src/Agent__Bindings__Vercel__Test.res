// Bindings for Vercel AI SDK Testing Utilities
// https://ai-sdk.dev/docs/ai-sdk-core/testing

// Re-export base types we'll need
module Bindings = Agent__Bindings__Vercel

// ============================================================================
// MockLanguageModelV2
// ============================================================================

// IMPORTANT: The types below represent the RAW PROVIDER FORMAT that MockLanguageModelV2
// produces via doStream(). This is NOT the same as the public API in Bindings.streamPart.
//
// Two distinct levels:
// 1. RAW FORMAT (this file): What doStream() returns - has text-start/delta/end, args field
// 2. PUBLIC API (main file): What fullStream exposes - has text/reasoning/source, input field
//
// Vercel SDK transforms between these internally.

// Types for doGenerate response
@tag("type")
type generateContent = | @as("text") TextContent({text: string})

type generateResult = {
  finishReason: Bindings.finishReason,
  usage: Bindings.usage,
  content: array<generateContent>,
  warnings: array<string>,
}

// Types for doStream response
// IMPORTANT: MockLanguageModelV2.doStream() returns RAW provider format chunks.
// The RAW format uses:
// - text-start/text-delta/text-end (not "text")
// - tool-call with "input" field containing STRINGIFIED JSON (not args with JSON.t)
// - finish (not finish-step in simple cases)
@tag("type")
type streamChunk =
  | @as("text-start") TextStart({id: string})
  | @as("text-delta") TextDelta({id: string, delta: string})
  | @as("text-end") TextEnd({id: string})
  | @as("tool-call") ToolCall({toolCallId: string, toolName: string, input: string}) // Note: input is STRINGIFIED JSON
  | @as("tool-call-delta") ToolCallDelta({toolCallId: string, argsTextDelta: string})
  | @as("finish")
  Finish({
      finishReason: Bindings.finishReason,
      usage: Bindings.usage,
      logprobs?: JSON.t,
    })

type doStreamResult = {stream: Bindings.AsyncIterableStream.t<streamChunk>}

// Configuration for MockLanguageModelV2
type mockLanguageModelConfig = {
  doGenerate?: unit => promise<generateResult>,
  doStream?: unit => promise<doStreamResult>,
}

@module("ai/test") @new
external mockLanguageModelV2: mockLanguageModelConfig => Bindings.languageModel =
  "MockLanguageModelV2"

// ============================================================================
// simulateReadableStream
// ============================================================================

type simulateStreamConfig<'a> = {
  chunks: array<'a>,
  initialDelayInMs?: int,
  chunkDelayInMs?: int,
}

@module("ai")
external simulateReadableStream: simulateStreamConfig<'a> => Bindings.AsyncIterableStream.t<
  'a,
> = "simulateReadableStream"

// ============================================================================
// Helper Functions
// ============================================================================

// Create a simple mock that returns text
// Note: Vercel uses doStream by default, so we need to implement doStream, not doGenerate
let makeTextMock = (text: string): Bindings.languageModel => {
  mockLanguageModelV2({
    doStream: () =>
      Promise.resolve({
        stream: simulateReadableStream({
          chunks: [
            TextStart({id: "text-1"}),
            TextDelta({id: "text-1", delta: text}),
            TextEnd({id: "text-1"}),
            Finish({
              finishReason: Stop,
              usage: {promptTokens: 10, completionTokens: 20, totalTokens: 30},
            }),
          ],
        }),
      }),
  })
}

// Create a streaming mock
let makeStreamingMock = (text: string): Bindings.languageModel => {
  mockLanguageModelV2({
    doStream: () =>
      Promise.resolve({
        stream: simulateReadableStream({
          chunks: [
            TextStart({id: "text-1"}),
            TextDelta({id: "text-1", delta: text}),
            TextEnd({id: "text-1"}),
            Finish({
              finishReason: Stop,
              usage: {promptTokens: 3, completionTokens: 10, totalTokens: 13},
            }),
          ],
        }),
      }),
  })
}

// Create a mock that returns a single tool call, then text on subsequent calls
let makeToolCallMock = (~toolCallId: string, ~toolName: string, ~args: JSON.t): Bindings.languageModel => {
  let callCount = ref(0)

  mockLanguageModelV2({
    doStream: () => {
      callCount := callCount.contents + 1

      Promise.resolve({
        stream: simulateReadableStream({
          chunks: if callCount.contents == 1 {
            // First call: return tool call
            // Note: input must be STRINGIFIED JSON in the raw format
            [
              TextStart({id: "text-1"}),
              TextDelta({id: "text-1", delta: "I'll help you with that."}),
              TextEnd({id: "text-1"}),
              ToolCall({toolCallId, toolName, input: JSON.stringify(args)}),
              Finish({
                finishReason: ToolCalls,
                usage: {promptTokens: 10, completionTokens: 5, totalTokens: 15},
              }),
            ]
          } else {
            // Subsequent calls: return completion text
            [
              TextStart({id: "text-2"}),
              TextDelta({id: "text-2", delta: "Task completed successfully."}),
              TextEnd({id: "text-2"}),
              Finish({
                finishReason: Stop,
                usage: {promptTokens: 20, completionTokens: 10, totalTokens: 30},
              }),
            ]
          },
        }),
      })
    },
  })
}

// Create a mock that returns multiple tool calls, then text on subsequent calls
let makeMultipleToolCallsMock = (~toolCalls: array<(string, string, JSON.t)>): Bindings.languageModel => {
  let callCount = ref(0)

  mockLanguageModelV2({
    doStream: () => {
      callCount := callCount.contents + 1

      Promise.resolve({
        stream: simulateReadableStream({
          chunks: if callCount.contents == 1 {
            // First call: return all tool calls
            let textChunks = [
              TextStart({id: "text-1"}),
              TextDelta({id: "text-1", delta: "I'll help you with multiple tasks."}),
              TextEnd({id: "text-1"}),
            ]
            let toolCallChunks = toolCalls->Array.map(((toolCallId, toolName, args)) => {
              ToolCall({toolCallId, toolName, input: JSON.stringify(args)})
            })
            let finishChunk = [
              Finish({
                finishReason: ToolCalls,
                usage: {promptTokens: 15, completionTokens: 8, totalTokens: 23},
              }),
            ]
            textChunks->Array.concat(toolCallChunks)->Array.concat(finishChunk)
          } else {
            // Subsequent calls: return completion text
            [
              TextStart({id: "text-2"}),
              TextDelta({id: "text-2", delta: "All tasks completed."}),
              TextEnd({id: "text-2"}),
              Finish({
                finishReason: Stop,
                usage: {promptTokens: 25, completionTokens: 12, totalTokens: 37},
              }),
            ]
          },
        }),
      })
    },
  })
}
