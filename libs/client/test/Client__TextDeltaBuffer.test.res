open Vitest

module Buffer = Client__TextDeltaBuffer
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

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

let addUserBlock = (
  buffer: Buffer.t,
  ~block,
  ~taskId="task-1",
  ~messageId="message-1",
  ~agentId="executor-id",
) => buffer.addUserBlock(~taskId, ~messageId, ~block, ~agentId)

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
    let buffer = makeBuffer(
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks, ~agentId as _) =>
        parsed := Some(Client__FrontmanProvider.parseUserMessageBlocks(blocks)),
    )

    addUserBlock(buffer, ~messageId="user-1", ~block=annotation)
    addUserBlock(buffer, ~messageId="user-1", ~block=screenshot)
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
    let buffer = makeBuffer(
      ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks, ~agentId as _) =>
        parsed := Some(Client__FrontmanProvider.parseUserMessageBlocks(blocks)),
    )

    addUserBlock(buffer, ~messageId="user-1", ~block=text)
    addUserBlock(buffer, ~messageId="user-1", ~block=image)
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
    let buffer = makeBuffer(
      ~onFlush=(~taskId, ~messageId, ~text, ~agentId) => {
        flushed.contents = flushed.contents->Array.concat([{taskId, messageId, text, agentId}])
      },
    )
    addAssistant(buffer, ~text="Hello ")
    addAssistant(buffer, ~text="world")
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
    t->expect(flushed.contents->Array.length)->Expect.toBe(2)

    // task-1 text was concatenated
    let task1Entry = flushed.contents->Array.find(e => e.taskId === "task-1")
    t->expect(task1Entry->Option.map(e => e.text))->Expect.toBe(Some("Hello world"))
    t->expect(task1Entry->Option.map(e => e.agentId))->Expect.toBe(Some("executor-id"))

    // task-2 is separate
    let task2Entry = flushed.contents->Array.find(e => e.taskId === "task-2")
    t->expect(task2Entry->Option.map(e => e.text))->Expect.toBe(Some("Other"))
  })

  test("flush after flush is a no-op", t => {
    let callCount = ref(0)
    let buffer = makeBuffer(
      ~onFlush=(~taskId as _, ~messageId as _, ~text as _, ~agentId as _) => {
        callCount := callCount.contents + 1
      },
    )
    addAssistant(buffer, ~text="Hello")
    buffer.flush()
    t->expect(callCount.contents)->Expect.toBe(1)

    buffer.flush()
    t->expect(callCount.contents)->Expect.toBe(1)
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

  test("flushes interleaved message IDs independently", t => {
    let flushed: ref<array<flushEntry>> = ref([])
    let buffer = makeBuffer(
      ~onFlush=(~taskId, ~messageId, ~text, ~agentId) => {
        flushed.contents = flushed.contents->Array.concat([{taskId, messageId, text, agentId}])
      },
    )

    addAssistant(buffer, ~messageId="message-1", ~text="Execute")
    addAssistant(buffer, ~messageId="message-2", ~text="Plan")
    buffer.flush()

    t
    ->expect(flushed.contents->Array.map(entry => (entry.messageId, entry.text)))
    ->Expect.toEqual([("message-1", "Execute"), ("message-2", "Plan")])
  })
})
