open Vitest

module Tree = FrontmanCore__Tool__ListTree
module Files = FrontmanCore__Tool__ListFiles
module Fs = FrontmanBindings.Fs
module Process = FrontmanBindings.Process
module ChildProcess = FrontmanCore__ChildProcess
module Helpers = FrontmanCore__ToolTestHelpers
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

@module("node:fs/promises") external mkdtemp: string => promise<string> = "mkdtemp"
@module("node:fs/promises") external chmod: (string, int) => promise<unit> = "chmod"
@val @scope("process") external getuid: unit => int = "getuid"

let setup = async () => {
  let dir = await mkdtemp("/tmp/frontman-discovery-")
  let _ = await Fs.Promises.mkdir(dir ++ "/src/nested", {recursive: true})
  let _ = await Fs.Promises.mkdir(dir ++ "/empty", {recursive: true})
  let _ = await Fs.Promises.mkdir(dir ++ "/node_modules", {recursive: true})
  await Fs.Promises.writeFile(dir ++ "/src/nested/page.ts", "")
  await Fs.Promises.writeFile(dir ++ "/.gitignore", "ignored.ts\nnode_modules/\n")
  await Fs.Promises.writeFile(dir ++ "/ignored.ts", "")
  let ctx: Tool.serverExecutionContext = {projectRoot: dir, sourceRoot: dir}
  ctx
}

let cleanup = async ctx => {
  (await ChildProcess.spawnResult("rm", ["-rf", ctx.Tool.sourceRoot]))->Result.getOrThrow->ignore
}

let checkFallback = async (t, ctx) => {
  let tree = (await Tree.executeOutput(ctx, {}))->Result.getOrThrow
  t->expect(tree.tree->String.includes("[filesystem fallback]"))->Expect.toBe(true)
  t->expect(tree.tree->String.includes("page.ts"))->Expect.toBe(true)
  t->expect(tree.tree->String.includes("empty/"))->Expect.toBe(true)
  t->expect(tree.tree->String.includes("node_modules"))->Expect.toBe(false)
  let shallow = (await Tree.executeOutput(ctx, {depth: 1}))->Result.getOrThrow
  t->expect(shallow.tree->String.includes("src/"))->Expect.toBe(true)
  t->expect(shallow.tree->String.includes("page.ts"))->Expect.toBe(false)
  let files = (await Files.execute(ctx, {path: "src/nested"}))->Helpers.text->Result.getOrThrow
  t->expect(files->String.includes("[filesystem fallback]"))->Expect.toBe(true)
  t->expect(files->String.includes("page.ts"))->Expect.toBe(true)
}

