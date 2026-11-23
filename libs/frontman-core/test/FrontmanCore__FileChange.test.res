open Vitest

module FileChange = FrontmanCore__FileChange
module EditFile = FrontmanCore__Tool__EditFile
module ProtocolFileChange = FrontmanAiFrontmanProtocol.FrontmanProtocol__FileChange
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module WriteFile = FrontmanCore__Tool__WriteFile
module Fs = FrontmanBindings.Fs.Promises

module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP
@schema
type resultFlags = {isError?: bool, changed?: bool}
let flags = result =>
  result
  ->S.decodeOrThrow(~from=MCP.callToolResultSchema, ~to=S.json->S.noValidation(true))
  ->S.parseOrThrow(~to=resultFlagsSchema)

@module("node:fs/promises") external mkdtemp: string => promise<string> = "mkdtemp"
@module("node:fs/promises")
external readBase64: (string, @as("base64") _) => promise<string> = "readFile"
type rmOptions = {recursive: bool}
@module("node:fs/promises") external rm: (string, rmOptions) => promise<unit> = "rm"

let withProject = async run => {
  let dir = await mkdtemp(FrontmanBindings.Path.join([FrontmanBindings.Os.tmpdir(), "changed-"]))
  let ctx: Tool.serverExecutionContext = {projectRoot: dir, sourceRoot: dir}
  try {
    await run(ctx)
  } catch {
  | exn =>
    await rm(dir, {recursive: true})
    throw(exn)
  }
  await rm(dir, {recursive: true})
}

describe("filesystem tool result.changed", _t => {
  let testWrites = (~name, ~encoding, ~first, ~second, ~read) =>
    testAsync(name, async t => {
      await withProject(
        async ctx => {
          let path = "file"
          let write = async (content, expected) => {
            let result = (await WriteFile.execute(ctx, {path, content, ?encoding}))->flags
            t->expect(result.isError->Option.getOr(false))->Expect.toBe(false)
            t->expect(result.changed)->Expect.toEqual(expected)
            t->expect(await read(ctx.sourceRoot ++ "/" ++ path))->Expect.toBe(content)
          }
          await write(first, Some(true))
          (await FrontmanCore__Tool__ReadFile.executeOutput(ctx, {path: path}))
          ->Result.getOrThrow
          ->ignore
          await write(second, Some(true))
          await write(second, None)
        },
      )
    })

  testWrites(
    ~name="text creation, modification and identical rewrite",
    ~encoding=None,
    ~first="one",
    ~second="two",
    ~read=path => Fs.readFile(path),
  )
  // FF and FE decode to the same UTF-8 replacement character but are different bytes.
  testWrites(
    ~name="binary creation, modification and identical rewrite",
    ~encoding=Some(#base64),
    ~first="/w==",
    ~second="/g==",
    ~read=path => readBase64(path),
  )

  testAsync("edits report changes only when the replacement changes the file", async t => {
    await withProject(
      async ctx => {
        let path = "edit.txt"
        let seed = (await WriteFile.execute(ctx, {path, content: "before"}))->flags
        t->expect(seed.isError->Option.getOr(false))->Expect.toBe(false)
        (await FrontmanCore__Tool__ReadFile.executeOutput(ctx, {path: path}))
        ->Result.getOrThrow
        ->ignore
        let edit = async (oldText, newText) =>
          (await EditFile.execute(ctx, {path, oldText, newText}))->flags
        let modified = await edit("before", "after")
        t->expect(modified.isError->Option.getOr(false))->Expect.toBe(false)
        t->expect(modified.changed)->Expect.toEqual(Some(true))
        t->expect(await Fs.readFile(ctx.sourceRoot ++ "/" ++ path))->Expect.toBe("after")

        // Fuzzy matching finds "after", so replacing it with "after" succeeds unchanged.
        let identical = await edit(" after ", "after")
        t->expect(identical.isError->Option.getOr(false))->Expect.toBe(false)
        t->expect(identical.changed)->Expect.toEqual(None)

        let failedEdit = await edit("missing", "other")
        t->expect(failedEdit.isError)->Expect.toEqual(Some(true))
        t->expect(failedEdit.changed)->Expect.toEqual(None)
        let failedWrite =
          (await WriteFile.execute(ctx, {path: path ++ "/child", content: "other"}))->flags
        t->expect(failedWrite.isError)->Expect.toEqual(Some(true))
        t->expect(failedWrite.changed)->Expect.toEqual(None)
        t->expect(await Fs.readFile(ctx.sourceRoot ++ "/" ++ path))->Expect.toBe("after")
      },
    )
  })
})

describe("FileChange", _t => {
  testAsync("edit_file delegates file creation to write_file", async t => {
    let ctx = {
      FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.projectRoot: "/tmp",
      sourceRoot: "/tmp",
    }
    switch await EditFile.executeOutput(ctx, {path: "new.txt", oldText: "", newText: "content"}) {
    | Error(message) => t->expect(message->String.includes("write_file"))->Expect.toBe(true)
    | Ok(_) => t->expect("an error")->Expect.toBe("a created file")
    }
  })

  test("marks binary writes unavailable without retaining text", t => {
    let change = FileChange.make(
      ~path="public/logo.png",
      ~status=ProtocolFileChange.Added,
      ~oldText=None,
      ~currentText=Some("base64-content"),
      ~binary=true,
    )

    t->expect(change.oldText)->Expect.toEqual(None)
    t->expect(change.currentText)->Expect.toEqual(None)
    t->expect(change.unavailableReason)->Expect.toEqual(Some(ProtocolFileChange.Binary))
  })

  test("marks oversized snapshots unavailable", t => {
    let large = "x"->String.repeat(FileChange.maxSnapshotBytes)
    let change = FileChange.make(
      ~path="src/large.ts",
      ~status=ProtocolFileChange.Modified,
      ~oldText=Some(large),
      ~currentText=Some(large),
      ~binary=false,
    )

    t->expect(change.oldText)->Expect.toEqual(None)
    t->expect(change.currentText)->Expect.toEqual(None)
    t->expect(change.unavailableReason)->Expect.toEqual(Some(ProtocolFileChange.SizeLimited))
  })
})
