module Agent = AskTheLlmAgent.Agent
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel
let name = "Client::StateReducer"

// ============================================================================
// Message Content Types
// ============================================================================

module UserContentPart = Vercel.UserPart
module AssistantContentPart = Vercel.AssistantPart

type toolCallState =
  | InputStreaming // Parameters are streaming in
  | InputAvailable // Parameters complete, executing
  | OutputAvailable // Completed successfully
  | OutputError // Failed with error

type toolCall = {
  toolCallId: string,
  toolName: string,
  // Input accumulation during streaming
  inputBuffer: string, // Raw streamed JSON (for ToolInputDelta)
  input: option<JSON.t>, // Parsed complete input
  // Execution results
  result: option<JSON.t>, // Tool output
  errorText: option<string>, // Error message
  // State tracking
  state: toolCallState,
}

// ============================================================================
// Message Types
// ============================================================================

// Assistant messages can be streaming or completed
type assistantMessage =
  | Streaming({id: string, textBuffer: string, createdAt: float})
  | Completed({id: string, content: array<AssistantContentPart.t>, createdAt: float})

// Top-level message variant
type message =
  | User({id: string, content: array<UserContentPart.t>, createdAt: float})
  | Assistant(assistantMessage)
  | ToolCall({
      id: string,
      toolCallId: string,
      toolName: string,
      state: toolCallState,
      inputBuffer: string,
      input: option<JSON.t>,
      result: option<JSON.t>,
      errorText: option<string>,
      createdAt: float,
    })

// Preview frame with URL and optional loaded document/window
type previewFrame = {
  url: string,
  contentDocument: option<WebAPI.DOMAPI.document>,
  contentWindow: option<WebAPI.DOMAPI.window>,
}

module SelectedElement = {
  type t = {
    element: WebAPI.DOMAPI.element,
    selector: option<string>,
    screenshot: option<string>,
    sourceLocation: option<Client__Types.sourceLocation>,
  }

  let make = (~element: WebAPI.DOMAPI.element, ~selector: option<string>, ~screenshot: option<string>, ~sourceLocation: option<Client__Types.sourceLocation>) => {
    {
      element,
      selector,
      screenshot,
      sourceLocation,
    }
  }

  let withoutElement = (selectedElement: option<t>) => {
    switch selectedElement {
    | Some(selectedElement) => {
        "selector": selectedElement.selector,
        "screenshot": selectedElement.screenshot,
        "sourceLocation": selectedElement.sourceLocation
      }->Some
    | None => None
    }
  }
}
type state = {
  messages: array<message>,
  previewFrame: previewFrame,
  webPreviewIsSelecting: bool,
  selectedElement: option<SelectedElement.t>,
}

type action =
  // User actions
  | AddUserMessage({id: string, content: array<UserContentPart.t>})
  // Streaming actions (from SSE events)
  | StreamingStarted({id: string})
  | TextDeltaReceived({id: string, text: string})
  | ToolCallReceived({toolCall: toolCall})
  | ToolInputStartReceived({toolCallId: string, toolName: string})
  | ToolInputDeltaReceived({toolCallId: string, delta: string})
  | ToolInputEndReceived({toolCallId: string})
  | ToolResultReceived({toolCallId: string, result: JSON.t})
  | ToolErrorReceived({toolCallId: string, error: string})
  // Completion action
  | MessageCompleted({id: string})
  // Preview frame actions
  | SetPreviewUrl({url: string})
  | SetPreviewFrame({
      contentDocument: option<WebAPI.DOMAPI.document>,
      contentWindow: option<WebAPI.DOMAPI.window>,
    })
  // WebPreview selection actions
  | ToggleWebPreviewSelection
  | SetSelectedElement({selectedElement: option<SelectedElement.t>})

// Effects for side effects
type effect =
  | SendMessageToAPI({message: string})
  | FetchElementDetails({element: WebAPI.DOMAPI.element, document: option<WebAPI.DOMAPI.document>})

