open Vitest

module ListTree = FrontmanCore__Tool__ListTree
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module ChildProcess = FrontmanCore__ChildProcess

module Process = FrontmanBindings.Process

@module("node:fs/promises") external chmod: (string, int) => promise<unit> = "chmod"
@val @scope("process") external getuid: unit => int = "getuid"

let tmpPrefix = "/tmp/listtree-test-"

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

describe("ListTree Tool - execute (integration)", _t => {
  test("preserves tree formatting, shared paths, workspace labels and truncation", t => {
    let workspacePaths = ListTree.buildWorkspacePathLookup([
      {name: "app", path: "src"},
      {name: "not-a-directory", path: "z.ts"},
    ])
    let tree =
      ["z.ts", "src/b.ts", "empty/", "src/a.ts", "src/", "src/a.ts", "node_modules/x.js"]
      ->ListTree.buildTrie
      ->ListTree.renderTree(~maxDepth=3, ~workspacePaths)
    t
    ->expect(tree)
    ->Expect.toBe(
      ".\n├── empty/\n├── src/ [workspace: app]\n│   ├── a.ts\n│   └── b.ts\n└── z.ts",
    )

    let truncated =
      Array.fromInitializer(~length=16, i => `file${Int.toString(i)}.ts`)
      ->ListTree.buildTrie
      ->ListTree.renderTree(~maxDepth=1, ~workspacePaths)
    t->expect(truncated->String.split("\n")->Array.length)->Expect.toBe(12)
    t->expect(truncated->String.endsWith("└── ... and 6 more entries"))->Expect.toBe(true)
  })

  testAsync("should return a text tree for a simple project", async t => {
    let dir = await makeTmpDir()
    await writeFile(dir, "src/index.ts", "")
    await writeFile(dir, "src/utils/helpers.ts", "")
    await writeFile(dir, "package.json", "{}")
    await writeFile(dir, "tsconfig.json", "{}")
    await initGitRepo(dir)

    let result = await ListTree.executeOutput(makeCtx(dir), {})

    switch result {
    | Ok(output) => {
        t->expect(output.tree->String.startsWith("."))->Expect.toBe(true)

        t->expect(output.tree->String.includes("src/"))->Expect.toBe(true)
        t->expect(output.tree->String.includes("package.json"))->Expect.toBe(true)
        t->expect(output.tree->String.includes("tsconfig.json"))->Expect.toBe(true)

        t->expect(output.monorepoType)->Expect.toBe(None)
        t->expect(Array.length(output.workspaces))->Expect.toBe(0)
      }
    | Error(msg) => failwith(`ListTree failed: ${msg}`)
    }

    await cleanup(dir)
  })

  testAsync("should detect npm workspaces monorepo", async t => {
    let dir = await makeTmpDir()
    await writeFile(
      dir,
      "package.json",
      `{"name": "my-monorepo", "workspaces": ["apps/*", "packages/*"]}`,
    )
    await writeFile(dir, "apps/web/package.json", `{"name": "@myapp/web"}`)
    await writeFile(dir, "apps/web/src/index.ts", "")
    await writeFile(dir, "apps/api/package.json", `{"name": "@myapp/api"}`)
    await writeFile(dir, "apps/api/src/index.ts", "")
    await writeFile(dir, "packages/shared/package.json", `{"name": "@myapp/shared"}`)
    await writeFile(dir, "packages/shared/src/index.ts", "")
    await initGitRepo(dir)

    let result = await ListTree.executeOutput(makeCtx(dir), {})

    switch result {
    | Ok(output) => {
        t->expect(output.monorepoType)->Expect.toBe(Some("npm-workspaces"))

        t->expect(Array.length(output.workspaces))->Expect.toBe(3)

        let wsNames = output.workspaces->Array.map(w => w.name)
        t->expect(wsNames->Array.includes("@myapp/web"))->Expect.toBe(true)
        t->expect(wsNames->Array.includes("@myapp/api"))->Expect.toBe(true)
        t->expect(wsNames->Array.includes("@myapp/shared"))->Expect.toBe(true)

        t->expect(output.tree->String.includes("[workspace:"))->Expect.toBe(true)
      }
    | Error(msg) => failwith(`ListTree failed: ${msg}`)
    }

    await cleanup(dir)
  })

  testAsync("should detect turborepo", async t => {
    let dir = await makeTmpDir()
    await writeFile(dir, "package.json", `{"name": "turbo-monorepo", "workspaces": ["apps/*"]}`)
    await writeFile(dir, "turbo.json", `{"pipeline": {}}`)
    await writeFile(dir, "apps/web/package.json", `{"name": "web"}`)
    await writeFile(dir, "apps/web/src/index.ts", "")
    await initGitRepo(dir)

    let result = await ListTree.executeOutput(makeCtx(dir), {})

    switch result {
    | Ok(output) => t->expect(output.monorepoType)->Expect.toBe(Some("turborepo"))
    | Error(msg) => failwith(`ListTree failed: ${msg}`)
    }

    await cleanup(dir)
  })

  testAsync("respects depth with Git, without Git and outside repositories", async t => {
    let dir = await makeTmpDir()
    await writeFile(dir, "a/b/c/d/deep.ts", "")
    await writeFile(dir, "a/b/shallow.ts", "")
    let _ = await Fs.Promises.mkdir(dir ++ "/empty", {recursive: true})
    await writeFile(dir, "node_modules/hidden.js", "")
    let path = Process.env->Dict.get("PATH")->Option.getOrThrow
    try {
      for mode in 0 to 2 {
        switch mode {
        | 1 => Process.env->Dict.set("PATH", dir)
        | 2 =>
          Process.env->Dict.set("PATH", path)
          await initGitRepo(dir)
        | _ => ()
        }
        let shallow = (await ListTree.executeOutput(makeCtx(dir), {depth: 1}))->Result.getOrThrow
        let deep = (await ListTree.executeOutput(makeCtx(dir), {depth: 3}))->Result.getOrThrow
        t->expect(shallow.tree->String.includes("a/"))->Expect.toBe(true)
        t->expect(shallow.tree->String.includes("b/"))->Expect.toBe(false)
        t->expect(deep.tree->String.includes("c/"))->Expect.toBe(true)
        t->expect(deep.tree->String.includes("shallow.ts"))->Expect.toBe(true)
        t->expect(deep.tree->String.includes("d/"))->Expect.toBe(false)
        t->expect(deep.tree->String.includes("node_modules"))->Expect.toBe(false)
        t->expect(deep.tree->String.includes("empty/"))->Expect.toBe(mode != 2)
        t->expect(deep.tree->String.includes("[filesystem fallback]"))->Expect.toBe(mode != 2)
      }
    } catch {
    | exn =>
      Process.env->Dict.set("PATH", path)
      await cleanup(dir)
      raise(exn)
    }
    await cleanup(dir)
  })

  testAsync("includes untracked files but excludes ignored and noise paths", async t => {
    let dir = await makeTmpDir()
    await writeFile(dir, "src/index.ts", "")
    await writeFile(dir, "node_modules/foo/index.js", "")
    await writeFile(dir, ".git/config", "")
    await writeFile(dir, "dist/bundle.js", "")
    let _ = await ChildProcess.execWithOptions("git init", {cwd: dir})
    let _ = await ChildProcess.execWithOptions("git add src/index.ts", {cwd: dir})

    let unusual = "quote'$(touch INJECTED)\nfile.ts"
    await writeFile(dir, unusual, "")
    await writeFile(dir, ".gitignore", "ignored.ts\n")
    await writeFile(dir, "ignored.ts", "")
    let paths = (await ListTree.getTrackedFiles(~cwd=dir))->Result.getOrThrow->Option.getOrThrow
    t->expect(paths->Array.includes(unusual))->Expect.toBe(true)
    t->expect(paths->Array.includes("ignored.ts"))->Expect.toBe(false)
    let result = await ListTree.executeOutput(makeCtx(dir), {})

    switch result {
    | Ok(output) => {
        t->expect(output.tree->String.includes("[filesystem fallback]"))->Expect.toBe(false)
        t->expect(output.tree->String.includes("src/"))->Expect.toBe(true)
        t->expect(output.tree->String.includes("node_modules"))->Expect.toBe(false)
        t->expect(output.tree->String.includes("dist"))->Expect.toBe(false)
      }
    | Error(msg) => failwith(`ListTree failed: ${msg}`)
    }

    await cleanup(dir)
  })

  testAsync("should support path parameter for subtree exploration", async t => {
    let dir = await makeTmpDir()
    await writeFile(dir, "apps/web/src/index.ts", "")
    await writeFile(dir, "apps/web/src/utils/helpers.ts", "")
    await writeFile(dir, "apps/api/src/index.ts", "")
    await writeFile(dir, "packages/shared/src/index.ts", "")
    await initGitRepo(dir)

    let result = await ListTree.executeOutput(makeCtx(dir), {path: ?Some("apps/web")})

    switch result {
    | Ok(output) => {
        t->expect(output.tree->String.includes("src/"))->Expect.toBe(true)
        t->expect(output.tree->String.includes("index.ts"))->Expect.toBe(true)
        t->expect(output.tree->String.includes("api"))->Expect.toBe(false)
        t->expect(output.tree->String.includes("packages"))->Expect.toBe(false)
      }
    | Error(msg) => failwith(`ListTree subtree failed: ${msg}`)
    }

    await cleanup(dir)
  })

  testAsync("should handle file path as input (falls back to parent directory)", async t => {
    let dir = await makeTmpDir()
    await writeFile(dir, "src/index.ts", "")
    await writeFile(dir, "src/utils/helpers.ts", "")
    await writeFile(dir, "package.json", "{}")
    await initGitRepo(dir)

    let result = await ListTree.executeOutput(makeCtx(dir), {path: ?Some("src/index.ts")})

    switch result {
    | Ok(output) => {
        t->expect(output.tree->String.length > 0)->Expect.toBe(true)
        t->expect(output.tree->String.includes("index.ts"))->Expect.toBe(true)
      }
    | Error(msg) => failwith(`ListTree should not fail on file paths: ${msg}`)
    }

    await cleanup(dir)
  })

  testAsync("should sort directories before files", async t => {
    let dir = await makeTmpDir()
    await writeFile(dir, "zebra.ts", "")
    await writeFile(dir, "alpha/index.ts", "")
    await writeFile(dir, "beta.ts", "")
    await initGitRepo(dir)

    let result = await ListTree.executeOutput(makeCtx(dir), {})

    switch result {
    | Ok(output) => {
        let lines = output.tree->String.split("\n")
        let alphaIdx = lines->Array.findIndex(l => l->String.includes("alpha/"))
        let zebraIdx = lines->Array.findIndex(l => l->String.includes("zebra.ts"))
        let betaIdx = lines->Array.findIndex(l => l->String.includes("beta.ts"))
        t->expect(alphaIdx < zebraIdx)->Expect.toBe(true)
        t->expect(alphaIdx < betaIdx)->Expect.toBe(true)
      }
    | Error(msg) => failwith(`ListTree sort failed: ${msg}`)
    }

    await cleanup(dir)
  })

  testAsync("reports missing roots and invalid Git metadata with path context", async t => {
    let dir = await makeTmpDir()
    await writeFile(dir, ".git", "invalid git metadata\n")
    for i in 0 to 1 {
      let root = switch i {
      | 0 => dir
      | _ => dir ++ "/missing"
      }
      switch await ListTree.executeOutput(makeCtx(root), {}) {
      | Ok(_) => failwith("Expected discovery error")
      | Error(msg) =>
        t->expect(msg->String.includes("sourceRoot: " ++ root))->Expect.toBe(true)
        t->expect(msg->String.includes("resolved: " ++ root))->Expect.toBe(true)
        switch i {
        | 0 => t->expect(msg->String.includes("invalid gitfile format"))->Expect.toBe(true)
        | _ => ()
        }
      }
    }
    await cleanup(dir)
  })

  testAsync("rejects unreadable directories in filesystem and Git scans", async t => {
    switch getuid() == 0 {
    | true => ()
    | false =>
      let dir = await makeTmpDir()
      await writeFile(dir, "src/hidden.ts", "")
      for mode in 0 to 1 {
        switch mode {
        | 1 =>
          (await ChildProcess.spawnResult("git", ["init"], ~cwd=dir))->Result.getOrThrow->ignore
        | _ => ()
        }
        await chmod(dir ++ "/src", 0)
        let result = await ListTree.executeOutput(makeCtx(dir), {})
        await chmod(dir ++ "/src", 493)
        switch result {
        | Ok(_) => failwith("Expected permission error")
        | Error(msg) =>
          t
          ->expect(msg->String.includes("EACCES") || msg->String.includes("Permission denied"))
          ->Expect.toBe(true)
          t->expect(msg->String.includes("sourceRoot: " ++ dir))->Expect.toBe(true)
          t->expect(msg->String.includes("[filesystem fallback]"))->Expect.toBe(false)
          switch mode {
          | 1 => t->expect(msg->String.includes("could not open directory"))->Expect.toBe(true)
          | _ => ()
          }
        }
      }
      await cleanup(dir)
    }
  })

  testAsync("should detect pnpm workspaces", async t => {
    let dir = await makeTmpDir()
    await writeFile(dir, "package.json", `{"name": "pnpm-mono", "workspaces": ["packages/*"]}`)
    await writeFile(dir, "pnpm-workspace.yaml", "packages:\n  - 'packages/*'\n")
    await writeFile(dir, "packages/ui/package.json", `{"name": "@mono/ui"}`)
    await writeFile(dir, "packages/ui/src/index.ts", "")
    await initGitRepo(dir)

    let result = await ListTree.executeOutput(makeCtx(dir), {})

    switch result {
    | Ok(output) => {
        t->expect(output.monorepoType)->Expect.toBe(Some("pnpm-workspaces"))
        t->expect(Array.length(output.workspaces))->Expect.toBe(1)

        let ws = output.workspaces->Array.getUnsafe(0)
        t->expect(ws.name)->Expect.toBe("@mono/ui")
        t->expect(ws.path)->Expect.toBe("packages/ui")
      }
    | Error(msg) => failwith(`ListTree pnpm failed: ${msg}`)
    }

    await cleanup(dir)
  })
})
