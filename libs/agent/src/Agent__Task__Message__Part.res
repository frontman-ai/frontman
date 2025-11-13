// Part types - opaque construction for type safety

module Base64 = Agent__Base64
S.enableJson()

// ============ TextPart ============

module TextPart = {
  @schema
  type t = {content: string}
}

// ============ Shared Data Content Types ============

// Data content - can be string (base64, etc) or binary data
@schema
type dataContent =
  | String(string)
  | Uint8Array(@s.matches(Base64.schema) Uint8Array.t)
  | ArrayBuffer(@s.matches(Base64.arrayBufferSchema) ArrayBuffer.t)

// ============ FilePart ============
module FilePart = {
  @schema
  type data =
    | Data({content: dataContent})
    | Url({url: string})

  @schema
  type t = {
    filename: @s.null option<string>,
    mediaType: string,
    data: data,
  }
}

module ImagePart = {
  @schema
  type t =
    | Data({content: dataContent, mediaType: @s.null option<string>})
    | Url({url: string, mediaType: @s.null option<string>})
}

// ============ DataPart ============

module DataPart = {
  @schema
  type t = {data: JSON.t}
}

// ============ ToolUsePart ============

module ToolCallPart = {
  @schema
  type t = {
    toolCallId: string,
    toolName: string,
    args: JSON.t,
  }
}

// ============ ToolResultPart ============

module ToolResultPart = {
  module Content = {
    @schema
    type t = Text(string) | Media({data: string, mediaType: string})
  }

  module Output = {
    @schema
    type t =
      | Text(string)
      | JSON(JSON.t)
      | ErrorText(string)
      | ErrorJSON(JSON.t)
      | Content(array<Content.t>)
  }

  @schema
  type t = {
    toolCallId: string,
    toolName: string,
    output: Output.t,
    @s.optional providerOptions: option<JSON.t>,
  }
}

// ============ Part Union ============

// Now has @schema - binary data is handled via base64 transformation
@schema
type t =
  | Text(TextPart.t)
  | File(FilePart.t)
  | Data(DataPart.t)
  | ToolCall(ToolCallPart.t)
  | ToolResult(ToolResultPart.t)
