module Conversation = {
    @react.component @module("@/components/ai-elements/conversation")
    external make: (~className: string, ~children: React.element) => React.element = "Conversation"
}

module ConversationContent = {
    @react.component @module("@/components/ai-elements/conversation")
    external make: (~children: React.element) => React.element = "ConversationContent"
}

module ConversationScrollButton = {
    @react.component @module("@/components/ai-elements/conversation")
    external make: unit => React.element = "ConversationScrollButton"
}

module Loader = {
    @react.component @module("@/components/ai-elements/loader")
    external make: unit => React.element = "Loader"
}

module Sources = {
    @react.component @module("@/components/ai-elements/sources")
    external make: (~children: React.element) => React.element = "Sources"
}

module SourcesTrigger = {
    @react.component @module("@/components/ai-elements/sources")
    external make: (~count: int) => React.element = "SourcesTrigger"
}

module SourcesContent = {
    @react.component @module("@/components/ai-elements/sources")
    external make: (~key: string, ~children: React.element) => React.element = "SourcesContent"
}

module Source = {
    @react.component @module("@/components/ai-elements/sources")
    external make: (~key: string, ~href: string, ~title: string) => React.element = "Source"
}

module Message = {
    @react.component @module("@/components/ai-elements/message")
    external make: (~from: string, ~className: string=?, ~children: React.element) => React.element = "Message"
}

module MessageContent = {
    @react.component @module("@/components/ai-elements/message")
    external make: (~className: string=?, ~variant: string=?, ~children: React.element) => React.element = "MessageContent"
}

module Response = {
    @react.component @module("@/components/ai-elements/response")
    external make: (~children: React.element) => React.element = "Response"
}

module Actions = {
    @react.component @module("@/components/ai-elements/actions")
    external make: (~className: string, ~children: React.element) => React.element = "Actions"
}

module Action = {
    @react.component @module("@/components/ai-elements/actions")
    external make: (~onClick: unit => unit, ~label: string, ~children: React.element) => React.element = "Action"
}

module Reasoning = {
    @react.component @module("@/components/ai-elements/reasoning")
    external make: (~key: string=?, ~className: string=?, ~isStreaming: bool=?, ~children: React.element) => React.element = "Reasoning"
}

module ReasoningTrigger = {
    @react.component @module("@/components/ai-elements/reasoning")
    external make: unit => React.element = "ReasoningTrigger"
}

module ReasoningContent = {
    @react.component @module("@/components/ai-elements/reasoning")
    external make: (~children: React.element) => React.element = "ReasoningContent"
}

module Tool = {
    @react.component @module("@/components/ai-elements/tool")
    external make: (~defaultOpen: bool=?, ~children: React.element) => React.element = "Tool"
}

module ToolHeader = {
    @react.component @module("@/components/ai-elements/tool")
    external make: (~title: React.element=?, @as("type") ~type_: string, ~state: string, ~className: string=?) => React.element = "ToolHeader"
}

module ToolContent = {
    @react.component @module("@/components/ai-elements/tool")
    external make: (~children: React.element) => React.element = "ToolContent"
}

module ToolInput = {
    @react.component @module("@/components/ai-elements/tool")
    external make: (~input: JSON.t) => React.element = "ToolInput"
}

module ToolOutput = {
    @react.component @module("@/components/ai-elements/tool")
    external make: (~output: React.element=?, ~errorText: string=?) => React.element = "ToolOutput"
}

module PromptInput = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~onSubmit: unit => unit, ~className: string, ~children: React.element, ~globalDrop: bool, ~multiple: bool) => React.element = "PromptInput"
}

module PromptInputHeader = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputHeader"
}

module PromptInputAttachments = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: 'a => React.element) => React.element = "PromptInputAttachments"
}

module PromptInputAttachment = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~data: 'a) => React.element = "PromptInputAttachment"
}

module PromptInputBody = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputBody"
}

module PromptInputTextarea = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~onChange: ReactEvent.Form.t => unit, ~value: string) => React.element = "PromptInputTextarea"
}

module PromptInputFooter = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputFooter"
}

module PromptInputTools = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputTools"
}

module PromptInputActionMenu = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputActionMenu"
}

module PromptInputActionMenuTrigger = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: unit => React.element = "PromptInputActionMenuTrigger"
}

module PromptInputActionMenuContent = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputActionMenuContent"
}

