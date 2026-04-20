// Regression coverage for tool-call path recovery guardrails (issue #887).

open Vitest

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module ListTree = FrontmanCore__Tool__ListTree
module SearchFiles = FrontmanCore__Tool__SearchFiles
module ReadFile = FrontmanCore__Tool__ReadFile
module ToolPathHints = FrontmanCore__ToolPathHints
module PathRecovery = FrontmanCore__PathRecovery
module Fs = FrontmanBindings.Fs
module Path = FrontmanBindings.Path
module ChildProcess = FrontmanCore__ChildProcess

let tmpPrefix = "/tmp/path-guardrails-test-"

let makeTmpDir = async () => {
  let dir = tmpPrefix ++ Float.toString(Date.now())
  let _ = await Fs.Promises.mkdir(dir, {recursive: true})
  dir
}

let writeFile = async (dir: string, relativePath: string, content: string) => {
  let fullPath = Path.join([dir, relativePath])
  let parentDir = Path.dirname(fullPath)
  let _ = await Fs.Promises.mkdir(parentDir, {recursive: true})
  await Fs.Promises.writeFile(fullPath, content)
}

let initGitRepo = async (dir: string) => {
  let _ = await ChildProcess.execWithOptions("git init", {cwd: dir})
  let _ = await ChildProcess.execWithOptions("git add -A", {cwd: dir})
}

let cleanup = async (dir: string) => {
  let _ = await ChildProcess.exec(`rm -rf ${dir}`)
}

let makeCtx = (dir: string): Tool.serverExecutionContext => {
  projectRoot: dir,
  sourceRoot: dir,
}

let makeFixture = async () => {
  let dir = await makeTmpDir()

  await writeFile(
    dir,
    "apps/marketing/src/content/docs/docs/getting-started/installation.md",
    "# Installation\nStep 1",
  )

  await writeFile(dir, "apps/marketing/src/content/docs/docs/reference/api.md", "# API Reference")

  await writeFile(dir, "libs/frontman-nextjs/src/index.ts", "export const nextjs = true")
  await writeFile(dir, "libs/frontman-vite/src/index.ts", "export const vite = true")
  await initGitRepo(dir)
  dir
}

