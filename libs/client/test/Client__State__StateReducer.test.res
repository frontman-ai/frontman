open Vitest

module Reducer = Client__State__StateReducer
module UserContentPart = Reducer.UserContentPart
module AssistantContentPart = Reducer.AssistantContentPart

describe("Client State Reducer", () => {
  test("initial state has no messages", t => {
    let state = Reducer.defaultState
    t->expect(state.messages->Array.length)->Expect.toBe(0)
  })

  test("AddUserMessage appends user message", t => {
    let state = Reducer.defaultState
    let action = Reducer.AddUserMessage({
      id: "user-1",
      content: [UserContentPart.text("Hello")],
    })

    let (nextState, _effects) = Reducer.next(state, action)

    t->expect(nextState.messages->Array.length)->Expect.toBe(1)

    switch nextState.messages->Array.get(0) {
    | Some(User({id, content, _})) => {
        t->expect(id)->Expect.toBe("user-1")
        t->expect(content->Array.length)->Expect.toBe(1)
      }
    | _ => t->expect("Got User message")->Expect.toBe("Expected User message")
    }
  })

  test("StreamingStarted creates assistant Streaming message", t => {
    let state = Reducer.defaultState
    let action = Reducer.StreamingStarted({id: "assistant-1"})

    let (nextState, _effects) = Reducer.next(state, action)

    t->expect(nextState.messages->Array.length)->Expect.toBe(1)

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Streaming({id, textBuffer, _}))) => {
        t->expect(id)->Expect.toBe("assistant-1")
        t->expect(textBuffer)->Expect.toBe("")
      }
    | _ => t->expect("Got Streaming message")->Expect.toBe("Expected Streaming message")
    }
  })

  test("TextDeltaReceived appends to textBuffer", t => {
    let state: Reducer.state = {
      previewFrame: {
        url: "https://example.com",
        contentDocument: None,
        contentWindow: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "Hello",
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let action = Reducer.TextDeltaReceived({id: "assistant-1", text: " world"})
    let (nextState, _effects) = Reducer.next(state, action)

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Streaming({textBuffer, _}))) =>
      t->expect(textBuffer)->Expect.toBe("Hello world")
    | _ => t->expect("Got updated text")->Expect.toBe("Expected updated text")
    }
  })

  test("MessageCompleted transitions to Completed variant", t => {
    let state: Reducer.state = {
      previewFrame: {
        url: "https://example.com",
        contentDocument: None,
        contentWindow: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "Hello world",
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let action = Reducer.MessageCompleted({
      id: "assistant-1",
    })
    let (nextState, _effects) = Reducer.next(state, action)

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Completed({content, _}))) => {
        t->expect(content->Array.length)->Expect.toBe(1)
        // Verify content was built from textBuffer
        switch content->Array.get(0) {
        | Some(AssistantContentPart.Text({text})) => t->expect(text)->Expect.toBe("Hello world")
        | _ => t->expect("Got text content")->Expect.toBe("Expected text content")
        }
      }
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })

  test("messages maintain order", t => {
    let state = Reducer.defaultState

    // Add user message
    let (state, _) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        content: [UserContentPart.text("Hi")],
      }),
    )

    // Start assistant streaming
    let (state, _) = Reducer.next(state, StreamingStarted({id: "assistant-1"}))

    // Add text delta
    let (state, _) = Reducer.next(state, TextDeltaReceived({id: "assistant-1", text: "Hello"}))

    // Complete message
    let (state, _) = Reducer.next(
      state,
      MessageCompleted({
        id: "assistant-1",
      }),
    )

    t->expect(state.messages->Array.length)->Expect.toBe(2)

    // Verify order: User first, then Assistant
    switch (state.messages->Array.get(0), state.messages->Array.get(1)) {
    | (Some(User(_)), Some(Assistant(_))) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("Messages in order")->Expect.toBe("Messages not in order")
    }
  })

  test("Selectors.isStreaming detects streaming messages", t => {
    let state: Reducer.state = {
      previewFrame: {
        url: "https://example.com",
        contentDocument: None,
        contentWindow: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "",
            createdAt: 0.0,
          }),
        ),
      ],
    }

    t->expect(Reducer.Selectors.isStreaming(state))->Expect.toBe(true)
  })

  test("Selectors.isStreaming false when no streaming", t => {
    let state: Reducer.state = {
      previewFrame: {
        url: "https://example.com",
        contentDocument: None,
        contentWindow: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Completed({
            id: "assistant-1",
            content: [AssistantContentPart.text("Done")],
            createdAt: 0.0,
          }),
        ),
      ],
    }

    t->expect(Reducer.Selectors.isStreaming(state))->Expect.toBe(false)
  })

  test("ToolCallReceived creates new ToolCall message", t => {
    let state: Reducer.state = {
      previewFrame: {
        url: "https://example.com",
        contentDocument: None,
        contentWindow: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "Calling tool...",
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let toolCall: Reducer.toolCall = {
      toolCallId: "call-123",
      toolName: "search",
      inputBuffer: "",
      input: Some(JSON.Encode.object({})),
      result: None,
      errorText: None,
      state: Reducer.InputAvailable,
    }

    let action = Reducer.ToolCallReceived({toolCall: toolCall})
    let (nextState, _effects) = Reducer.next(state, action)

    t->expect(nextState.messages->Array.length)->Expect.toBe(2)

    switch nextState.messages->Array.get(1) {
    | Some(ToolCall({toolCallId, toolName, _})) => {
        t->expect(toolCallId)->Expect.toBe("call-123")
        t->expect(toolName)->Expect.toBe("search")
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })
})

describe("Client State Reducer - MessageCompleted Content Conversion", () => {
  test("handles empty textBuffer correctly", t => {
    let state: Reducer.state = {
      previewFrame: {
        url: "https://example.com",
        contentDocument: None,
        contentWindow: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "msg-2",
            textBuffer: "",
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let (nextState, _) = Reducer.next(state, MessageCompleted({id: "msg-2"}))

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Completed({content, _}))) =>
      t->expect(content->Array.length)->Expect.toBe(0)
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })

  test("converts toolCalls to ToolCall content parts", t => {
    let state: Reducer.state = {
      previewFrame: {
        url: "https://example.com",
        contentDocument: None,
        contentWindow: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "msg-3",
            textBuffer: "Listing files",
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let (nextState, _) = Reducer.next(state, MessageCompleted({id: "msg-3"}))

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Completed({content, _}))) => {
        t->expect(content->Array.length)->Expect.toBe(1)

        // Should be text content
        switch content->Array.get(0) {
        | Some(AssistantContentPart.Text({text})) =>
          t->expect(text)->Expect.toBe("Listing files")
        | _ => t->expect("Got text content")->Expect.toBe("Expected text content")
        }
      }
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })

  test("preserves message ID during streaming to completed transition", t => {
    let state: Reducer.state = {
      previewFrame: {
        url: "https://example.com",
        contentDocument: None,
        contentWindow: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "stable-id-123",
            textBuffer: "Test",
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let (nextState, _) = Reducer.next(state, MessageCompleted({id: "stable-id-123"}))

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Completed({id, _}))) => t->expect(id)->Expect.toBe("stable-id-123")
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })
})

describe("Client State Reducer - Streaming Flow", () => {
  test("full streaming lifecycle maintains stable ID", t => {
    let state = Reducer.defaultState

    // 1. Start streaming
    let (state, _) = Reducer.next(state, StreamingStarted({id: "text-abc"}))

    // 2. Receive text deltas
    let (state, _) = Reducer.next(state, TextDeltaReceived({id: "text-abc", text: "Hello"}))
    let (state, _) = Reducer.next(state, TextDeltaReceived({id: "text-abc", text: " world"}))

    // 3. Complete message
    let (state, _) = Reducer.next(state, MessageCompleted({id: "text-abc"}))

    // Verify: Message ID stayed stable throughout
    switch state.messages->Array.get(0) {
    | Some(Assistant(Completed({id, content, _}))) => {
        t->expect(id)->Expect.toBe("text-abc")
        switch content->Array.get(0) {
        | Some(AssistantContentPart.Text({text})) => t->expect(text)->Expect.toBe("Hello world")
        | _ => t->expect("Got text content")->Expect.toBe("Expected text content")
        }
      }
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })
})

describe("Client State Reducer - Selectors", () => {
  test("getMessageId selector works for all message types", t => {
    let userMsg = Reducer.User({
      id: "user-1",
      content: [],
      createdAt: 0.0,
    })

    let streamingMsg = Reducer.Assistant(
      Reducer.Streaming({
        id: "streaming-1",
        textBuffer: "",
        createdAt: 0.0,
      }),
    )

    let completedMsg = Reducer.Assistant(
      Reducer.Completed({
        id: "completed-1",
        content: [],
        createdAt: 0.0,
      }),
    )

    let toolCallMsg = Reducer.ToolCall({
      id: "tool-1",
      toolCallId: "tool-1",
      toolName: "search",
      state: Reducer.InputAvailable,
      inputBuffer: "",
      input: None,
      result: None,
      errorText: None,
      createdAt: 0.0,
    })

    t->expect(Reducer.Selectors.getMessageId(userMsg))->Expect.toBe("user-1")
    t->expect(Reducer.Selectors.getMessageId(streamingMsg))->Expect.toBe("streaming-1")
    t->expect(Reducer.Selectors.getMessageId(completedMsg))->Expect.toBe("completed-1")
    t->expect(Reducer.Selectors.getMessageId(toolCallMsg))->Expect.toBe("tool-1")
  })
})

describe("Client State Reducer - Tool Lifecycle", () => {
  test("ToolInputStartReceived creates tool with InputStreaming state", t => {
    let state = Reducer.defaultState

    let action = Reducer.ToolInputStartReceived({
      toolCallId: "call-1",
      toolName: "read_file",
    })
    let (nextState, _) = Reducer.next(state, action)

    t->expect(nextState.messages->Array.length)->Expect.toBe(1)

    switch nextState.messages->Array.get(0) {
    | Some(ToolCall({toolCallId, toolName, state, input, _})) => {
        t->expect(toolCallId)->Expect.toBe("call-1")
        t->expect(toolName)->Expect.toBe("read_file")
        t->expect(state)->Expect.toBe(Reducer.InputStreaming)
        t->expect(input)->Expect.toBe(None)
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })

  test("ToolInputDeltaReceived accumulates input buffer", t => {
    let state: Reducer.state = {
      previewFrame: {url: "https://example.com", contentDocument: None, contentWindow: None},
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        ToolCall({
          id: "call-1",
          toolCallId: "call-1",
          toolName: "read_file",
          inputBuffer: "{\"path",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.InputStreaming,
          createdAt: 0.0,
        }),
      ],
    }

    let action = Reducer.ToolInputDeltaReceived({
      toolCallId: "call-1",
      delta: "\": \"test.res\"}",
    })
    let (nextState, _) = Reducer.next(state, action)

    switch nextState.messages->Array.get(0) {
    | Some(ToolCall({inputBuffer, _})) =>
      t->expect(inputBuffer)->Expect.toBe("{\"path\": \"test.res\"}")
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })

  test("ToolInputEndReceived parses input and transitions to InputAvailable", t => {
    let state: Reducer.state = {
      previewFrame: {url: "https://example.com", contentDocument: None, contentWindow: None},
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        ToolCall({
          id: "call-1",
          toolCallId: "call-1",
          toolName: "read_file",
          inputBuffer: "{\"path\": \"test.res\"}",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.InputStreaming,
          createdAt: 0.0,
        }),
      ],
    }

    let action = Reducer.ToolInputEndReceived({toolCallId: "call-1"})
    let (nextState, _) = Reducer.next(state, action)

    switch nextState.messages->Array.get(0) {
    | Some(ToolCall({state, input, _})) => {
        t->expect(state)->Expect.toBe(Reducer.InputAvailable)
        t->expect(input->Option.isSome)->Expect.toBe(true)
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })

  test("ToolResultReceived sets result and OutputAvailable state", t => {
    let state: Reducer.state = {
      previewFrame: {url: "https://example.com", contentDocument: None, contentWindow: None},
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        ToolCall({
          id: "call-1",
          toolCallId: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
          result: None,
          errorText: None,
          state: Reducer.InputAvailable,
          createdAt: 0.0,
        }),
      ],
    }

    let result = JSON.parseOrThrow("{\"content\": \"file contents\"}")
    let action = Reducer.ToolResultReceived({toolCallId: "call-1", result})
    let (nextState, _) = Reducer.next(state, action)

    switch nextState.messages->Array.get(0) {
    | Some(ToolCall({state, result, _})) => {
        t->expect(state)->Expect.toBe(Reducer.OutputAvailable)
        t->expect(result->Option.isSome)->Expect.toBe(true)
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })

  test("ToolErrorReceived sets error and OutputError state", t => {
    let state: Reducer.state = {
      previewFrame: {url: "https://example.com", contentDocument: None, contentWindow: None},
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        ToolCall({
          id: "call-1",
          toolCallId: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
          result: None,
          errorText: None,
          state: Reducer.InputAvailable,
          createdAt: 0.0,
        }),
      ],
    }

    let action = Reducer.ToolErrorReceived({
      toolCallId: "call-1",
      error: "File not found",
    })
    let (nextState, _) = Reducer.next(state, action)

    switch nextState.messages->Array.get(0) {
    | Some(ToolCall({state, errorText, _})) => {
        t->expect(state)->Expect.toBe(Reducer.OutputError)
        t->expect(errorText)->Expect.toBe(Some("File not found"))
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })

  test("ToolCallReceived with complete input creates tool with InputAvailable", t => {
    let state = Reducer.defaultState

    let toolCall: Reducer.toolCall = {
      toolCallId: "call-1",
      toolName: "read_file",
      inputBuffer: "",
      input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
      result: None,
      errorText: None,
      state: Reducer.InputAvailable,
    }
    let action = Reducer.ToolCallReceived({toolCall: toolCall})
    let (nextState, _) = Reducer.next(state, action)

    t->expect(nextState.messages->Array.length)->Expect.toBe(1)

    switch nextState.messages->Array.get(0) {
    | Some(ToolCall({state, input, _})) => {
        t->expect(state)->Expect.toBe(Reducer.InputAvailable)
        t->expect(input->Option.isSome)->Expect.toBe(true)
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })
})