let getInitialUrl = () => {
  // Check if window is available (browser environment)
  switch %external(window) {
  | Some(win) => {
      let currentUrl = win->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
      `${currentUrl.protocol}//${currentUrl.host}`
    }
  | None => "http://localhost:3000" // Default for test environment
  }
}

let defaultState: state = {
  messages: [],
  previewFrame: {url: getInitialUrl(), contentDocument: None, contentWindow: None},
  webPreviewIsSelecting: false,
  selectedElement: None,
}

let actionToString = action => {
  switch action {
  | AddUserMessage({id, _}) => `AddUserMessage(${id})`
  | StreamingStarted({id}) => `StreamingStarted(${id})`
  | TextDeltaReceived({id, text}) => `TextDeltaReceived(${id}, "${text}")`
  | ToolCallReceived({toolCall}) => `ToolCallReceived(${toolCall.toolName})`
  | ToolInputStartReceived({toolCallId, toolName, _}) =>
    `ToolInputStartReceived(${toolCallId}, ${toolName})`
  | ToolInputDeltaReceived({toolCallId, _}) => `ToolInputDeltaReceived(${toolCallId})`
  | ToolInputEndReceived({toolCallId, _}) => `ToolInputEndReceived(${toolCallId})`
  | ToolResultReceived({toolCallId, _}) => `ToolResultReceived(${toolCallId})`
  | ToolErrorReceived({toolCallId, _}) => `ToolErrorReceived(${toolCallId})`
  | MessageCompleted({id}) => `MessageCompleted(${id})`
  | SetPreviewUrl({url}) => `SetPreviewUrl(${url})`
  | SetPreviewFrame(_) => `SetPreviewFrame(contentDocument, contentWindow)`
  | ToggleWebPreviewSelection => `ToggleWebPreviewSelection`
  | SetSelectedElement(_) => `SetSelectedElement`
  }
}

let handleEffect = (effect, state, dispatch) => {
  switch effect {
  | SendMessageToAPI({message}) => {
      let headers = WebAPI.Headers.make()
      headers->WebAPI.Headers.set(~name="Content-Type", ~value="application/json")

      let body = JSON.stringifyAny({"message": message, "selectedElement": SelectedElement.withoutElement(state.selectedElement)})->Option.getOr("{}")

      let _ =
        WebAPI.Global.fetch(
          "/api/ask-the-llm/chat",
          ~init={
            method: "POST",
            headers: WebAPI.HeadersInit.fromHeaders(headers),
            body: WebAPI.BodyInit.fromString(body),
          },
        )
        ->Promise.then(response => {
          Console.log2("[Effect] Message sent to API:", response)
          Promise.resolve()
        })
        ->Promise.catch(error => {
          Console.error2("[Effect] Failed to send message to API:", error)
          Promise.resolve()
        })
    }
  | FetchElementDetails({element, document}) => {
      // Fetch selector
      let selectorPromise = Promise.resolve()->Promise.then(_ => {
        let selector = Bindings__Finder.finder(
          ~element,
          ~options={
            root: document
            ->Option.map(doc => doc.documentElement->Obj.magic)
            ->Option.getOr(element),
            idName: (~name as _) => true,
            className: (~name as _) => true,
            tagName: (~name as _) => true,
            attr: (~name as _, ~value as _) => false,
          },
        )
        Promise.resolve(Some(selector))
      })

      // Fetch screenshot
      let screenshotPromise =
        Bindings__Snapdom.snapdom(~element)
        ->Promise.then(captureResult => {
          Promise.resolve(Some(captureResult.url))
        })
        ->Promise.catch(error => {
          Console.error2("Failed to capture screenshot:", error)
          Promise.resolve(None)
        })

      // Fetch source location
      let sourceLocationPromise =
        Bindings__DOMElementToComponentSource.getElementSourceLocation(~element)
        ->Promise.then(sourceLocationOpt => {
          Promise.resolve(sourceLocationOpt)
        })
        ->Promise.catch(error => {
          Console.error2("Failed to get source location:", error)
          Promise.resolve(None)
        })

      // Wait for all promises and update state once
      let _ = Promise.all3((selectorPromise, screenshotPromise, sourceLocationPromise))
        ->Promise.then(((selector, screenshot, sourceLocation)) => {
          dispatch(SetSelectedElement({selectedElement: Some({
            element: element,
            selector: selector,
            screenshot: screenshot,
            sourceLocation: sourceLocation->Option.map(sourceLoc => {
              {...sourceLoc, file: sourceLoc.file->String.split("?")->Array.get(0)->Option.getOr(sourceLoc.file)}
            }),
          })}))
          Promise.resolve()
        })
    }
  }
}

