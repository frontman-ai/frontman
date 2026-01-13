// Integration tests for the ListFiles tool with .gitignore support

open Vitest

module ListFiles = FrontmanCore__Tool__ListFiles
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module Path = FrontmanBindings.Path
module ChildProcess = FrontmanBindings.ChildProcess
module Process = FrontmanBindings.Process

let fixtureDir = Path.join([Process.cwd(), "test", "fixtures", "listfiles"])

describe("ListFiles Tool - execute (integration)", _t => {
  // Initialize git repo before tests
  beforeAllAsync(async () => {
    let _ = await ChildProcess.execWithOptions("git init", {cwd: fixtureDir})
  })

  // Clean up .git after tests
  afterAllAsync(async () => {
    let _ = await ChildProcess.exec(`rm -rf ${Path.join([fixtureDir, ".git"])}`)
  })

  testAsync("should list files in directory", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await ListFiles.execute(ctx, {})

    switch result {
    | Ok(entries) => {
        t->expect(Array.length(entries) > 0)->Expect.toBe(true)

        // Should include regular files
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

    let result = await ListFiles.execute(ctx, {})

    switch result {
    | Ok(entries) => {
        // Should NOT include gitignored entries
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

    let result = await ListFiles.execute(ctx, {})

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

    let result = await ListFiles.execute(ctx, {path: "src"})

    switch result {
    | Ok(entries) => {
        t->expect(Array.length(entries) > 0)->Expect.toBe(true)

        let hasAppTs = entries->Array.some(e => e.name === "app.ts")
        t->expect(hasAppTs)->Expect.toBe(true)

        // Verify path includes subdirectory
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

    let result = await ListFiles.execute(ctx, {})

    switch result {
    | Ok(entries) => {
        // Check a file entry
        let fileEntry = entries->Array.find(e => e.name === "index.ts")
        switch fileEntry {
        | Some(entry) => {
            t->expect(entry.isFile)->Expect.toBe(true)
            t->expect(entry.isDirectory)->Expect.toBe(false)
          }
        | None => failwith("index.ts not found")
        }

        // Check a directory entry
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

  testAsync("should handle non-existent directory", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await ListFiles.execute(ctx, {path: "nonexistent"})

    switch result {
    | Ok(_) => failwith("Should have failed for non-existent directory")
    | Error(msg) => {
        t->expect(msg->String.includes("nonexistent"))->Expect.toBe(true)
      }
    }
  })

  testAsync("should prevent path traversal", async t => {
    let ctx: Tool.serverExecutionContext = {
      projectRoot: fixtureDir,
      sourceRoot: fixtureDir,
    }

    let result = await ListFiles.execute(ctx, {path: "../../../etc"})

    switch result {
    | Ok(_) => failwith("Should have failed for path traversal attempt")
    | Error(msg) => {
        t->expect(msg->String.length > 0)->Expect.toBe(true)
      }
    }
  })
})

describe("ListFiles Tool - getIgnoredEntries", _t => {
  // Initialize git repo before tests
  beforeAllAsync(async () => {
    let _ = await ChildProcess.execWithOptions("git init", {cwd: fixtureDir})
  })

  // Clean up .git after tests
  afterAllAsync(async () => {
    let _ = await ChildProcess.exec(`rm -rf ${Path.join([fixtureDir, ".git"])}`)
  })

  testAsync("should return ignored entries from gitignore", async t => {
    let entries = ["node_modules", "dist", "index.ts", "secrets.env"]
    let result = await ListFiles.getIgnoredEntries(~cwd=fixtureDir, entries)

    switch result {
    | Ok(ignored) => {
        t->expect(ignored->Array.includes("node_modules"))->Expect.toBe(true)
        t->expect(ignored->Array.includes("dist"))->Expect.toBe(true)
        t->expect(ignored->Array.includes("secrets.env"))->Expect.toBe(true)
        t->expect(ignored->Array.includes("index.ts"))->Expect.toBe(false)
      }
    | Error(msg) => failwith(`getIgnoredEntries failed: ${msg}`)
    }
  })

  testAsync("should return empty array when no files match", async t => {
    let entries = ["index.ts", "config.json", "readme.md"]
    let result = await ListFiles.getIgnoredEntries(~cwd=fixtureDir, entries)

    switch result {
    | Ok(ignored) => {
        t->expect(Array.length(ignored))->Expect.toBe(0)
      }
    | Error(msg) => failwith(`getIgnoredEntries failed: ${msg}`)
    }
  })

  testAsync("should handle empty entries array", async t => {
    let entries: array<string> = []
    let result = await ListFiles.getIgnoredEntries(~cwd=fixtureDir, entries)

    switch result {
    | Ok(ignored) => {
        t->expect(Array.length(ignored))->Expect.toBe(0)
      }
    | Error(msg) => failwith(`getIgnoredEntries failed: ${msg}`)
    }
  })
})
