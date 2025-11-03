// Bindings for Vercel AI SDK
// https://sdk.vercel.ai/docs

// Enable JSON support in Sury
S.enableJson()

// Import utilities
module Base64 = Agent__Base64
module DateISO = Agent__DateISO

// ============================================================================
// Core Types
// ============================================================================

type languageModel
type streamTextResult
type aiSchema

type role =
  | @as("user") User
  | @as("assistant") Assistant
  | @as("system") System
  | @as("tool") Tool

@schema
type usage = {
  promptTokens?: int,
  completionTokens?: int,
  totalTokens?: int,
}

@schema
type finishReason =
  | @as("stop") Stop
  | @as("length") Length
  | @as("content-filter") ContentFilter
  | @as("tool-calls") ToolCalls
  | @as("error") Error
  | @as("other") Other
  | @as("unknown") Unknown

// ============================================================================
// Message Parts
// ============================================================================

// Image/File data - opaque types that accept string | Uint8Array | ArrayBuffer

module ImageData = {
  type t
  external fromString: string => t = "%identity"
  external fromUint8Array: Uint8Array.t => t = "%identity"
  external fromArrayBuffer: ArrayBuffer.t => t = "%identity"
}

module FileData = {
  type t
  external fromString: string => t = "%identity"
  external fromUint8Array: Uint8Array.t => t = "%identity"
  external fromArrayBuffer: ArrayBuffer.t => t = "%identity"
}

module UserPart = {
  @tag("type")
  type t =
    | @as("text") Text({text: string})
    | @as("image") Image({image: ImageData.t, mediaType?: string})
    | @as("file") File({data: FileData.t, filename?: string, mediaType: string})

  let text = (text: string): t => Text({text: text})

  let imageFromString = (~url: string, ~mediaType): t => Image({
    image: ImageData.fromString(url),
    ?mediaType,
  })

  let imageFromUint8Array = (~data: Uint8Array.t, ~mediaType): t => Image({
    image: ImageData.fromUint8Array(data),
    ?mediaType,
  })

  let imageFromArrayBuffer = (~data: ArrayBuffer.t, ~mediaType): t => Image({
    image: ImageData.fromArrayBuffer(data),
    ?mediaType,
  })

  let fileFromString = (~url: string, ~mediaType, ~filename): t => File({
    data: FileData.fromString(url),
    mediaType,
    ?filename,
  })

  let fileFromUint8Array = (~data: Uint8Array.t, ~mediaType, ~filename): t => File({
    data: FileData.fromUint8Array(data),
    mediaType,
    ?filename,
  })

  let fileFromArrayBuffer = (~data: ArrayBuffer.t, ~mediaType, ~filename): t => File({
    data: FileData.fromArrayBuffer(data),
    mediaType,
    ?filename,
  })
}

module AssistantPart = {
  @tag("type")
  type t =
    | @as("text") Text({text: string})
    | @as("tool-call") ToolCall({toolCallId: string, toolName: string, input: JSON.t})

  let text = (text: string): t => Text({text: text})
}

module ToolResultPart = {
  type toolResultContentPart =
    | @as("text") TextContent({text: string})
    | @as("media") MediaContent({data: string, mediaType: string})

  @tag("type")
  type toolResultOutput =
    | @as("text") Text({value: string})
    | @as("json") Json({value: JSON.t})
    | @as("error-text") ErrorText({value: string})
    | @as("error-json") ErrorJson({value: JSON.t})
    | @as("content") Content({value: array<toolResultContentPart>})

  @tag("type")
  type t =
    | @as("tool-result")
    ToolResult({
        toolCallId: string,
        toolName: string,
        output: toolResultOutput,
        providerOptions?: JSON.t,
      })

  let textOutput = (value: string): toolResultOutput => Text({value: value})
  let jsonOutput = (value: JSON.t): toolResultOutput => Json({value: value})
  let errorText = (value: string): toolResultOutput => ErrorText({value: value})
  let errorJson = (value: JSON.t): toolResultOutput => ErrorJson({value: value})

  let create = (~toolCallId, ~toolName, ~output, ~providerOptions=?, ()): t => ToolResult({
    toolCallId,
    toolName,
    output,
    ?providerOptions,
  })
}

// ============================================================================
// Message Types
// ============================================================================

@unboxed
type userContent =
  | String(string)
  | Parts(array<UserPart.t>)

@unboxed
type assistantContent =
  | String(string)
  | Parts(array<AssistantPart.t>)

@unboxed
type toolContent = Parts(array<ToolResultPart.t>)

type systemModelMessage = {content: string}

type userModelMessage = {content: userContent}

type toolModelMessage = {content: toolContent}

@tag("role")
type modelMessage =
  | @as("system") SystemMessage({content: string})
  | @as("user") UserMessage({content: userContent})
  | @as("assistant") AssistantMessage({content: assistantContent})
  | @as("tool") ToolMessage({content: toolContent})

// Legacy message type (used by current implementation)
@unboxed
type content =
  | String(string)
  | Parts(array<JSON.t>)

type message = {
  role: role,
  content: content,
}

// ============================================================================
// Streaming
// ============================================================================

