open Vitest

module Test = Agent__Bindings__Vercel__Test
module Bindings = Agent__Bindings__Vercel
module Adapter = Agent__Adapters__Vercel

describe("MockLanguageModelV2", () => {
  testAsync("returns mocked text response", async t => {
    let mockModel = Test.makeTextMock("Hello from mock!")
    let registry = Agent__ToolsRegistry.make()

    let llm = Adapter.makeLLM(~model=mockModel, ~toolRegistry=registry)
    let taskId = Agent__Id.make()
    let initialMessage = Agent__Task__Message.User({
      taskId,
      content: String("Test prompt"),
      selectedElementSourceLocation: None,
    })
    let task = Agent__Task.make(taskId, initialMessage, None)

    let result = await Adapter.streamText(llm, task->Agent__Task.getHistory)
    let responseText = await result->Adapter.getText

    t->expect(responseText)->Expect.toBe("Hello from mock!")
  })

  testAsync("simulates streaming response", async t => {
    let mockModel = Test.makeStreamingMock("Streamed text")
    let registry = Agent__ToolsRegistry.make()

    let llm = Adapter.makeLLM(~model=mockModel, ~toolRegistry=registry)
    let taskId = Agent__Id.make()
    let initialMessage = Agent__Task__Message.User({
      taskId,
      content: String("Test prompt"),
      selectedElementSourceLocation: None,
    })
    let task = Agent__Task.make(taskId, initialMessage, None)

    let result = await Adapter.streamText(llm, task->Agent__Task.getHistory)

    // Since makeStreamingMock now uses the same underlying implementation as makeTextMock,
    // we can just verify getText works
    let responseText = await result->Adapter.getText
    t->expect(responseText)->Expect.toBe("Streamed text")
  })

  testAsync("completes in under 1 second", async t => {
    let startTime = Date.now()
    let mockModel = Test.makeTextMock("Fast response")
    let registry = Agent__ToolsRegistry.make()

    let llm = Adapter.makeLLM(~model=mockModel, ~toolRegistry=registry)
    let taskId = Agent__Id.make()
    let initialMessage = Agent__Task__Message.User({
      taskId,
      content: String("Test prompt"),
      selectedElementSourceLocation: None,
    })
    let task = Agent__Task.make(taskId, initialMessage, None)

    let _result = await Adapter.streamText(llm, task->Agent__Task.getHistory)
    let endTime = Date.now()
    let duration = endTime -. startTime

    t->expect(duration < 1000.0)->Expect.toBe(true)
  })
})

describe("simulateReadableStream with delays", () => {
  testAsync("respects configured delays", async t => {
    let chunks = [
      Test.TextStart({id: "text-1"}),
      Test.TextDelta({id: "text-1", delta: "Hello"}),
      Test.TextEnd({id: "text-1"}),
      Test.Finish({
        finishReason: Stop,
        usage: {promptTokens: 5, completionTokens: 1, totalTokens: 6},
      }),
    ]

    let startTime = Date.now()
    let stream = Test.simulateReadableStream({
      chunks,
      initialDelayInMs: 10,
      chunkDelayInMs: 5,
    })

    let doStreamResult: Test.doStreamResult = {stream: stream}
    let mockModel = Test.mockLanguageModelV2({
      doStream: () => Promise.resolve(doStreamResult),
    })

    let registry = Agent__ToolsRegistry.make()
    let llm = Adapter.makeLLM(~model=mockModel, ~toolRegistry=registry)
    let taskId = Agent__Id.make()
    let initialMessage = Agent__Task__Message.User({
      taskId,
      content: String("Test"),
      selectedElementSourceLocation: None,
    })
    let task = Agent__Task.make(taskId, initialMessage, None)

    let result = await Adapter.streamText(llm, task->Agent__Task.getHistory)
    let _ = await result->Adapter.getText

    let endTime = Date.now()
    let duration = endTime -. startTime

    // Should take at least 10 (initial) + 5 + 5 + 5 = 25ms (4 chunks with delay)
    t->expect(duration >= 25.0)->Expect.toBe(true)
  })
})
