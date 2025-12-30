open Vitest

module Bindings = FrontmanBindings

describe("ContextLoader__Core", () => {
  // Test pure functions
  describe("generateLocalPaths", () => {
    test(
      "generates paths from root to cwd",
      t => {
        let paths = ContextLoader__Core.generateLocalPaths(
          "AGENTS.md",
          ~cwd="/home/user/project/sub",
          ~root="/home/user/project",
        )

        t->expect(Array.length(paths))->Expect.toBe(2)
        // First should be root
        t->expect(Array.getUnsafe(paths, 0))->Expect.toBe("/home/user/project/AGENTS.md")
        // Second should be cwd
        t->expect(Array.getUnsafe(paths, 1))->Expect.toBe("/home/user/project/sub/AGENTS.md")
      },
    )
  })

  describe("expandTilde", () => {
    test(
      "expands ~ to home directory",
      t => {
        let result = ContextLoader__Core.expandTilde("~/documents/file.txt")
        let home = Bindings.Os.homedir()
        t->expect(String.startsWith(result, home))->Expect.toBe(true)
      },
    )
  })

  describe("generateLocalCandidates", () => {
    test(
      "generates candidates per directory with all filenames",
      t => {
        let candidates = ContextLoader__Core.generateLocalCandidates(
          ~cwd="/home/user/project/sub",
          ~root="/home/user/project",
        )

        // Should have 2 tuples (one per directory: root and sub)
        t->expect(Array.length(candidates))->Expect.toBe(2)

        // First should be root directory with all candidate paths
        let (rootDir, rootPaths) = Array.getUnsafe(candidates, 0)
        t->expect(rootDir)->Expect.toBe("/home/user/project")
        t->expect(Array.length(rootPaths))->Expect.toBe(3) // AGENTS.md, CLAUDE.md, CONTEXT.md

        // Second should be sub directory
        let (subDir, subPaths) = Array.getUnsafe(candidates, 1)
        t->expect(subDir)->Expect.toBe("/home/user/project/sub")
        t->expect(Array.length(subPaths))->Expect.toBe(3)
      },
    )
  })
})
