open Vitest

module Buffer = Client__TextDeltaBuffer

type flushEntry = {taskId: string, text: string, timestamp: string, agentId: string}

describe("TextDeltaBuffer", () => {
  test("flush synchronously dispatches all pending entries", t => {
    let flushed: ref<array<flushEntry>> = ref([])
    let buffer = Buffer.make(
      ~onFlush=(~taskId, ~text, ~timestamp, ~agentId) => {
        flushed.contents = flushed.contents->Array.concat([{taskId, text, timestamp, agentId}])
      },
    )
    buffer.selectAgent(~taskId="task-1", ~agentId="executor-id")
    buffer.selectAgent(~taskId="task-2", ~agentId="planner-id")
    buffer.add(~taskId="task-1", ~text="Hello ", ~timestamp="2024-01-15T10:00:00Z")
    buffer.add(~taskId="task-1", ~text="world", ~timestamp="2024-01-15T10:00:00Z")
    buffer.add(~taskId="task-2", ~text="Other", ~timestamp="2024-01-15T11:00:00Z")

    // Before flush: nothing dispatched (pending in rAF)
    t->expect(flushed.contents->Array.length)->Expect.toBe(0)

    // Flush synchronously dispatches everything
    buffer.flush()
    t->expect(flushed.contents->Array.length)->Expect.toBe(2)

    // task-1 text was concatenated, first timestamp preserved
    let task1Entry = flushed.contents->Array.find(e => e.taskId === "task-1")
    t->expect(task1Entry->Option.map(e => e.text))->Expect.toBe(Some("Hello world"))
    t->expect(task1Entry->Option.map(e => e.timestamp))->Expect.toBe(Some("2024-01-15T10:00:00Z"))
    t->expect(task1Entry->Option.map(e => e.agentId))->Expect.toBe(Some("executor-id"))

    // task-2 is separate
    let task2Entry = flushed.contents->Array.find(e => e.taskId === "task-2")
    t->expect(task2Entry->Option.map(e => e.text))->Expect.toBe(Some("Other"))
  })

  test("flush after flush is a no-op", t => {
    let callCount = ref(0)
    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~text as _, ~timestamp as _, ~agentId as _) => {
        callCount := callCount.contents + 1
      },
    )
    buffer.selectAgent(~taskId="task-1", ~agentId="executor-id")
    buffer.add(~taskId="task-1", ~text="Hello", ~timestamp="2024-01-15T10:00:00Z")
    buffer.flush()
    t->expect(callCount.contents)->Expect.toBe(1)

    buffer.flush()
    t->expect(callCount.contents)->Expect.toBe(1)
  })

  test("reset discards pending entries without dispatching", t => {
    let callCount = ref(0)
    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~text as _, ~timestamp as _, ~agentId as _) => {
        callCount := callCount.contents + 1
      },
    )
    buffer.selectAgent(~taskId="task-1", ~agentId="executor-id")
    buffer.add(~taskId="task-1", ~text="Hello", ~timestamp="2024-01-15T10:00:00Z")
    buffer.reset()
    buffer.flush()
    t->expect(callCount.contents)->Expect.toBe(0)
  })

  test("flushes previous agent before switching a task", t => {
    let flushed: ref<array<flushEntry>> = ref([])
    let buffer = Buffer.make(
      ~onFlush=(~taskId, ~text, ~timestamp, ~agentId) => {
        flushed.contents = flushed.contents->Array.concat([{taskId, text, timestamp, agentId}])
      },
    )

    buffer.selectAgent(~taskId="task-1", ~agentId="executor-id")
    buffer.add(~taskId="task-1", ~text="Execute", ~timestamp="2024-01-15T10:00:00Z")
    buffer.selectAgent(~taskId="task-1", ~agentId="planner-id")
    buffer.add(~taskId="task-1", ~text="Plan", ~timestamp="2024-01-15T10:01:00Z")
    buffer.flush()

    t
    ->expect(flushed.contents->Array.map(entry => (entry.agentId, entry.text)))
    ->Expect.toEqual([("executor-id", "Execute"), ("planner-id", "Plan")])
  })

  test("fails when a delta arrives before selected agent", t => {
    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~text as _, ~timestamp as _, ~agentId as _) => (),
    )

    Expect.toThrow(
      t->expect(
        () => buffer.add(~taskId="task-1", ~text="Missing", ~timestamp="2024-01-15T10:00:00Z"),
      ),
    )
  })
})
