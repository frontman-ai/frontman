open Vitest

module Buffer = Client__TextDeltaBuffer
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock

type flushEntry = {
  taskId: string,
  messageId: string,
  text: string,
  agentId: string,
}

let makeBuffer = (
  ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~agentId as _) => (),
  ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~agentId as _) => (),
) => Buffer.make(~onFlush, ~onUserFlush)

let addAssistant = (
  buffer: Buffer.t,
  ~text,
  ~taskId="task-1",
  ~messageId="message-1",
  ~agentId="executor-id",
) => buffer.add(~taskId, ~messageId, ~text, ~agentId)

let addUserBlock = (buffer: Buffer.t, ~block, ~messageId) =>
  buffer.addUserBlock(~taskId="task-1", ~messageId, ~block, ~agentId="executor-id")

describe("TextDeltaBuffer", () => {
  test("discardTask removes only failed task buffers", t => {
    let flushed = ref([])
    let buffer = makeBuffer(
      ~onFlush=(~taskId, ~messageId as _, ~text as _, ~agentId as _) =>
        flushed := flushed.contents->Array.concat([taskId]),
    )
    addAssistant(buffer, ~taskId="failed-task", ~messageId="failed-message", ~text="discard")
    addAssistant(buffer, ~taskId="healthy-task", ~messageId="healthy-message", ~text="keep")

    buffer.discardTask("failed-task")
    buffer.flush()
    addAssistant(
      buffer,
      ~taskId="replacement-task",
      ~messageId="failed-message",
      ~text="replacement",
      ~agentId="planner-id",
    )
    buffer.flush()

    t->expect(flushed.contents)->Expect.toEqual(["healthy-task", "replacement-task"])
  })

  test("groups user blocks by message before flushing", t => {
    let flushed = ref(None)
    let first = ContentBlock.TextContent({text: "one", _meta: None, annotations: None})
    let second = ContentBlock.TextContent({text: "two", _meta: None, annotations: None})
    let buffer = makeBuffer(
      ~onUserFlush=(~taskId, ~messageId, ~blocks, ~agentId) =>
        flushed := Some((taskId, messageId, blocks, agentId)),
    )

    addUserBlock(buffer, ~messageId="user-1", ~block=first)
    addUserBlock(buffer, ~messageId="user-1", ~block=second)
    buffer.flush()

    t
    ->expect(flushed.contents)
    ->Expect.toEqual(Some(("task-1", "user-1", [first, second], "executor-id")))
  })

  test("flush synchronously dispatches all pending entries", t => {
    let flushed: ref<array<flushEntry>> = ref([])
    let buffer = makeBuffer(
      ~onFlush=(~taskId, ~messageId, ~text, ~agentId) => {
        flushed.contents = flushed.contents->Array.concat([{taskId, messageId, text, agentId}])
      },
    )
    addAssistant(buffer, ~text="Hello ")
    addAssistant(buffer, ~text="world")
    addAssistant(buffer, ~messageId="message-2", ~text="Plan")
    addAssistant(
      buffer,
      ~taskId="task-2",
      ~messageId="message-2",
      ~text="Other",
      ~agentId="planner-id",
    )

    // Before flush: nothing dispatched (pending in rAF)
    t->expect(flushed.contents->Array.length)->Expect.toBe(0)

    // Flush synchronously dispatches everything
    buffer.flush()
    t->expect(flushed.contents->Array.length)->Expect.toBe(3)

    // task-1 text was concatenated without merging its interleaved message IDs
    let task1Entry =
      flushed.contents->Array.find(e => e.taskId === "task-1" && e.messageId === "message-1")
    t->expect(task1Entry->Option.map(e => e.text))->Expect.toBe(Some("Hello world"))
    t->expect(task1Entry->Option.map(e => e.agentId))->Expect.toBe(Some("executor-id"))
    let task1SecondMessage =
      flushed.contents->Array.find(e => e.taskId === "task-1" && e.messageId === "message-2")
    t->expect(task1SecondMessage->Option.map(e => e.text))->Expect.toBe(Some("Plan"))

    // task-2 is separate
    let task2Entry = flushed.contents->Array.find(e => e.taskId === "task-2")
    t->expect(task2Entry->Option.map(e => e.text))->Expect.toBe(Some("Other"))

    buffer.flush()
    t->expect(flushed.contents->Array.length)->Expect.toBe(3)
  })

  test("reset discards pending entries", t => {
    let callCount = ref(0)
    let buffer = makeBuffer(
      ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~agentId as _) => {
        callCount := callCount.contents + 1
      },
    )
    addAssistant(buffer, ~text="Hello")
    buffer.reset()
    t->expect(callCount.contents)->Expect.toBe(0)

    addAssistant(buffer, ~taskId="task-2", ~text="Reused after reset", ~agentId="planner-id")
    buffer.flush()
    t->expect(callCount.contents)->Expect.toBe(1)
  })
})