module PromptInputActionAddAttachments = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: unit => React.element = "PromptInputActionAddAttachments"
}

module PromptInputButton = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~variant: string, ~onClick: unit => unit, ~children: React.element) => React.element = "PromptInputButton"
}

module PromptInputModelSelect = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~onValueChange: string => unit, ~value: string, ~children: React.element) => React.element = "PromptInputModelSelect"
}

module PromptInputModelSelectTrigger = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputModelSelectTrigger"
}

module PromptInputModelSelectValue = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: unit => React.element = "PromptInputModelSelectValue"
}

module PromptInputModelSelectContent = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputModelSelectContent"
}

module PromptInputModelSelectItem = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~key: string, ~value: string, ~children: React.element) => React.element = "PromptInputModelSelectItem"
}

module PromptInputSubmit = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~disabled: bool, ~status: string) => React.element = "PromptInputSubmit"
}

// Web Preview components
type consoleLogLevel = [#log | #warn | #error]

type consoleLog = {
  level: consoleLogLevel,
  message: string,
  timestamp: Js.Date.t,
}

module WebPreview = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~className: string=?, ~defaultUrl: string=?, ~onUrlChange: string => unit=?, ~children: React.element) => React.element = "WebPreview"
}

module WebPreviewNavigation = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~className: string=?, ~children: React.element) => React.element = "WebPreviewNavigation"
}

module WebPreviewNavigationButton = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~onClick: unit => unit=?, ~disabled: bool=?, ~tooltip: string=?, ~children: React.element) => React.element = "WebPreviewNavigationButton"
}

module WebPreviewUrl = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~value: string=?, ~onChange: ReactEvent.Form.t => unit=?, ~onKeyDown: ReactEvent.Keyboard.t => unit=?) => React.element = "WebPreviewUrl"
}

module WebPreviewBody = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~className: string=?, ~loading: React.element=?, ~src: string=?) => React.element = "WebPreviewBody"
}

module WebPreviewConsole = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~className: string=?, ~logs: array<consoleLog>=?, ~children: React.element=?) => React.element = "WebPreviewConsole"
}

module Shimmer = {
    @react.component @module("@/components/ai-elements/shimmer")
    external make: (~children: React.element, ~duration: int=?, ~spread: int=?, ~className: string=?) => React.element = "Shimmer"
}

// Queue component types
type queueTodoStatus = [#pending | #completed]

type queueMessagePart = {
    @as("type") type_: string,
    text?: string,
    url?: string,
    filename?: string,
    mediaType?: string,
}

type queueMessage = {
    id: string,
    parts: array<queueMessagePart>,
}

type queueTodo = {
    id: string,
    title: string,
    description?: string,
    status?: queueTodoStatus,
}

// Queue components
module Queue = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~children: React.element) => React.element = "Queue"
}

module QueueSection = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~defaultOpen: bool=?, ~children: React.element) => React.element = "QueueSection"
}

module QueueSectionTrigger = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~children: React.element) => React.element = "QueueSectionTrigger"
}

module QueueSectionLabel = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~label: string, ~count: int=?, ~icon: React.element=?, ~className: string=?) => React.element = "QueueSectionLabel"
}

module QueueSectionContent = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~children: React.element) => React.element = "QueueSectionContent"
}

module QueueList = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~children: React.element) => React.element = "QueueList"
}

module QueueItem = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~children: React.element) => React.element = "QueueItem"
}

module QueueItemIndicator = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~completed: bool=?, ~className: string=?) => React.element = "QueueItemIndicator"
}

module QueueItemContent = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~completed: bool=?, ~className: string=?, ~children: React.element) => React.element = "QueueItemContent"
}

module QueueItemDescription = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~completed: bool=?, ~className: string=?, ~children: React.element) => React.element = "QueueItemDescription"
}

module QueueItemActions = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~children: React.element) => React.element = "QueueItemActions"
}

module QueueItemAction = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~onClick: unit => unit=?, ~children: React.element) => React.element = "QueueItemAction"
}

module QueueItemAttachment = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~children: React.element) => React.element = "QueueItemAttachment"
}

module QueueItemImage = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~src: string, ~alt: string=?, ~className: string=?) => React.element = "QueueItemImage"
}

module QueueItemFile = {
    @react.component @module("@/components/ai-elements/queue")
    external make: (~className: string=?, ~children: React.element) => React.element = "QueueItemFile"
}