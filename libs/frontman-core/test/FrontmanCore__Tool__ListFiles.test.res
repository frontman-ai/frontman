open Vitest

module ListFiles = FrontmanCore__Tool__ListFiles
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Path = FrontmanBindings.Path
module ChildProcess = FrontmanCore__ChildProcess
module Process = FrontmanBindings.Process
module Fs = FrontmanBindings.Fs
module Helpers = FrontmanCore__ToolTestHelpers

@module("node:fs/promises") external mkdtemp: string => promise<string> = "mkdtemp"
@module("node:fs/promises") external chmod: (string, int) => promise<unit> = "chmod"
@val @scope("process") external getuid: unit => int = "getuid"

let fixtureDir = Path.join([Process.cwd(), "test", "fixtures", "listfiles"])

let execute = (ctx, input) =>
  FrontmanCore__ToolTestHelpers.execute(ListFiles.execute, ctx, input, ListFiles.outputSchema)

describe("ListFiles Tool - execute (integration)", _t => {
  beforeAllAsync(async () => {
    let _ = await ChildProcess.execWithOptions("git init", {cwd: fixtureDir})
  })

  afterAllAsync(async () => {
    let _ = await ChildProcess.exec(`rm -rf ${Path.join([fixtureDir, ".git"])}`)
  })

  testAsync("should list files in directory", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await execute(ctx, {})

    switch result {
    | Ok(entries) => {
        t->expect(Array.length(entries) > 0)->Expect.toBe(true)

        let hasIndex = entries->Array.some(e => e.name === "index.ts")
        let hasConfig = entries->Array.some(e => e.name === "config.json")
        let hasReadme = entries->Array.some(e => e.name === "readme.md")

        t->expect(hasIndex)->Expect.toBe(true)
        t->expect(hasConfig)->Expect.toBe(true)
        t->expect(hasReadme)->Expect.toBe(true)
      }
    | Error(msg) => failwith(`ListFiles failed: ${msg}`)
    }
  })

  testAsync("should filter out gitignored files", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await execute(ctx, {})

    switch result {
    | Ok(entries) => {
        let hasNodeModules = entries->Array.some(e => e.name === "node_modules")
        let hasDist = entries->Array.some(e => e.name === "dist")
        let hasSecretsEnv = entries->Array.some(e => e.name === "secrets.env")
        let hasDebugLog = entries->Array.some(e => e.name === "debug.log")

        t->expect(hasNodeModules)->Expect.toBe(false)
        t->expect(hasDist)->Expect.toBe(false)
        t->expect(hasSecretsEnv)->Expect.toBe(false)
        t->expect(hasDebugLog)->Expect.toBe(false)
      }
    | Error(msg) => failwith(`ListFiles failed: ${msg}`)
    }
  })

  testAsync("should include .gitignore file itself", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await execute(ctx, {})

    switch result {
    | Ok(entries) => {
        let hasGitignore = entries->Array.some(e => e.name === ".gitignore")
        t->expect(hasGitignore)->Expect.toBe(true)
      }
    | Error(msg) => failwith(`ListFiles failed: ${msg}`)
    }
  })

  testAsync("should list files in subdirectory", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await execute(ctx, {path: "src"})

    switch result {
    | Ok(entries) => {
        t->expect(Array.length(entries) > 0)->Expect.toBe(true)

        let hasAppTs = entries->Array.some(e => e.name === "app.ts")
        t->expect(hasAppTs)->Expect.toBe(true)

        let appEntry = entries->Array.find(e => e.name === "app.ts")
        switch appEntry {
        | Some(entry) => t->expect(entry.path)->Expect.toBe("src/app.ts")
        | None => failwith("app.ts not found")
        }
      }
    | Error(msg) => failwith(`ListFiles failed: ${msg}`)
    }
  })

  testAsync("should return correct file/directory flags", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await execute(ctx, {})

    switch result {
    | Ok(entries) => {
        let fileEntry = entries->Array.find(e => e.name === "index.ts")
        switch fileEntry {
        | Some(entry) => {
            t->expect(entry.isFile)->Expect.toBe(true)
            t->expect(entry.isDirectory)->Expect.toBe(false)
          }
        | None => failwith("index.ts not found")
        }

        let dirEntry = entries->Array.find(e => e.name === "src")
        switch dirEntry {
        | Some(entry) => {
            t->expect(entry.isFile)->Expect.toBe(false)
            t->expect(entry.isDirectory)->Expect.toBe(true)
          }
        | None => failwith("src directory not found")
        }
      }
    | Error(msg) => failwith(`ListFiles failed: ${msg}`)
    }
  })

  testAsync("should handle file path as input (falls back to parent directory)", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await execute(ctx, {path: "index.ts"})

    switch result {
    | Ok(entries) => {
        t->expect(Array.length(entries) > 0)->Expect.toBe(true)

        let hasConfig = entries->Array.some(e => e.name === "config.json")
        t->expect(hasConfig)->Expect.toBe(true)
      }
    | Error(msg) => failwith(`ListFiles should not fail on file paths: ${msg}`)
    }
  })

  testAsync("should handle non-existent directory", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await execute(ctx, {path: "nonexistent"})

    switch result {
    | Ok(_) => failwith("Should have failed for non-existent directory")
    | Error(msg) =>
      t->expect(msg->String.includes("nonexistent"))->Expect.toBe(true)
      t->expect(msg->String.includes("sourceRoot: " ++ fixtureDir))->Expect.toBe(true)
      t
      ->expect(msg->String.includes("resolved: " ++ fixtureDir ++ "/nonexistent"))
      ->Expect.toBe(true)
    }
  })

  testAsync("reports fallback notices without hiding Git failures", async t => {
    let dir = await mkdtemp("/tmp/listfiles-test-")
    let ctx: Tool.serverExecutionContext = {projectRoot: dir, sourceRoot: dir}
    await Fs.Promises.writeFile(dir ++ "/file.ts", "")
    let path = Process.env->Dict.get("PATH")->Option.getOrThrow
    try {
      for mode in 0 to 1 {
        switch mode {
        | 1 => Process.env->Dict.set("PATH", dir)
        | _ => ()
        }
        let text = (await ListFiles.execute(ctx, {}))->Helpers.text->Result.getOrThrow
        t->expect(text->String.includes("[filesystem fallback]"))->Expect.toBe(true)
        t->expect(text->String.includes("file.ts"))->Expect.toBe(true)
      }
    } catch {
    | exn =>
      Process.env->Dict.set("PATH", path)
      (await ChildProcess.spawnResult("rm", ["-rf", dir]))->Result.getOrThrow->ignore
      raise(exn)
    }
    Process.env->Dict.set("PATH", path)
    await Fs.Promises.writeFile(dir ++ "/.git", "invalid git metadata\n")
    let result = (await ListFiles.execute(ctx, {}))->Helpers.text
    (await ChildProcess.spawnResult("rm", ["-rf", dir]))->Result.getOrThrow->ignore
    switch result {
    | Ok(_) => failwith("Expected invalid Git metadata error")
    | Error(msg) =>
      t->expect(msg->String.includes("invalid gitfile format"))->Expect.toBe(true)
      t->expect(msg->String.includes("sourceRoot: " ++ dir))->Expect.toBe(true)
    }
  })

  testAsync("keeps permission failures visible", async t => {
    switch getuid() == 0 {
    | true => ()
    | false =>
      let dir = await mkdtemp("/tmp/listfiles-test-")
      let ctx: Tool.serverExecutionContext = {projectRoot: dir, sourceRoot: dir}
      await chmod(dir, 0)
      let result = (await ListFiles.execute(ctx, {}))->Helpers.text
      await chmod(dir, 493)
      (await ChildProcess.spawnResult("rm", ["-rf", dir]))->Result.getOrThrow->ignore
      switch result {
      | Ok(_) => failwith("Expected permission error")
      | Error(msg) =>
        t->expect(msg->String.includes("EACCES"))->Expect.toBe(true)
        t->expect(msg->String.includes("sourceRoot: " ++ dir))->Expect.toBe(true)
      }
    }
  })

  testAsync("should prevent path traversal", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await execute(ctx, {path: "../../../etc"})

    switch result {
    | Ok(_) => failwith("Should have failed for path traversal attempt")
    | Error(msg) => t->expect(msg->String.length > 0)->Expect.toBe(true)
    }
  })
})

