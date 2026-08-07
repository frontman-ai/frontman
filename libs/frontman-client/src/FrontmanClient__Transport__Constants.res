module Channel = FrontmanClient__Phoenix__Channel

let tasksTopic = "tasks"
let taskTopicPrefix = "task:"
let makeTaskTopic = (taskId: string) => `${taskTopicPrefix}${taskId}`

let acpMessageEvent: Channel.channelEvent = #"acp:message"
@@live
let mcpMessageEvent: Channel.channelEvent = #"mcp:message"
