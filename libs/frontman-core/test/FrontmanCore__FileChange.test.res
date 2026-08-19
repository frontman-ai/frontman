open Vitest

module FileChange = FrontmanCore__FileChange
module ProtocolFileChange = FrontmanAiFrontmanProtocol.FrontmanProtocol__FileChange

describe("FileChange", _t => {
  test("keeps available text snapshots below the per-mutation limit", t => {
    let change = FileChange.make(
      ~path="src/app.tsx",
      ~status=ProtocolFileChange.Modified,
      ~oldText=Some("before"),
      ~currentText=Some("after"),
      ~binary=false,
    )

    t->expect(change.textAvailable)->Expect.toBe(true)
    t->expect(change.oldText)->Expect.toEqual(Some("before"))
    t->expect(change.currentText)->Expect.toEqual(Some("after"))
  })

  test("marks binary writes unavailable without retaining text", t => {
    let change = FileChange.make(
      ~path="public/logo.png",
      ~status=ProtocolFileChange.Added,
      ~oldText=None,
      ~currentText=Some("base64-content"),
      ~binary=true,
    )

    t->expect(change.textAvailable)->Expect.toBe(false)
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

    t->expect(change.textAvailable)->Expect.toBe(false)
    t->expect(change.unavailableReason)->Expect.toEqual(Some(ProtocolFileChange.SizeLimited))
  })
})
