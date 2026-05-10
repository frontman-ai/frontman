open Vitest

module ProjectPath = FrontmanCore__ProjectPath
module CorePath = FrontmanCore__Path
module Path = FrontmanBindings.Path

// ============================================
// resolve — basic behavior
// ============================================
describe("resolve", () => {
  test("classifies API path strings into typed input paths", t => {
    let absolutePath = CorePath.fromString("/project/src/file.ts")
    let relativePath = CorePath.fromString("src\\file.ts")

    t
    ->expect(absolutePath->CorePath.fold(~absolute=path => path, ~relative=_ => "wrong"))
    ->Expect.toBe("/project/src/file.ts")
    t
    ->expect(relativePath->CorePath.fold(~absolute=_ => "wrong", ~relative=path => path))
    ->Expect.toBe("src/file.ts")
  })

  test("resolves already-classified relative paths", t => {
    let result = ProjectPath.resolveParsed(
      ~sourceRoot="/project",
      ~inputPath=CorePath.relative("src/file.ts"),
    )

    switch result {
    | Ok(projectPath) =>
      t->expect(ProjectPath.toString(projectPath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("resolves already-classified absolute paths", t => {
    let result = ProjectPath.resolveParsed(
      ~sourceRoot="/project",
      ~inputPath=CorePath.absolute("/project/src/file.ts"),
    )

    switch result {
    | Ok(projectPath) =>
      t->expect(ProjectPath.toString(projectPath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("resolves relative path under sourceRoot", t => {
    let result = ProjectPath.resolve(~sourceRoot="/project", ~inputPath="src/file.ts")
    switch result {
    | Ok(projectPath) =>
      t->expect(ProjectPath.toString(projectPath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("resolves dot path to sourceRoot", t => {
    let result = ProjectPath.resolve(~sourceRoot="/project", ~inputPath=".")
    switch result {
    | Ok(projectPath) => t->expect(ProjectPath.toString(projectPath))->Expect.toBe("/project")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("rejects path escaping sourceRoot via ..", t => {
    let result = ProjectPath.resolve(~sourceRoot="/project", ~inputPath="../../etc/passwd")
    switch result {
    | Ok(_) => t->expect("should have failed")->Expect.toBe("")
    | Error(_) => t->expect(true)->Expect.toBe(true)
    }
  })

  test("accepts absolute path under sourceRoot", t => {
    let result = ProjectPath.resolve(~sourceRoot="/project", ~inputPath="/project/src/file.ts")
    switch result {
    | Ok(projectPath) =>
      t->expect(ProjectPath.toString(projectPath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("rejects absolute path outside sourceRoot", t => {
    let result = ProjectPath.resolve(~sourceRoot="/project", ~inputPath="/etc/passwd")
    switch result {
    | Ok(_) => t->expect("should have failed")->Expect.toBe("")
    | Error(_) => t->expect(true)->Expect.toBe(true)
    }
  })

  test("handles sourceRoot without trailing separator", t => {
    // Verify the separator appending logic doesn't break valid paths
    let result = ProjectPath.resolve(~sourceRoot="/project/src", ~inputPath="file.ts")
    switch result {
    | Ok(projectPath) =>
      t->expect(ProjectPath.toString(projectPath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("handles sourceRoot with trailing forward slash", t => {
    let result = ProjectPath.resolve(~sourceRoot="/project/src/", ~inputPath="file.ts")
    switch result {
    | Ok(projectPath) =>
      t->expect(ProjectPath.toString(projectPath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("path.sep is a valid separator character", t => {
    // Verify Path.sep is either / or \ — sanity check for the binding
    t->expect(Path.sep == "/" || Path.sep == "\\")->Expect.toBe(true)
  })
})

// ============================================
// resolve — separator handling (Issue #432)
// On macOS/Linux, Path.normalize uses /
// These tests verify the logic is correct with forward slashes;
// on Windows, the same code uses Path.sep (\) to append separators.
// ============================================
describe("resolve - separator handling", () => {
  test("sourceRoot at path boundary is enforced (no prefix collision)", t => {
    // /project-extra should NOT be accepted under /project
    let result = ProjectPath.resolve(~sourceRoot="/project", ~inputPath="/project-extra/file.ts")
    switch result {
    | Ok(_) => t->expect("should have rejected path prefix collision")->Expect.toBe("")
    | Error(_) => t->expect(true)->Expect.toBe(true)
    }
  })

  test("accepts sourceRoot itself as absolute input", t => {
    let result = ProjectPath.resolve(~sourceRoot="/project", ~inputPath="/project")
    switch result {
    | Ok(projectPath) => t->expect(ProjectPath.toString(projectPath))->Expect.toBe("/project")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("nested sourceRoot with similar prefix is safe", t => {
    // /a/bc should not match /a/b as sourceRoot
    let result = ProjectPath.resolve(~sourceRoot="/a/b", ~inputPath="/a/bc/file.ts")
    switch result {
    | Ok(_) => t->expect("should have rejected similar prefix")->Expect.toBe("")
    | Error(_) => t->expect(true)->Expect.toBe(true)
    }
  })
})

describe("toRelativePath", () => {
  test("converts absolute path under dot sourceRoot to relative path", t => {
    let cwd = Path.resolve(".")
    let absolutePath = Path.join([cwd, "src", "App.tsx"])
    let relativePath = FrontmanCore__PathContext.toRelativePath(~sourceRoot=".", ~absolutePath)

    t->expect(relativePath)->Expect.toBe("src/App.tsx")
  })

  test("does not slice prefix-adjacent paths", t => {
    let relativePath = FrontmanCore__PathContext.toRelativePath(
      ~sourceRoot="/repo/app",
      ~absolutePath="/repo/application/src/page.tsx",
    )

    t->expect(relativePath)->Expect.toBe("/repo/application/src/page.tsx")
  })
})

// ============================================
// dirname
// ============================================
describe("dirname", () => {
  test("returns parent directory", t => {
    switch ProjectPath.resolve(~sourceRoot="/project", ~inputPath="src/file.ts") {
    | Ok(projectPath) => t->expect(ProjectPath.dirname(projectPath))->Expect.toBe("/project/src")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })
})

// ============================================
// join
// ============================================
describe("join", () => {
  test("joins path segments and validates result", t => {
    switch ProjectPath.resolve(~sourceRoot="/project", ~inputPath="src") {
    | Ok(projectPath) =>
      switch ProjectPath.join(~sourceRoot="/project", projectPath, ["file.ts"]) {
      | Ok(joined) => t->expect(ProjectPath.toString(joined))->Expect.toBe("/project/src/file.ts")
      | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
      }
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("rejects join that escapes sourceRoot", t => {
    switch ProjectPath.resolve(~sourceRoot="/project", ~inputPath="src") {
    | Ok(projectPath) =>
      switch ProjectPath.join(~sourceRoot="/project", projectPath, ["..", "..", "etc"]) {
      | Ok(_) => t->expect("should have failed")->Expect.toBe("")
      | Error(_) => t->expect(true)->Expect.toBe(true)
      }
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })
})