module AsyncIterableStream = {
  type readableStream<'a>
  type defaultReader<'a>
  type asyncIterator<'a> = AsyncIterator.t<'a>
  type t<'a>
  type readResult<'a> = {"done": bool, "value": 'a}

  external toReadableStream: t<'a> => readableStream<'a> = "%identity"
  external toAsyncIterator: t<'a> => asyncIterator<'a> = "%identity"
  external fromReadableStream: readableStream<'a> => t<'a> = "%identity"
  external fromAsyncIterator: asyncIterator<'a> => t<'a> = "%identity"

  @send external getReader: readableStream<'a> => defaultReader<'a> = "getReader"
  @send external read: defaultReader<'a> => Promise.t<readResult<'a>> = "read"
  @send external releaseLock: defaultReader<'a> => unit = "releaseLock"
}

// Supporting types for streamPart

@schema
type generatedFile = {
  base64: string,
  uint8Array: @s.matches(Base64.schema) Uint8Array.t,
  mediaType: string,
}

@schema
type requestMetadata = {body: JSON.t}

@schema
type responseMetadata = {
  id: string,
  model?: string,
  timestamp: @s.matches(DateISO.schema) Date.t,
  headers?: Dict.t<string>,
}

// Complete streamText fullStream types
// Represents all possible chunks from streamText().fullStream
// Based on official Vercel AI SDK documentation
@tag("type") @schema
type streamPart =
  | @as("start") Start({})
  | @as("start-step") StartStep({request: requestMetadata, warnings: array<JSON.t>})
  | @as("text-start") TextStart({id: string})
  | @as("text-delta") TextDelta({id: string, text: string})
  | @as("text-end") TextEnd({id: string})
  | @as("reasoning-start") ReasoningStart({id: string})
  | @as("reasoning-delta") ReasoningDelta({id: string, text: string})
  | @as("reasoning-end") ReasoningEnd({id: string})
  | @as("source")
  Source({
      sourceType: string, // Always "url" in current API
      id: string,
      url: string,
      title?: string,
      providerMetadata?: JSON.t,
    })
  | @as("file") File({file: generatedFile})
  | @as("tool-call") ToolCall({toolCallId: string, toolName: string, input: JSON.t})
  | @as("tool-input-start")
  ToolInputStart({
      id: string,
      toolName: string,
      providerExecuted?: bool,
      dynamic?: bool,
      title?: string,
    })
  | @as("tool-input-delta") ToolInputDelta({id: string, delta: string})
  | @as("tool-input-end") ToolInputEnd({id: string})
  | @as("tool-result")
  ToolResult({
      toolCallId: string,
      toolName: string,
      input: JSON.t,
      result: JSON.t,
    })
  | @as("tool-error") ToolError({toolCallId: string, toolName: string, error: JSON.t})
  | @as("finish-step")
  FinishStep({
      response?: responseMetadata,
      usage: usage,
      finishReason: finishReason,
      providerMetadata?: JSON.t,
    })
  | @as("finish") Finish({finishReason: finishReason, totalUsage: usage})
  | @as("abort") Abort({})
  | @as("error") Error({error: JSON.t})
  | @as("raw") Raw({value: JSON.t})

@get external fullStream: streamTextResult => AsyncIterableStream.t<streamPart> = "fullStream"
@get external finishReason: streamTextResult => promise<finishReason> = "finishReason"
@get external text: streamTextResult => promise<string> = "text"

// ============================================================================
// Tools
// ============================================================================

type toolDef = {
  description?: string,
  parameters: aiSchema,
  inputSchema: aiSchema,
  //Note(Danni) - although vercel supports executing tools, we want to manage this ourselves, so removing it for now
  // to avoid any chance of passing this in
  // execute?: JSON.t => promise<JSON.t>,
}

type toolCall = {
  toolCallId: string,
  toolName: string,
  args: JSON.t,
}

@get external toolCalls: streamTextResult => promise<array<toolCall>> = "toolCalls"

@module("ai") external jsonSchema: JSONSchema.t => aiSchema = "jsonSchema"

// ============================================================================
// API Functions
// ============================================================================

type streamTextParams = {
  model: languageModel,
  messages: array<modelMessage>,
  tools?: Dict.t<toolDef>,
  maxSteps?: int,
}

type response = {messages: array<modelMessage>}

@module("ai") external streamText: streamTextParams => promise<streamTextResult> = "streamText"
@get external response: streamTextResult => promise<response> = "response"

// ============================================================================
// Providers
// ============================================================================

module Anthropic = {
  @module("@ai-sdk/anthropic")
  external anthropic: string => languageModel = "anthropic"

  let claude3Sonnet = () => anthropic("claude-3-5-sonnet-20241022")
}

module OpenAI = {
  type openaiProvider

  type createOpenAIConfig = {apiKey: string}

  @module("@ai-sdk/openai")
  external createOpenAI: createOpenAIConfig => openaiProvider = "createOpenAI"

  @send
  external chat: (openaiProvider, string) => languageModel = "chat"

  let gpt4o = apiKey => {
    let provider = createOpenAI({apiKey: apiKey})
    provider->chat("gpt-4o-mini")
  }
}