describe("ListFiles Tool - getIgnoredEntries", _t => {
  beforeAllAsync(async () => {
    let _ = await ChildProcess.execWithOptions("git init", {cwd: fixtureDir})
  })

  afterAllAsync(async () => {
    let _ = await ChildProcess.exec(`rm -rf ${Path.join([fixtureDir, ".git"])}`)
  })

  testAsync("should return ignored entries from gitignore", async t => {
    let unusual = "quote'$(touch INJECTED)\nfile.ts"
    let entries = ["node_modules", "dist", "index.ts", "secrets.env", unusual]
    let result = await ListFiles.getIgnoredEntries(~cwd=fixtureDir, entries)

    switch result {
    | Ok(ignored) => {
        t->expect(ignored->Array.includes("node_modules"))->Expect.toBe(true)
        t->expect(ignored->Array.includes("dist"))->Expect.toBe(true)
        t->expect(ignored->Array.includes("secrets.env"))->Expect.toBe(true)
        t->expect(ignored->Array.includes("index.ts"))->Expect.toBe(false)
        t->expect(ignored->Array.includes(unusual))->Expect.toBe(false)
        t
        ->expect((await Fs.Promises.readdir(fixtureDir))->Array.includes("INJECTED"))
        ->Expect.toBe(false)
      }
    | Error(msg) => failwith(`getIgnoredEntries failed: ${msg}`)
    }
  })

  testAsync("should return empty array when no files match", async t => {
    let entries = ["index.ts", "config.json", "readme.md"]
    let result = await ListFiles.getIgnoredEntries(~cwd=fixtureDir, entries)

    switch result {
    | Ok(ignored) => t->expect(Array.length(ignored))->Expect.toBe(0)
    | Error(msg) => failwith(`getIgnoredEntries failed: ${msg}`)
    }
  })

  testAsync("should handle empty entries array", async t => {
    let entries: array<string> = []
    let result = await ListFiles.getIgnoredEntries(~cwd=fixtureDir, entries)

    switch result {
    | Ok(ignored) => t->expect(Array.length(ignored))->Expect.toBe(0)
    | Error(msg) => failwith(`getIgnoredEntries failed: ${msg}`)
    }
  })
})
