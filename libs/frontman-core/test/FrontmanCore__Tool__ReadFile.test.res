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

describe("ReadFile Tool", _t => {
  testAsync("caps requested reads at 1000 lines", async t => {
    let dir = await makeTmpDir()
    let content = Array.make(~length=1500, "line")->Array.join("\n")
    await Fs.Promises.writeFile(Path.join([dir, "large.txt"]), content)

    switch await ReadFile.executeOutput(makeCtx(dir), {path: "large.txt", limit: ?Some(1500)}) {
    | Ok(output) => {
        t->expect(output.content->String.split("\n")->Array.length)->Expect.toBe(1000)
        t->expect(output.hasMore)->Expect.toBe(true)
      }
    | Error(msg) => t->expect("read failed: " ++ msg)->Expect.toBe("should have read the file")
    }

    await cleanup(dir)
  })
})