// Helper to extract text content from user message parts
let extractTextFromUserContent = (content: array<UserContentPart.t>): string => {
  content
  ->Array.filterMap(part => {
    switch part {
    | Text({text}) => Some(text)
    | Image({image: _, mediaType: _}) => %todo("add this")
    | Image({image: _}) => %todo("add this")
    | File(_) => %todo("add this")
    }
  })
  ->Array.join(" ")
}

let next = (state, action) => {
  switch action {
  // Add user message to end of messages array
  | AddUserMessage({id, content}) => {
      let message = User({
        id,
        content,
        createdAt: Date.now(),
      })
      let textContent = extractTextFromUserContent(content)
      AskTheLlmReactStatestore.StateReducer.update(
        {
          messages: Array.concat(state.messages, [message]),
          previewFrame: state.previewFrame,
          webPreviewIsSelecting: state.webPreviewIsSelecting,
          selectedElement: state.selectedElement,
        },
        ~sideEffects=[SendMessageToAPI({message: textContent})],
      )
    }

  // Start streaming a new assistant message
  | StreamingStarted({id}) => {
      let message = Assistant(
        Streaming({
          id,
          textBuffer: "",
          createdAt: Date.now(),
        }),
      )
      AskTheLlmReactStatestore.StateReducer.update({
        messages: Array.concat(state.messages, [message]),
        previewFrame: state.previewFrame,
        webPreviewIsSelecting: state.webPreviewIsSelecting,
        selectedElement: state.selectedElement,
      })
    }

  // Append text delta to streaming message
  | TextDeltaReceived({id, text}) => {
      let updatedMessages = state.messages->Array.map(msg => {
        switch msg {
        | Assistant(Streaming({id: msgId, textBuffer, createdAt})) if msgId == id =>
          Assistant(
            Streaming({
              id: msgId,
              textBuffer: textBuffer ++ text,
              createdAt,
            }),
          )
        | other => other
        }
      })
      AskTheLlmReactStatestore.StateReducer.update({
        messages: updatedMessages,
        previewFrame: state.previewFrame,
        webPreviewIsSelecting: state.webPreviewIsSelecting,
        selectedElement: state.selectedElement,
      })
    }

  // Tool call with complete input (Path A: ToolCall event)
  | ToolCallReceived({toolCall}) => {
      let existingIndex = state.messages->Array.findIndex(msg =>
        switch msg {
        | ToolCall(tool) => tool.toolCallId == toolCall.toolCallId
        | _ => false
        }
      )

      let messages = if existingIndex >= 0 {
        // Update existing ToolCall message
        state.messages->Array.mapWithIndex((msg, i) =>
          if i == existingIndex {
            switch msg {
            | ToolCall(tool) =>
              ToolCall({
                ...tool,
                toolName: toolCall.toolName,
                input: toolCall.input,
                state: InputAvailable,
              })
            | other => other
            }
          } else {
            msg
          }
        )
      } else {
        // Create new ToolCall message
        let newMessage = ToolCall({
          id: toolCall.toolCallId,
          toolCallId: toolCall.toolCallId,
          toolName: toolCall.toolName,
          inputBuffer: "",
          input: toolCall.input,
          result: None,
          errorText: None,
          state: InputAvailable,
          createdAt: Date.now(),
        })
        Array.concat(state.messages, [newMessage])
      }

      AskTheLlmReactStatestore.StateReducer.update({
        ...state,
        messages,
      })
    }

  // Tool input streaming started (Path B: ToolInputStart event)
  | ToolInputStartReceived({toolCallId, toolName}) => {
      let existingIndex = state.messages->Array.findIndex(msg =>
        switch msg {
        | ToolCall(tool) => tool.toolCallId == toolCallId
        | _ => false
        }
      )

      let messages = if existingIndex >= 0 {
        // Update existing ToolCall message
        state.messages->Array.mapWithIndex((msg, i) =>
          if i == existingIndex {
            switch msg {
            | ToolCall(tool) =>
              ToolCall({
                ...tool,
                toolName,
                state: InputStreaming,
              })
            | other => other
            }
          } else {
            msg
          }
        )
      } else {
        // Create new ToolCall message
        let newMessage = ToolCall({
          id: toolCallId,
          toolCallId,
          toolName,
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: InputStreaming,
          createdAt: Date.now(),
        })
        Array.concat(state.messages, [newMessage])
      }

      AskTheLlmReactStatestore.StateReducer.update({
        ...state,
        messages,
      })
    }

  // Tool input delta received (streaming parameters)
  | ToolInputDeltaReceived({toolCallId, delta}) => {
      let updatedMessages = state.messages->Array.map(msg => {
        switch msg {
        | ToolCall(tool) if tool.toolCallId == toolCallId =>
          ToolCall({...tool, inputBuffer: tool.inputBuffer ++ delta})
        | other => other
        }
      })
      AskTheLlmReactStatestore.StateReducer.update({...state, messages: updatedMessages})
    }

  // Tool input complete (parse buffered JSON)
  | ToolInputEndReceived({toolCallId}) => {
      let updatedMessages = state.messages->Array.map(msg => {
        switch msg {
        | ToolCall(tool) if tool.toolCallId == toolCallId => {
            let parsedInput = try {
              Some(JSON.parseOrThrow(tool.inputBuffer))
            } catch {
            | _ => None
            }
            ToolCall({...tool, input: parsedInput, state: InputAvailable})
          }
        | other => other
        }
      })
      AskTheLlmReactStatestore.StateReducer.update({...state, messages: updatedMessages})
    }

  // Tool execution completed with result
  | ToolResultReceived({toolCallId, result}) => {
      let updatedMessages = state.messages->Array.map(msg => {
        switch msg {
        | ToolCall(tool) if tool.toolCallId == toolCallId =>
          ToolCall({...tool, result: Some(result), state: OutputAvailable})
        | other => other
        }
      })
      AskTheLlmReactStatestore.StateReducer.update({...state, messages: updatedMessages})
    }

  // Tool execution failed with error
  | ToolErrorReceived({toolCallId, error}) => {
      let updatedMessages = state.messages->Array.map(msg => {
        switch msg {
        | ToolCall(tool) if tool.toolCallId == toolCallId =>
          ToolCall({...tool, errorText: Some(error), state: OutputError})
        | other => other
        }
      })
      AskTheLlmReactStatestore.StateReducer.update({...state, messages: updatedMessages})
    }

  // Transition streaming message to completed
  | MessageCompleted({id}) => {
      let updatedMessages = state.messages->Array.map(msg => {
        switch msg {
        | Assistant(Streaming({id: msgId, textBuffer, createdAt})) if msgId == id => {
            let content = if String.length(textBuffer) > 0 {
              [AssistantContentPart.Text({text: textBuffer})]
            } else {
              []
            }
            Assistant(Completed({id: msgId, content, createdAt}))
          }
        | other => other
        }
      })
      AskTheLlmReactStatestore.StateReducer.update({
        ...state,
        messages: updatedMessages,
        previewFrame: state.previewFrame,
        webPreviewIsSelecting: state.webPreviewIsSelecting,
        selectedElement: state.selectedElement,
      })
    }

  // Set preview URL (clears document and window)
  | SetPreviewUrl({url}) =>
    AskTheLlmReactStatestore.StateReducer.update({
      messages: state.messages,
      previewFrame: {...state.previewFrame ,url},
      webPreviewIsSelecting: state.webPreviewIsSelecting,
      selectedElement: state.selectedElement,
    })

  // Set preview frame (keep existing URL)
  | SetPreviewFrame({contentDocument, contentWindow}) =>
    AskTheLlmReactStatestore.StateReducer.update({
      messages: state.messages,
      previewFrame: {...state.previewFrame, contentDocument, contentWindow},
      webPreviewIsSelecting: state.webPreviewIsSelecting,
      selectedElement: state.selectedElement,
    })

  // Toggle WebPreview selection mode
  | ToggleWebPreviewSelection =>
    AskTheLlmReactStatestore.StateReducer.update({
      messages: state.messages,
      previewFrame: state.previewFrame,
      webPreviewIsSelecting: !state.webPreviewIsSelecting,
      // Clear selected element when turning selection mode ON
      selectedElement: if !state.webPreviewIsSelecting {
        None // Turning ON - clear selection
      } else {
        state.selectedElement // Turning OFF - keep selection
      },
    })

  // Set selected element and reset selection mode
  | SetSelectedElement({selectedElement}) => {
      // Determine if we need to fetch details
      let shouldFetchDetails = switch selectedElement {
      | Some({element, selector: None, screenshot: None, sourceLocation: None}) =>
          // New element with no details - trigger fetch
          Some(FetchElementDetails({
            element: element,
            document: state.previewFrame.contentDocument,
          }))
      | _ => None // Element with details or clearing selection - no fetch needed
      }

      AskTheLlmReactStatestore.StateReducer.update(
        {
          messages: state.messages,
          previewFrame: state.previewFrame,
          webPreviewIsSelecting: false, // Auto-reset selection mode
          selectedElement,
        },
        ~sideEffects=shouldFetchDetails->Option.mapOr([], effect => [effect]),
      )
    }
  }
}