describe("Git-optional file discovery", _ => {
  testAsync("walks non-Git projects with directory types, depth limits and notices", async t => {
    let ctx = await setup()
    await checkFallback(t, ctx)
    await cleanup(ctx)
  })

  testAsync("works when the Git executable is missing", async t => {
    let ctx = await setup()
    let path = Process.env->Dict.get("PATH")->Option.getOrThrow
    Process.env->Dict.set("PATH", ctx.sourceRoot)
    try {
      await checkFallback(t, ctx)
    } catch {
    | exn =>
      Process.env->Dict.set("PATH", path)
      await cleanup(ctx)
      raise(exn)
    }
    Process.env->Dict.set("PATH", path)
    await cleanup(ctx)
  })

  testAsync("includes untracked files but excludes ignored files in Git projects", async t => {
    let ctx = await setup()
    (await ChildProcess.spawnResult("git", ["init"], ~cwd=ctx.sourceRoot))
    ->Result.getOrThrow
    ->ignore
    (await ChildProcess.spawnResult("git", ["add", ".gitignore"], ~cwd=ctx.sourceRoot))
    ->Result.getOrThrow
    ->ignore
    let tree = (await Tree.executeOutput(ctx, {}))->Result.getOrThrow
    t->expect(tree.tree->String.includes("page.ts"))->Expect.toBe(true)
    t->expect(tree.tree->String.includes("ignored.ts"))->Expect.toBe(false)
    t->expect(tree.tree->String.includes("[filesystem fallback]"))->Expect.toBe(false)
    let files =
      (await Files.execute(ctx, {}))->Helpers.decode(Files.outputSchema)->Result.getOrThrow
    t->expect(files->Array.some(entry => entry.name == "ignored.ts"))->Expect.toBe(false)
    await cleanup(ctx)
  })

  testAsync("does not hide other Git failures behind a filesystem fallback", async t => {
    let ctx = await setup()
    await Fs.Promises.writeFile(ctx.sourceRoot ++ "/.git", "invalid git metadata\n")
    let results = [
      (await Tree.execute(ctx, {}))->Helpers.text,
      (await Files.execute(ctx, {}))->Helpers.text,
    ]
    await cleanup(ctx)
    results->Array.forEach(
      result =>
        switch result {
        | Ok(_) => failwith("Expected invalid Git metadata error")
        | Error(msg) =>
          t->expect(msg->String.includes("invalid gitfile format"))->Expect.toBe(true)
          t->expect(msg->String.includes("sourceRoot:"))->Expect.toBe(true)
        },
    )
  })

  testAsync("preserves unusual filenames without shell expansion", async t => {
    let ctx = await setup()
    let name = "quote'$(touch INJECTED)\nfile.ts"
    await Fs.Promises.writeFile(ctx.sourceRoot ++ "/" ++ name, "")
    await Fs.Promises.writeFile(ctx.sourceRoot ++ "/secret'file.ts", "")
    await Fs.Promises.writeFile(ctx.sourceRoot ++ "/.gitignore", "secret'file.ts\n")
    (await ChildProcess.spawnResult("git", ["init"], ~cwd=ctx.sourceRoot))
    ->Result.getOrThrow
    ->ignore
    let files =
      (await Files.execute(ctx, {}))->Helpers.decode(Files.outputSchema)->Result.getOrThrow
    t->expect(files->Array.some(entry => entry.name == name))->Expect.toBe(true)
    t->expect(files->Array.some(entry => entry.name == "secret'file.ts"))->Expect.toBe(false)
    t
    ->expect((await Fs.Promises.readdir(ctx.sourceRoot))->Array.includes("INJECTED"))
    ->Expect.toBe(false)
    let paths =
      (await Tree.getTrackedFiles(~cwd=ctx.sourceRoot))->Result.getOrThrow->Option.getOrThrow
    t->expect(paths->Array.includes(name))->Expect.toBe(true)
    await cleanup(ctx)
  })

  testAsync("reports source-root context for missing directories", async t => {
    let ctx = await setup()
    let missing = {...ctx, sourceRoot: ctx.sourceRoot ++ "/missing"}
    let results = [
      (await Tree.execute(missing, {}))->Helpers.text,
      (await Files.execute(missing, {}))->Helpers.text,
    ]
    results->Array.forEach(
      result =>
        switch result {
        | Ok(_) => failwith("Expected missing-root error")
        | Error(msg) =>
          t->expect(msg->String.includes("sourceRoot: " ++ missing.sourceRoot))->Expect.toBe(true)
          t->expect(msg->String.includes("resolved: " ++ missing.sourceRoot))->Expect.toBe(true)
        },
    )
    await cleanup(ctx)
  })

  testAsync("rejects Git scans that omit unreadable untracked directories", async t => {
    switch getuid() == 0 {
    | true => ()
    | false =>
      let ctx = await setup()
      (await ChildProcess.spawnResult("git", ["init"], ~cwd=ctx.sourceRoot))
      ->Result.getOrThrow
      ->ignore
      await chmod(ctx.sourceRoot ++ "/src", 0)
      let result = try {
        (await Tree.execute(ctx, {}))->Helpers.text
      } catch {
      | exn =>
        await chmod(ctx.sourceRoot ++ "/src", 493)
        await cleanup(ctx)
        raise(exn)
      }
      await chmod(ctx.sourceRoot ++ "/src", 493)
      await cleanup(ctx)
      switch result {
      | Ok(_) => failwith("Expected incomplete Git scan error")
      | Error(msg) =>
        t->expect(msg->String.includes("could not open directory"))->Expect.toBe(true)
        t->expect(msg->String.includes("Permission denied"))->Expect.toBe(true)
        t->expect(msg->String.includes("sourceRoot: " ++ ctx.sourceRoot))->Expect.toBe(true)
        t->expect(msg->String.includes("[filesystem fallback]"))->Expect.toBe(false)
      }
    }
  })

  testAsync("keeps permission failures visible", async t => {
    switch getuid() == 0 {
    | true => ()
    | false =>
      let ctx = await setup()
      await chmod(ctx.sourceRoot ++ "/src", 0)
      let results = [
        (await Tree.execute(ctx, {path: "src"}))->Helpers.text,
        (await Files.execute(ctx, {path: "src"}))->Helpers.text,
      ]
      await chmod(ctx.sourceRoot ++ "/src", 493)
      await cleanup(ctx)
      results->Array.forEach(
        result =>
          switch result {
          | Ok(_) => failwith("Expected permission error")
          | Error(msg) =>
            t
            ->expect(msg->String.includes("EACCES") || msg->String.includes("Permission denied"))
            ->Expect.toBe(true)
            t->expect(msg->String.includes("sourceRoot:"))->Expect.toBe(true)
          },
      )
    }
  })
})
