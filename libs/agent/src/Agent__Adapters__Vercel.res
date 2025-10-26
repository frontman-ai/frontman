// Vercel AI SDK adapter - converts domain types to Vercel format
// This is the ONLY module that should import Bindings
//

// ============ LLM Type ============

// Opaque type - hides Vercel implementation details
module Bindings = Agent__Bindings__Vercel
module Part = Agent__Task__Message__Part
module Message = Agent__Task__Message
module UserPart = Agent__Adapters__Vercel__UserPart

type t = {
  model: Bindings.languageModel,
  tools: Dict.t<Bindings.toolDef>,
}

// ============ Type Re-exports ============
// Re-export types so AgenticLoop doesn't need to import bindings directly
type vercelMessage = Bindings.modelMessage
type streamResult = Bindings.streamTextResult
type toolCallInfo = Bindings.toolCall
type streamEvent = Bindings.streamPart

// ============ Tool Conversion ============

let toVercelTools = (registry: Agent__ToolsRegistry.t): Dict.t<Bindings.toolDef> => {
  let vercelTools = Dict.make()

  registry->Array.forEach(tool => {
    module Tool = unpack(tool: Agent__Tool.T)
    let aiSchemaWrapped = Bindings.jsonSchema(Tool.inputSchema->S.toJSONSchema)
    let toolDef: Bindings.toolDef = {
      description: Tool.description,
      parameters: aiSchemaWrapped,
      inputSchema: aiSchemaWrapped,
    }

    vercelTools->Dict.set(Tool.name, toolDef)
  })

  vercelTools
}

// ============ Message Conversion ============

// Helper to convert domain ToolResultPart.Output to Vercel ToolResultPart.Output
let toolResultOutputToVercel = (
  output: Part.ToolResultPart.Output.t,
): Bindings.ToolResultPart.toolResultOutput => {
  switch output {
  | Text(value) => Bindings.ToolResultPart.textOutput(value)
  | JSON(value) => Bindings.ToolResultPart.jsonOutput(value)
  | ErrorText(value) => Bindings.ToolResultPart.errorText(value)
  | ErrorJSON(value) => Bindings.ToolResultPart.errorJson(value)
  | Content(contentParts) => {
      let vercelContentParts = contentParts->Array.map(part => {
        switch part {
        | Part.ToolResultPart.Content.Text(text) => {
            let textValue = text
            Bindings.ToolResultPart.TextContent({text: textValue})
          }
        | Part.ToolResultPart.Content.Media({data, mediaType}) => {
            let dataValue = data
            let mediaTypeValue = mediaType
            Bindings.ToolResultPart.MediaContent({data: dataValue, mediaType: mediaTypeValue})
          }
        }
      })
      let contentValue = vercelContentParts
      Bindings.ToolResultPart.Content({value: contentValue})
    }
  }
}

let messageToVercel = (msg: Message.t): Bindings.modelMessage => {
  switch msg {
  | System(systemMsg) =>
    Bindings.SystemMessage({
      content: systemMsg.content,
    })

  | User({content: Message.User.String(text)}) =>
    Bindings.UserMessage({
      content: Bindings.String(text),
    })

  | User({content: List(parts)}) => {
      let vercelParts = UserPart.arrayToVercel(parts)
      let content: Bindings.userContent = Parts(vercelParts)
      Bindings.UserMessage({
        content: content,
      })
    }

  | Assistant({content: Message.Assistant.String(text)}) =>
    Bindings.AssistantMessage({
      content: String(text),
    })

  | Assistant({content: Message.Assistant.List(parts)}) => {
      let vercelParts = parts->Array.map(part => {
        switch part {
        | Message.Assistant.Text({content}) => Bindings.AssistantPart.text(content)
        | Message.Assistant.ToolCall(toolCallPart) =>
          Bindings.AssistantPart.ToolCall({
            toolCallId: toolCallPart.toolCallId,
            toolName: toolCallPart.toolName,
            input: toolCallPart.args,
          })
        }
      })
      let content: Bindings.assistantContent = Parts(vercelParts)
      Bindings.AssistantMessage({
        content: content,
      })
    }

  | Tool(toolResults) => {
      let vercelParts = toolResults.content->Array.map(toolResult => {
        Bindings.ToolResultPart.create(
          ~toolCallId=toolResult.toolCallId,
          ~toolName=toolResult.toolName,
          ~output=toolResultOutputToVercel(toolResult.output),
          ~providerOptions=?toolResult.providerOptions,
          (),
        )
      })
      let content: Bindings.toolContent = Parts(vercelParts)
      Bindings.ToolMessage({
        content: content,
      })
    }
  }
}