module Selectors = {
  // Get all messages (maintains order)
  let messages = (state: state) => state.messages

  // Get only completed messages
  let completedMessages = (state: state) =>
    state.messages->Array.filter(msg => {
      switch msg {
      | User(_) => true
      | Assistant(Completed(_)) => true
      | Assistant(Streaming(_)) => false
      | ToolCall({state: OutputAvailable | OutputError, _}) => true
      | ToolCall(_) => false
      }
    })

  // Get streaming messages
  let streamingMessages = (state: state) =>
    state.messages->Array.filterMap(msg => {
      switch msg {
      | Assistant(Streaming(_) as streaming) => Some(streaming)
      | _ => None
      }
    })

  // Check if any message is currently streaming
  let isStreaming = (state: state) =>
    state.messages->Array.some(msg => {
      switch msg {
      | Assistant(Streaming(_)) => true
      | ToolCall({state: InputStreaming | InputAvailable, _}) => true
      | _ => false
      }
    })

  // Get last message
  let lastMessage = (state: state) => state.messages->Array.get(Array.length(state.messages) - 1)

  // Extract stable ID for React keys
  let getMessageId = (msg: message): string => {
    switch msg {
    | User({id, _}) => id
    | Assistant(Streaming({id, _})) => id
    | Assistant(Completed({id, _})) => id
    | ToolCall({id, _}) => id
    }
  }

  // Get preview document state
  let previewFrame = (state: state) => state.previewFrame

  // Get webPreview selection mode
  let webPreviewIsSelecting = (state: state) => state.webPreviewIsSelecting

  // Get selected element
  let selectedElement = (state: state) => state.selectedElement

  // Get preview URL
  let previewUrl = (state: state) => state.previewFrame.url
}