describe("Tool path guardrails", _t => {
  testAsync("T1 invalid list_tree path recovers via nearest existing parent", async t => {
    ToolPathHints.clear()
    let dir = await makeFixture()

    let result = await ListTree.execute(
      makeCtx(dir),
      {path: ?Some("apps/marketing/src/pages/docs")},
    )

    switch result {
    | Ok(output) => {
        t->expect(output.tree->String.includes("[recovered]"))->Expect.toBe(true)
        t->expect(output.tree->String.includes("content/"))->Expect.toBe(true)
      }
    | Error(msg) => failwith(`Expected recovery output, got error: ${msg}`)
    }

    await cleanup(dir)
  })

  test("T2 search_files backend errors include structured diagnostics", t => {
    let err: SearchFiles.backendError = {
      backend: "git",
      command: "git ls-files",
      cwd: "/tmp/missing",
      exitCode: Some(128),
      stderr: "fatal: not a git repository",
      message: "Process exited with code 128",
      targetPath: "/tmp/missing",
    }

    let rendered = SearchFiles.formatBackendError(err)

    t->expect(rendered->String.includes("command:"))->Expect.toBe(true)
    t->expect(rendered->String.includes("cwd:"))->Expect.toBe(true)
    t->expect(rendered->String.includes("exit_code:"))->Expect.toBe(true)
    t->expect(rendered->String.includes("stderr:"))->Expect.toBe(true)
    t->expect(rendered->String.includes("target_path:"))->Expect.toBe(true)
  })

  testAsync("T3 wrong subfolder guess returns recovery guidance instead of ENOENT", async t => {
    ToolPathHints.clear()
    let dir = await makeFixture()

    let result = await ReadFile.execute(
      makeCtx(dir),
      {path: "apps/marketing/src/content/docs/docs/reference/installation.md"},
    )

    switch result {
    | Ok(_) => failwith("Expected read_file to fail with recovery guidance")
    | Error(msg) => {
        t->expect(msg->String.includes("Nearest existing parent"))->Expect.toBe(true)
        t->expect(msg->String.includes("Candidate files"))->Expect.toBe(true)
        t->expect(msg->String.includes("installation.md"))->Expect.toBe(true)
        t->expect(msg->String.includes("ENOENT"))->Expect.toBe(false)
      }
    }

    await cleanup(dir)
  })

  testAsync("T4 zero-result guardrail blocks immediate guessed read_file", async t => {
    ToolPathHints.clear()
    let dir = await makeFixture()
    let ctx = makeCtx(dir)

    let searchResult = await SearchFiles.execute(
      ctx,
      {
        pattern: "index.d.ts",
        path: ?Some("libs/frontman-nextjs"),
      },
    )

    switch searchResult {
    | Ok(output) => t->expect(output.totalResults)->Expect.toBe(0)
    | Error(msg) => failwith(`Expected zero-result search, got error: ${msg}`)
    }

    let readResult = await ReadFile.execute(ctx, {path: "libs/frontman-nextjs/index.d.ts"})

    switch readResult {
    | Ok(_) => failwith("Expected read_file to be blocked by guardrail")
    | Error(msg) => {
        t->expect(msg->String.includes("Zero-result guardrail"))->Expect.toBe(true)
        t->expect(msg->String.includes("ENOENT"))->Expect.toBe(false)
      }
    }

    await cleanup(dir)
  })

  test("T5 recordSearch normalizes non-absolute files under search path", t => {
    ToolPathHints.clear()

    let sourceRoot = "/tmp/root-test"
    let expectedFile = "libs/frontman-nextjs/src/index.ts"

    ToolPathHints.recordSearch(
      ~sourceRoot,
      ~searchPath=Path.join([sourceRoot, "libs", "frontman-nextjs"]),
      ~pattern="index.ts",
      ~files=["src/index.ts"],
      ~totalResults=1,
    )

    let anchors = ToolPathHints.getAnchors(~sourceRoot)
    t->expect(anchors->Array.includes("."))->Expect.toBe(false)
    t->expect(anchors->Array.includes(expectedFile->Path.dirname))->Expect.toBe(true)
  })

  testAsync("T6 read_file-style recovery stays in source root", async t => {
    ToolPathHints.clear()
    let dir = await makeFixture()

    let outsideCandidate = await PathRecovery.recoverMissingPath(
      ~sourceRoot=dir,
      ~resolvedPath=dir,
      ~entryLimit=4,
    )

    switch outsideCandidate {
    | None => failwith("Expected recovery result")
    | Some(recovery) => {
        t->expect(recovery.nearestDir)->Expect.toBe(dir)
        t->expect(recovery.nearestDirRelative)->Expect.toBe("")
      }
    }

    await cleanup(dir)
  })

  testAsync("regression replay: 3addabc6-like sequence avoids avoidable ENOENTs", async t => {
    ToolPathHints.clear()
    let dir = await makeFixture()
    let ctx = makeCtx(dir)

    let treeResult = await ListTree.execute(ctx, {path: ?Some("apps/marketing/src/pages/docs")})

    switch treeResult {
    | Ok(output) => t->expect(output.tree->String.includes("[recovered]"))->Expect.toBe(true)
    | Error(msg) => failwith(`list_tree recovery failed: ${msg}`)
    }

    let mislocatedRead = await ReadFile.execute(
      ctx,
      {path: "apps/marketing/src/content/docs/docs/reference/installation.md"},
    )

    switch mislocatedRead {
    | Ok(_) => failwith("Expected mislocated read to return guidance")
    | Error(msg) => t->expect(msg->String.includes("ENOENT"))->Expect.toBe(false)
    }

    let zeroA = await SearchFiles.execute(
      ctx,
      {pattern: "index.d.ts", path: ?Some("libs/frontman-nextjs")},
    )

    switch zeroA {
    | Ok(output) => t->expect(output.totalResults)->Expect.toBe(0)
    | Error(msg) => failwith(`search_files nextjs failed: ${msg}`)
    }

    let readA = await ReadFile.execute(ctx, {path: "libs/frontman-nextjs/index.d.ts"})

    switch readA {
    | Ok(_) => failwith("Expected guarded read error for nextjs")
    | Error(msg) => {
        t->expect(msg->String.includes("Zero-result guardrail"))->Expect.toBe(true)
        t->expect(msg->String.includes("ENOENT"))->Expect.toBe(false)
      }
    }

    let zeroB = await SearchFiles.execute(
      ctx,
      {pattern: "index.d.ts", path: ?Some("libs/frontman-vite")},
    )

    switch zeroB {
    | Ok(output) => t->expect(output.totalResults)->Expect.toBe(0)
    | Error(msg) => failwith(`search_files vite failed: ${msg}`)
    }

    let readB = await ReadFile.execute(ctx, {path: "libs/frontman-vite/index.d.ts"})

    switch readB {
    | Ok(_) => failwith("Expected guarded read error for vite")
    | Error(msg) => {
        t->expect(msg->String.includes("Zero-result guardrail"))->Expect.toBe(true)
        t->expect(msg->String.includes("ENOENT"))->Expect.toBe(false)
      }
    }

    await cleanup(dir)
  })
})
