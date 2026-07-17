// Tests for the ReadFile tool — focused-slice guardrails (line + byte caps).

open Vitest

module ReadFile = FrontmanCore__Tool__ReadFile
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Fs = FrontmanBindings.Fs
module Path = FrontmanBindings.Path
module ChildProcess = FrontmanCore__ChildProcess

let makeTmpDir = async () => {
  let dir = "/tmp/readfile-test-" ++ Float.toString(Date.now())
  let _ = await Fs.Promises.mkdir(dir, {recursive: true})
  dir
}

let cleanup = async (dir: string) => {
  let _ = await ChildProcess.exec(`rm -rf ${dir}`)
}

let makeCtx = (dir: string): Tool.serverExecutionContext => {
  projectRoot: dir,
  sourceRoot: dir,
}

describe("ReadFile Tool - focused-slice guardrails", _t => {
  // Regression: a single line larger than maxBytes must still be capped. The
  // window loop always keeps the first line so a read never comes back empty,
  // so the byte ceiling has to be enforced when building the content too.
  testAsync("a single line larger than maxBytes is truncated to the cap", async t => {
    let dir = await makeTmpDir()
    let hugeLine = String.repeat("a", ReadFile.maxBytes * 2)
    await Fs.Promises.writeFile(Path.join([dir, "huge.txt"]), hugeLine)

    switch await ReadFile.executeOutput(makeCtx(dir), {path: "huge.txt"}) {
    | Ok(output) => {
        t->expect(String.length(output.content) <= ReadFile.maxBytes)->Expect.toBe(true)
        t->expect(output.hasMore)->Expect.toBe(true)
      }
    | Error(msg) => t->expect("read failed: " ++ msg)->Expect.toBe("should have read the file")
    }

    await cleanup(dir)
  })

  // Many short lines that together exceed maxBytes stop at the byte budget, and
  // hasMore is set so the agent knows to page with offset.
  testAsync("many short lines are capped at maxBytes with hasMore=true", async t => {
    let dir = await makeTmpDir()
    let line = String.repeat("b", 200)
    let big = Array.make(~length=1000, line)->Array.join("\n")
    await Fs.Promises.writeFile(Path.join([dir, "many.txt"]), big)

    switch await ReadFile.executeOutput(makeCtx(dir), {path: "many.txt"}) {
    | Ok(output) => {
        t->expect(String.length(output.content) <= ReadFile.maxBytes)->Expect.toBe(true)
        t->expect(output.hasMore)->Expect.toBe(true)
      }
    | Error(msg) => t->expect("read failed: " ++ msg)->Expect.toBe("should have read the file")
    }

    await cleanup(dir)
  })

  // A small file is returned whole, unmodified, with hasMore=false.
  testAsync("a small file is returned whole with hasMore=false", async t => {
    let dir = await makeTmpDir()
    await Fs.Promises.writeFile(Path.join([dir, "small.txt"]), "line1\nline2\nline3")

    switch await ReadFile.executeOutput(makeCtx(dir), {path: "small.txt"}) {
    | Ok(output) => {
        t->expect(output.content)->Expect.toBe("line1\nline2\nline3")
        t->expect(output.hasMore)->Expect.toBe(false)
      }
    | Error(msg) => t->expect("read failed: " ++ msg)->Expect.toBe("should have read the file")
    }

    await cleanup(dir)
  })
})
