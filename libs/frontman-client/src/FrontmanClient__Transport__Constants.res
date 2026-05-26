// Transport-specific constants
// Channel topics use domain terminology (Tasks), not ACP terminology (Sessions)

module Channel = FrontmanClient__Phoenix__Channel

// Channel topics
let tasksTopic = "tasks"
let taskTopicPrefix = "task:"
let makeTaskTopic = (taskId: string) => `${taskTopicPrefix}${taskId}`

// Channel events
let acpMessageEvent: Channel.channelEvent = #"acp:message"
@@live
let mcpMessageEvent: Channel.channelEvent = #"mcp:message"
