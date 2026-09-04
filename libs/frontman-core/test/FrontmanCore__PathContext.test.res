open Vitest

module Path = FrontmanBindings.Path
module PathContext = FrontmanCore__PathContext

describe("toRelativePath", () => {
  test("uses platform path relative calculation", t => {
    let sourceRoot = Path.resolve("/project")
    let absolutePath = Path.join([sourceRoot, "src", "App.tsx"])

    t
    ->expect(PathContext.toRelativePath(~sourceRoot, ~absolutePath))
    ->Expect.toBe(Path.join(["src", "App.tsx"]))
  })

  test("returns empty path for source root itself", t => {
    let sourceRoot = Path.resolve("/project")

    t->expect(PathContext.toRelativePath(~sourceRoot, ~absolutePath=sourceRoot))->Expect.toBe("")
  })
})

describe("resolveSearchPath", () => {
  test("rejects absolute paths outside sourceRoot", t => {
    switch PathContext.resolveSearchPath(~sourceRoot="/project", ~inputPath=Some("/etc/passwd")) {
    | Ok(_) => t->expect("should have failed")->Expect.toBe("")
    | Error(err) =>
      t
      ->expect(err.message->String.includes("Absolute path must be under source root"))
      ->Expect.toBe(true)
    }
  })

  test("defaults to resolved sourceRoot", t => {
    switch PathContext.resolveSearchPath(~sourceRoot=".", ~inputPath=None) {
    | Ok(path) => t->expect(path)->Expect.toBe(Path.resolve("."))
    | Error(err) => t->expect(err.message)->Expect.toBe("should not fail")
    }
  })
})
