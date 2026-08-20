open Vitest

module FileChange = FrontmanAiFrontmanProtocol.FrontmanProtocol__FileChange
module Message = Client__Message
module Task = Client__Task__Types.Task
module TaskReducer = Client__Task__Reducer

let envelope = (
  ~path="src/app.tsx",
  ~status=FileChange.Modified,
  ~oldPath=None,
  ~oldText,
  ~currentText,
  ~unavailableReason=None,
): FileChange.envelope => {
  path,
  status,
  oldPath,
  oldText,
  currentText,
  unavailableReason,
}

let rawOutput = (change: FileChange.envelope): JSON.t => {
  let encoded =
    change->S.decodeOrThrow(~from=FileChange.envelopeSchema, ~to=S.json->S.noValidation(true))
  JSON.Encode.object(Dict.fromArray([(FileChange.reservedKey, encoded)]))
}

let legacyEditInput = (~path, ~oldText, ~newText): JSON.t =>
  JSON.Encode.object(
    Dict.fromArray([
      ("path", JSON.Encode.string(path)),
      ("oldText", JSON.Encode.string(oldText)),
      ("newText", JSON.Encode.string(newText)),
    ]),
  )

let legacyEditOutput = (~path, ~message): JSON.t => {
  let context = JSON.Encode.object(Dict.fromArray([("relativePath", JSON.Encode.string(path))]))
  JSON.Encode.object(
    Dict.fromArray([("message", JSON.Encode.string(message)), ("_context", context)]),
  )
}

let toolCall = (~id, change): Message.t => Message.ToolCall({
  id,
  toolName: "edit_file",
  state: Message.OutputAvailable,
  inputBuffer: "",
  input: None,
  result: Some({rawOutput: Some(rawOutput(change)), content: []}),
  errorText: None,
  parentAgentId: None,
  spawningToolName: None,
})

let legacyEditToolCall = (
  ~id,
  ~path,
  ~oldText,
  ~newText,
  ~serialized=false,
  ~message="Edit applied successfully.",
): Message.t => {
  let input = legacyEditInput(~path, ~oldText, ~newText)
  let input = switch serialized {
  | true => input->JSON.stringifyAny->Option.getOrThrow->JSON.Encode.string
  | false => input
  }
  Message.ToolCall({
    id,
    toolName: "edit_file",
    state: Message.OutputAvailable,
    inputBuffer: "",
    input: Some(input),
    result: Some({rawOutput: Some(legacyEditOutput(~path, ~message)), content: []}),
    errorText: None,
    parentAgentId: None,
    spawningToolName: None,
  })
}

