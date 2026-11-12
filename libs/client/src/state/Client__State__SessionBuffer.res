open Client__State__Protocol

let getSessionTextBuffer = dispatch =>
  switch Client__TextDeltaBuffer.active.contents {
  | Some(buffer) => buffer
  | None =>
    let dispatchTask = (taskId, action) => dispatch(TaskAction({target: ForTask(taskId), action}))
    let buffer = Client__TextDeltaBuffer.make(
      ~onFlush=(~taskId, ~messageId, ~text, ~agentId) =>
        dispatchTask(taskId, TextDeltaReceived({messageId, text, agentId})),
      ~onUserFlush=(~taskId, ~messageId, ~blocks, ~agentId) => {
        let (content, annotations) = Client__ACP__MessageCodec.parseUserMessageBlocks(blocks)
        dispatchTask(taskId, UserMessageReceived({id: messageId, content, annotations, agentId}))
      },
    )
    Client__TextDeltaBuffer.active := Some(buffer)
    buffer
  }