let messagesToVercel = (messages: array<Agent__Task__Message.t>): array<vercelMessage> => {
  messages->Array.map(messageToVercel)
}

// Convert Vercel modelMessage back to domain message
let messageFromVercel = (msg: Bindings.modelMessage, ~taskId: option<Agent__Task__Id.t>=?): option<
  Agent__Task__Message.t,
> => {
  switch msg {
  | SystemMessage({content}) =>
    Some(
      Agent__Task__Message.System({
        taskId,
        content,
      }),
    )

  | UserMessage({content: String(text)}) =>
    Some(Agent__Task__Message.User({?taskId, content: String(text)}))

  | UserMessage({content: Parts(parts), _}) => {
      let domainParts = UserPart.arrayFromVercel(parts)
      Some(Agent__Task__Message.User({?taskId, content: List(domainParts)}))
    }

  | AssistantMessage({content: String(text)}) =>
    Some(
      Agent__Task__Message.Assistant({
        taskId,
        content: Agent__Task__Message.Assistant.String(text),
      }),
    )

  | AssistantMessage({content: Parts(parts)}) => {
      Console.log2("Converting AssistantMessage with parts:", parts)
      let domainParts = parts->Array.map(part => {
        switch part {
        | Bindings.AssistantPart.Text({text}) =>
          Agent__Task__Message.Assistant.Text({content: text})
        | Bindings.AssistantPart.ToolCall({toolCallId, toolName, input}) => {
            Console.log3("ToolCall part:", toolName, input)
            Agent__Task__Message.Assistant.ToolCall({
              toolCallId,
              toolName,
              args: input,
            })
          }
        }
      })
      Some(
        Agent__Task__Message.Assistant({
          taskId,
          content: Agent__Task__Message.Assistant.List(domainParts),
        }),
      )
    }

  | ToolMessage({content: Parts(parts)}) =>
    // We execute tools ourselves via Reactor, but Vercel is still returning tool results
    // This shouldn't happen with maxSteps: 1, but we filter them out anyway
    Console.error2("Vercel returned tool result message (filtered out):", parts)
    None
  }
}

// ============ LLM Creation ============

let makeLLM = (~model: Bindings.languageModel, ~toolRegistry: Agent__ToolsRegistry.t): t => {
  let tools = toVercelTools(toolRegistry)
  {model, tools}
}

// ============ Stream Result Accessors ============

// Accessor functions for streamResult - shields AgenticLoop from Vercel bindings
let getFullStream = (result: streamResult) => result->Bindings.fullStream
let getResponse = (result: streamResult) => result->Bindings.response
let getFinishReason = (result: streamResult) => result->Bindings.finishReason
let getToolCalls = (result: streamResult) => result->Bindings.toolCalls
let getText = (result: streamResult) => result->Bindings.text

// ============ Stream Processing ============

// Process an async iterable (like ReadableStream) using for-await-of pattern
// This is more efficient than recursive iteration
let processAsyncIterable = (
  iterable: Bindings.AsyncIterableStream.t<streamEvent>,
  handler: streamEvent => promise<unit>,
): promise<unit> => {
  let impl: (
    Bindings.AsyncIterableStream.t<streamEvent>,
    streamEvent => promise<unit>,
  ) => promise<unit> = %raw(`
    async function(iterable, handler) {
      for await (const chunk of iterable) {
        await handler(chunk);
      }
    }
  `)
  impl(iterable, handler)
}

// ============ Stream Text ============

// Stream text with Vercel messages directly (for manual loop control)
let streamText = async (llm: t, messages: array<Agent__Task__Message.t>): streamResult => {
  let messages = messagesToVercel(messages)
  await Bindings.streamText({
    model: llm.model,
    messages,
    tools: llm.tools,
    maxSteps: 1, // Prevent Vercel from auto-executing tools - we handle execution via Reactor
  })
}
