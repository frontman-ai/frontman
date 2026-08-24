open Vitest

module FileChange = FrontmanCore__FileChange
module EditFile = FrontmanCore__Tool__EditFile
module ProtocolFileChange = FrontmanAiFrontmanProtocol.FrontmanProtocol__FileChange

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
