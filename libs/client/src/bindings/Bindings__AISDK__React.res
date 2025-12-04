// AI SDK React bindings for ReScript
// @ai-sdk/react hooks and types

// Message part types - using a discriminated union via record
type messagePart = {
  @as("type") type_: string,
  text: option<string>,
  url: option<string>,
}

// Message type
type message = {
  id: string,
  role: string,
  parts: array<messagePart>,
}

// Chat status
type chatStatus = string

// SendMessage function type
type sendMessage = (
  {"text": option<string>, "files": option<array<WebAPI.FileAPI.file>>},
  {"body": {"model": string, "webSearch": bool}},
) => unit

// UseChat return type
type useChatReturn = {
  messages: array<message>,
  sendMessage: sendMessage,
  status: chatStatus,
  regenerate: unit => unit,
}

// useChat hook
@module("@ai-sdk/react")
external useChat: unit => useChatReturn = "useChat"
