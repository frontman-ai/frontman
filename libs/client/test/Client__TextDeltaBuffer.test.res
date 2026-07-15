open Vitest

module Buffer = Client__TextDeltaBuffer
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

type flushEntry = {
  taskId: string,
  messageId: string,
  text: string,
  timestamp: string,
  agentId: string,
}

describe("TextDeltaBuffer", () => {
  test("discardTask removes only failed task buffers and identities", t => {
    let flushed = ref([])
    let buffer = Buffer.make(
      ~onFlush=(~taskId, ~messageId as _, ~text as _, ~timestamp as _, ~agentId as _) =>
        flushed := flushed.contents->Array.concat([taskId]),
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~timestamp as _, ~agentId as _) =>
        (),
    )
    buffer.add(
      ~taskId="failed-task",
      ~messageId="failed-message",
      ~text="discard",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.add(
      ~taskId="healthy-task",
      ~messageId="healthy-message",
      ~text="keep",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )

    buffer.discardTask("failed-task")
    buffer.flush()
    buffer.add(
      ~taskId="replacement-task",
      ~messageId="failed-message",
      ~text="identity released",
      ~timestamp="2024-01-15T10:00:01Z",
      ~agentId="planner-id",
    )
    buffer.flush()

    t->expect(flushed.contents)->Expect.toEqual(["healthy-task", "replacement-task"])
  })

  test("assembles annotation and screenshot blocks before parsing", t => {
    let parsed = ref(None)
    let annotationMeta = JSON.parseOrThrow(`{
      "annotation":true,"annotation_index":0,"annotation_id":"annotation-1",
      "tag_name":"button","selector":"#submit"
    }`)
    let screenshotMeta = JSON.parseOrThrow(`{
      "annotation_screenshot":true,"annotation_index":0,"annotation_id":"annotation-1"
    }`)
    let annotation = ACP.EmbeddedResource({
      resource: {
        _meta: Some(annotationMeta),
        annotations: None,
        resource: TextResourceContents({
          uri: "annotation://annotation-1",
          mimeType: None,
          text: "",
        }),
      },
      _meta: None,
      annotations: None,
    })
    let screenshot = ACP.EmbeddedResource({
      resource: {
        _meta: Some(screenshotMeta),
        annotations: None,
        resource: BlobResourceContents({
          uri: "annotation://annotation-1/screenshot",
          mimeType: Some("image/png"),
          blob: "c2NyZWVuc2hvdA==",
        }),
      },
      _meta: None,
      annotations: None,
    })
    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~timestamp as _, ~agentId as _) => (),
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks, ~timestamp as _, ~agentId as _) =>
        parsed := Some(Client__FrontmanProvider.parseUserMessageBlocks(blocks)),
    )

    buffer.addUserBlock(
      ~taskId="task-1",
      ~messageId="user-1",
      ~block=annotation,
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.addUserBlock(
      ~taskId="task-1",
      ~messageId="user-1",
      ~block=screenshot,
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.flush()

    switch parsed.contents {
    | Some((_, [annotation])) =>
      t
      ->expect(annotation.screenshot)
      ->Expect.toEqual(Ok(Some("data:image/png;base64,c2NyZWVuc2hvdA==")))
    | _ => t->expect("one annotation")->Expect.toBe("missing")
    }
  })

  test("assembles text and image blocks into one user message", t => {
    let parsed = ref(None)
    let imageMeta = JSON.parseOrThrow(`{"user_image":true,"filename":"photo.png"}`)
    let text = ACP.TextContent({text: "Look", _meta: None, annotations: None})
    let image = ACP.EmbeddedResource({
      resource: {
        _meta: Some(imageMeta),
        annotations: None,
        resource: BlobResourceContents({
          uri: "attachment://photo.png",
          mimeType: Some("image/png"),
          blob: "aW1hZ2U=",
        }),
      },
      _meta: None,
      annotations: None,
    })
    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~timestamp as _, ~agentId as _) => (),
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks, ~timestamp as _, ~agentId as _) =>
        parsed := Some(Client__FrontmanProvider.parseUserMessageBlocks(blocks)),
    )

    buffer.addUserBlock(
      ~taskId="task-1",
      ~messageId="user-1",
      ~block=text,
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.addUserBlock(
      ~taskId="task-1",
      ~messageId="user-1",
      ~block=image,
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.flush()

    switch parsed.contents {
    | Some((
        [
          Client__Message.UserContentPart.Text({text}),
          Client__Message.UserContentPart.Image({name}),
        ],
        [],
      )) => {
        t->expect(text)->Expect.toBe("Look")
        t->expect(name)->Expect.toEqual(Some("photo.png"))
      }
    | _ => t->expect("text and image")->Expect.toBe("missing")
    }
  })

  test("flush synchronously dispatches all pending entries", t => {
    let flushed: ref<array<flushEntry>> = ref([])
    let buffer = Buffer.make(
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~timestamp as _, ~agentId as _) =>
        (),
      ~onFlush=(~taskId, ~messageId, ~text, ~timestamp, ~agentId) => {
        flushed.contents =
          flushed.contents->Array.concat([{taskId, messageId, text, timestamp, agentId}])
      },
    )
    buffer.add(
      ~taskId="task-1",
      ~messageId="message-1",
      ~text="Hello ",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.add(
      ~taskId="task-1",
      ~messageId="message-1",
      ~text="world",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.add(
      ~taskId="task-2",
      ~messageId="message-2",
      ~text="Other",
      ~timestamp="2024-01-15T11:00:00Z",
      ~agentId="planner-id",
    )

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
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~timestamp as _, ~agentId as _) =>
        (),
      ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~timestamp as _, ~agentId as _) => {
        callCount := callCount.contents + 1
      },
    )
    buffer.add(
      ~taskId="task-1",
      ~messageId="message-1",
      ~text="Hello",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.flush()
    t->expect(callCount.contents)->Expect.toBe(1)

    buffer.flush()
    t->expect(callCount.contents)->Expect.toBe(1)
  })

  test("reset discards pending entries and clears identities", t => {
    let callCount = ref(0)
    let buffer = Buffer.make(
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~timestamp as _, ~agentId as _) =>
        (),
      ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~timestamp as _, ~agentId as _) => {
        callCount := callCount.contents + 1
      },
    )
    buffer.add(
      ~taskId="task-1",
      ~messageId="message-1",
      ~text="Hello",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.reset()
    t->expect(callCount.contents)->Expect.toBe(0)

    buffer.add(
      ~taskId="task-2",
      ~messageId="message-1",
      ~text="Reused after reset",
      ~timestamp="2024-01-15T10:01:00Z",
      ~agentId="planner-id",
    )
    buffer.flush()
    t->expect(callCount.contents)->Expect.toBe(1)
  })

  test("flushes interleaved message IDs independently", t => {
    let flushed: ref<array<flushEntry>> = ref([])
    let buffer = Buffer.make(
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~timestamp as _, ~agentId as _) =>
        (),
      ~onFlush=(~taskId, ~messageId, ~text, ~timestamp, ~agentId) => {
        flushed.contents =
          flushed.contents->Array.concat([{taskId, messageId, text, timestamp, agentId}])
      },
    )

    buffer.add(
      ~taskId="task-1",
      ~messageId="message-1",
      ~text="Execute",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.add(
      ~taskId="task-1",
      ~messageId="message-2",
      ~text="Plan",
      ~timestamp="2024-01-15T10:01:00Z",
      ~agentId="executor-id",
    )
    buffer.flush()

    t
    ->expect(flushed.contents->Array.map(entry => (entry.messageId, entry.text)))
    ->Expect.toEqual([("message-1", "Execute"), ("message-2", "Plan")])
  })

  test("fails when one message changes agents", t => {
    let buffer = Buffer.make(
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~timestamp as _, ~agentId as _) =>
        (),
      ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~timestamp as _, ~agentId as _) => (),
    )
    buffer.add(
      ~taskId="task-1",
      ~messageId="message-1",
      ~text="Execute",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.flush()

    Expect.toThrow(
      t->expect(
        () =>
          buffer.add(
            ~taskId="task-1",
            ~messageId="message-1",
            ~text="Plan",
            ~timestamp="2024-01-15T10:01:00Z",
            ~agentId="planner-id",
          ),
      ),
    )
  })

  test("fails when one message changes timestamps after flush", t => {
    let buffer = Buffer.make(
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~timestamp as _, ~agentId as _) =>
        (),
      ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~timestamp as _, ~agentId as _) => (),
    )
    buffer.add(
      ~taskId="task-1",
      ~messageId="message-1",
      ~text="One",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.flush()

    Expect.toThrow(
      t->expect(
        () =>
          buffer.add(
            ~taskId="task-1",
            ~messageId="message-1",
            ~text="Two",
            ~timestamp="2024-01-15T10:00:01Z",
            ~agentId="executor-id",
          ),
      ),
    )
  })

  test("user message metadata and role remain immutable", t => {
    let block = ACP.TextContent({text: "Hello", _meta: None, annotations: None})
    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~timestamp as _, ~agentId as _) => (),
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~timestamp as _, ~agentId as _) =>
        (),
    )
    buffer.addUserBlock(
      ~taskId="task-1",
      ~messageId="message-1",
      ~block,
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    buffer.flush()

    Expect.toThrow(
      t->expect(
        () =>
          buffer.addUserBlock(
            ~taskId="task-1",
            ~messageId="message-1",
            ~block,
            ~timestamp="2024-01-15T10:00:01Z",
            ~agentId="executor-id",
          ),
      ),
    )
    Expect.toThrow(
      t->expect(
        () =>
          buffer.add(
            ~taskId="task-1",
            ~messageId="message-1",
            ~text="Assistant",
            ~timestamp="2024-01-15T10:00:00Z",
            ~agentId="executor-id",
          ),
      ),
    )
    Expect.toThrow(
      t->expect(
        () =>
          buffer.addUserBlock(
            ~taskId="task-2",
            ~messageId="message-1",
            ~block,
            ~timestamp="2024-01-15T10:00:00Z",
            ~agentId="executor-id",
          ),
      ),
    )
  })

  test("fails when one message crosses tasks", t => {
    let flushed: ref<array<flushEntry>> = ref([])
    let buffer = Buffer.make(
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~timestamp as _, ~agentId as _) =>
        (),
      ~onFlush=(~taskId, ~messageId, ~text, ~timestamp, ~agentId) =>
        flushed := flushed.contents->Array.concat([{taskId, messageId, text, timestamp, agentId}]),
    )
    buffer.add(
      ~taskId="task-1",
      ~messageId="message-1",
      ~text="Execute",
      ~timestamp="2024-01-15T10:00:00Z",
      ~agentId="executor-id",
    )
    Expect.toThrow(
      t->expect(
        () =>
          buffer.add(
            ~taskId="task-2",
            ~messageId="message-1",
            ~text="Plan",
            ~timestamp="2024-01-15T10:00:00Z",
            ~agentId="planner-id",
          ),
      ),
    )
  })
})
