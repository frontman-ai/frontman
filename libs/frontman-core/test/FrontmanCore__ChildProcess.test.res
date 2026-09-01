open Vitest

module ChildProcess = FrontmanCore__ChildProcess
module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module Os = FrontmanBindings.Os

@val external setTimeout: (unit => unit, int) => unit = "setTimeout"

let wait = milliseconds => Promise.make((resolve, _reject) => setTimeout(resolve, milliseconds))

let exists = async path => {
  try {
    await Fs.Promises.access(path)
    true
  } catch {
  | _ => false
  }
}

describe("ChildProcess - spawnResult", _t => {
  testAsync("should return Ok for a successful command", async t => {
    let result = await ChildProcess.spawnResult("echo", ["hello"])

    switch result {
    | Ok({stdout}) => t->expect(stdout->String.trim)->Expect.toBe("hello")
    | Error({message}) => failwith(`Expected Ok, got Error: ${message}`)
    }
  })

  testAsync("should return Error for a failing command", async t => {
    let result = await ChildProcess.spawnResult("ls", ["--nonexistent-flag-xyz"])

    switch result {
    | Ok(_) => failwith("Expected Error for invalid flag")
    | Error({code}) => t->expect(code->Option.isSome)->Expect.toBe(true)
    }
  })

  testAsync("should return Error (not throw) when cwd is a file path (ENOTDIR)", async t => {
    let tempDir = Path.join([Os.tmpdir(), `cp-test-${Date.now()->Float.toString}`])
    let _ = await Fs.Promises.mkdir(tempDir, {recursive: true})
    let filePath = Path.join([tempDir, "not-a-directory.txt"])
    await Fs.Promises.writeFile(filePath, "content")

    let result = await ChildProcess.spawnResult("echo", ["hello"], ~cwd=filePath)

    switch result {
    | Ok(_) => failwith("Expected Error when cwd is a file, got Ok")
    | Error({message}) => t->expect(message->String.length > 0)->Expect.toBe(true)
    }

    let _ = await ChildProcess.exec(`rm -rf ${tempDir}`)
  })

  testAsync("should return Error (not throw) when cwd does not exist (ENOENT)", async t => {
    let nonexistentDir = Path.join([Os.tmpdir(), "nonexistent-dir-abc123xyz"])

    let result = await ChildProcess.spawnResult("echo", ["hello"], ~cwd=nonexistentDir)

    switch result {
    | Ok(_) => failwith("Expected Error when cwd does not exist, got Ok")
    | Error({message}) => t->expect(message->String.length > 0)->Expect.toBe(true)
    }
  })

  testAsync("kills a running process when its execution signal aborts", async t => {
    let controller = WebAPI.AbortController.make()
    let marker = Path.join([Os.tmpdir(), `frontman-abort-${Date.now()->Float.toString}`])
    let running = ChildProcess.spawnResult(
      "node",
      [
        "-e",
        `setTimeout(() => require("node:fs").writeFileSync(${marker
          ->JSON.Encode.string
          ->JSON.stringify}, "late"), 200)`,
      ],
      ~signal=controller.signal,
    )

    WebAPI.AbortController.abort(controller)

    switch await running {
    | Ok(_) => failwith("Expected an aborted process error")
    | Error({message}) => t->expect(message)->Expect.toBe("Process aborted")
    }
    await wait(300)
    t->expect(await exists(marker))->Expect.toBe(false)
  })
})

describe("ChildProcess - exec", _t => {
  testAsync("should execute a simple command", async t => {
    let result = await ChildProcess.exec("echo hello")

    switch result {
    | Ok({stdout}) => t->expect(stdout->String.trim)->Expect.toBe("hello")
    | Error({message}) => failwith(`Expected Ok, got Error: ${message}`)
    }
  })
})