describe("conversation file changes", () => {
  test("ignores tool outputs without a file-change envelope", t => {
    let emptyOutput = JSON.Encode.object(Dict.make())
    t->expect(Client__FileChanges.parseEnvelope(emptyOutput))->Expect.toEqual(None)
  })

  test("reads a file-change envelope from the reserved structuredContent key", t => {
    let change = envelope(~oldText=Some("old"), ~currentText=Some("new"))
    t->expect(Client__FileChanges.parseEnvelope(rawOutput(change)))->Expect.toEqual(Some(change))
  })

  test("ignores a legacy edit result whose message reports no write", t => {
    let snapshot = Client__FileChanges.aggregate(
      ~revision=1,
      [
        legacyEditToolCall(
          ~id="tool-1",
          ~path="src/app.tsx",
          ~oldText="before",
          ~newText="after",
          ~message="oldText not found in file src/app.tsx.",
        ),
      ],
    )

    t->expect(Array.length(snapshot.files))->Expect.toBe(0)
  })

  test("derives a change from a successful legacy edit result", t => {
    let snapshot = Client__FileChanges.aggregate(
      ~revision=1,
      [legacyEditToolCall(~id="tool-1", ~path="src/app.tsx", ~oldText="before", ~newText="after")],
    )

    switch snapshot.files {
    | [{path, status: FileChange.Modified, oldText, currentText}] => {
        t->expect(path)->Expect.toBe("src/app.tsx")
        t->expect(oldText)->Expect.toEqual(Some("before"))
        t->expect(currentText)->Expect.toEqual(Some("after"))
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("derives a change when the legacy edit input is serialized JSON", t => {
    let snapshot = Client__FileChanges.aggregate(
      ~revision=1,
      [
        legacyEditToolCall(
          ~id="tool-1",
          ~path="src/app.tsx",
          ~oldText="before",
          ~newText="after",
          ~serialized=true,
        ),
      ],
    )

    switch snapshot.files {
    | [{oldText: Some("before"), currentText: Some("after")}] => ()
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("aggregates repeated edits from first before text to latest after text", t => {
    let first = envelope(~oldText=Some("one\nold\n"), ~currentText=Some("one\nmiddle\n"))
    let second = envelope(~oldText=Some("one\nmiddle\n"), ~currentText=Some("one\nnew\n"))
    let snapshot = Client__FileChanges.aggregate(
      ~revision=4,
      [toolCall(~id="tool-1", first), toolCall(~id="tool-2", second)],
    )

    t->expect(snapshot.revision)->Expect.toBe(4)
    switch snapshot.files {
    | [{oldText, currentText, addedLines, removedLines}] => {
        t->expect(oldText)->Expect.toEqual(Some("one\nold\n"))
        t->expect(currentText)->Expect.toEqual(Some("one\nnew\n"))
        t->expect(addedLines)->Expect.toBe(1)
        t->expect(removedLines)->Expect.toBe(1)
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("ignores a repeated file-change envelope", t => {
    let change = envelope(~oldText=Some("before"), ~currentText=Some("after"))
    let files = Client__FileChanges.aggregate(
      ~revision=1,
      [toolCall(~id="tool-1", change), toolCall(~id="tool-2", change)],
    ).files

    switch files {
    | [{oldText: Some("before"), currentText: Some("after"), unavailableReason: None}] => ()
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("rejects a textless envelope without an unavailable reason", t => {
    let malformed = envelope(~oldText=None, ~currentText=None)

    Expect.toThrow(
      t->expect(
        () =>
          Client__FileChanges.aggregate(~revision=1, [toolCall(~id="tool-1", malformed)])->ignore,
      ),
    )
  })

  test("omits a file whose final content matches its baseline", t => {
    let first = envelope(~oldText=Some("before"), ~currentText=Some("after"))
    let second = envelope(~oldText=Some("after"), ~currentText=Some("before"))
    let snapshot = Client__FileChanges.aggregate(
      ~revision=1,
      [toolCall(~id="tool-1", first), toolCall(~id="tool-2", second)],
    )
    t->expect(Array.length(snapshot.files))->Expect.toBe(0)
  })

  test("derives added, deleted, and renamed statuses", t => {
    let added = envelope(
      ~path="a.txt",
      ~status=FileChange.Added,
      ~oldText=None,
      ~currentText=Some("a"),
    )
    let deleted = envelope(
      ~path="b.txt",
      ~status=FileChange.Deleted,
      ~oldText=Some("b"),
      ~currentText=None,
    )
    let renamed = envelope(
      ~path="d.txt",
      ~status=FileChange.Renamed,
      ~oldPath=Some("c.txt"),
      ~oldText=Some("c"),
      ~currentText=Some("c"),
    )
    let currentTurn = Message.User({
      id: "user",
      content: [],
      annotations: [],
      agentId: "executor-id",
    })
    let currentChange = envelope(~path="z.txt", ~oldText=None, ~currentText=Some("z"))
    let files = Client__FileChanges.aggregateCompleted(
      ~revision=1,
      ~isAgentRunning=true,
      [
        toolCall(~id="tool-a", added),
        toolCall(~id="tool-b", deleted),
        toolCall(~id="tool-c", renamed),
        currentTurn,
        toolCall(~id="tool-current", currentChange),
      ],
    ).files

    switch files {
    | [{status: FileChange.Added}, {status: FileChange.Deleted}, {status: FileChange.Renamed}] => ()
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("carries an earlier edit across a later rename", t => {
    let edit = envelope(~path="old.txt", ~oldText=Some("before"), ~currentText=Some("middle"))
    let rename = envelope(
      ~path="new.txt",
      ~status=FileChange.Renamed,
      ~oldPath=Some("old.txt"),
      ~oldText=Some("middle"),
      ~currentText=Some("after"),
    )
    let files = Client__FileChanges.aggregate(
      ~revision=1,
      [toolCall(~id="tool-1", edit), toolCall(~id="tool-2", rename)],
    ).files

    switch files {
    | [{path: "new.txt", oldPath: Some("old.txt"), oldText, currentText}] => {
        t->expect(oldText)->Expect.toEqual(Some("before"))
        t->expect(currentText)->Expect.toEqual(Some("after"))
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("keeps consecutive content-preserving renames", t => {
    let firstRename = envelope(
      ~path="middle.txt",
      ~status=FileChange.Renamed,
      ~oldPath=Some("original.txt"),
      ~oldText=Some("content"),
      ~currentText=Some("content"),
    )
    let secondRename = envelope(
      ~path="final.txt",
      ~status=FileChange.Renamed,
      ~oldPath=Some("middle.txt"),
      ~oldText=Some("content"),
      ~currentText=Some("content"),
    )
    let files = Client__FileChanges.aggregate(
      ~revision=1,
      [toolCall(~id="tool-1", firstRename), toolCall(~id="tool-2", secondRename)],
    ).files

    switch files {
    | [{path: "final.txt", oldPath: Some("original.txt"), status: FileChange.Renamed}] => ()
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("preserves binary and discontinuous unavailable reasons", t => {
    let binary = envelope(
      ~path="binary.dat",
      ~oldText=None,
      ~currentText=None,
      ~unavailableReason=Some(FileChange.Binary),
    )
    let laterText = envelope(~path="binary.dat", ~oldText=Some("old"), ~currentText=Some("new"))
    let beforeGap = envelope(~path="gap.txt", ~oldText=Some("one"), ~currentText=Some("two"))
    let afterGap = envelope(
      ~path="gap.txt",
      ~oldText=Some("external edit"),
      ~currentText=Some("three"),
    )
    let files = Client__FileChanges.aggregate(
      ~revision=1,
      [
        toolCall(~id="tool-1", binary),
        toolCall(~id="tool-2", laterText),
        toolCall(~id="tool-3", beforeGap),
        toolCall(~id="tool-4", afterGap),
      ],
    ).files

    switch files {
    | [
        {path: "binary.dat", unavailableReason: Some(Client__FileChanges.Binary)},
        {path: "gap.txt", unavailableReason: Some(Client__FileChanges.Discontinuous)},
      ] => ()
    | _ => t->expect(false)->Expect.toBe(true)
    }
    t
    ->expect(files->Array.every(file => file.oldText == None && file.currentText == None))
    ->Expect.toBe(true)
  })

  test("preserves the size-limited unavailable reason", t => {
    let sizeLimited = envelope(
      ~path="large.txt",
      ~oldText=None,
      ~currentText=None,
      ~unavailableReason=Some(FileChange.SizeLimited),
    )
    let files = Client__FileChanges.aggregate(
      ~revision=1,
      [toolCall(~id="tool-1", sizeLimited)],
    ).files

    switch files {
    | [{unavailableReason: Some(Client__FileChanges.SizeLimited)}] => ()
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("publishes a new snapshot only when the turn becomes idle", t => {
    let task =
      Task.makeNew(~previewUrl="http://localhost:3000")->Task.newToLoaded(
        ~id="task-1",
        ~title="Diff test",
      )
    let (running, _) = TaskReducer.next(task, ExecutionStateRunning)
    let change = envelope(~oldText=Some("old"), ~currentText=Some("new"))
    let call: Message.toolCall = {
      id: "tool-1",
      toolName: "edit_file",
      state: Message.InputAvailable,
      inputBuffer: "",
      input: None,
      result: None,
      errorText: None,
      parentAgentId: None,
      spawningToolName: None,
    }
    let (withCall, _) = TaskReducer.next(running, ToolCallReceived({toolCall: call}))
    let (withResult, _) = TaskReducer.next(
      withCall,
      ToolResultReceived({
        id: "tool-1",
        rawOutput: Some(rawOutput(change)),
        content: None,
        complete: true,
      }),
    )

    t->expect(Array.length(Task.getCompletedFileChanges(withResult).files))->Expect.toBe(0)
    let (idle, _) = TaskReducer.next(withResult, ExecutionStateIdle)
    t->expect(Array.length(Task.getCompletedFileChanges(idle).files))->Expect.toBe(1)
    t->expect(Task.getCompletedFileChanges(idle).revision)->Expect.toBe(1)
  })
})
