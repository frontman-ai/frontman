open Vitest

module Bindings = AskTheLlmBindings

describe("ContextLoader__Core", () => {
  // Test pure functions
  describe("generateLocalPaths", () => {
    test(
      "generates paths from cwd to root",
      t => {
        let paths = ContextLoader__Core.generateLocalPaths(
          "AGENTS.md",
          ~cwd="/home/user/project/sub",
          ~root="/home/user/project",
        )

        t->expect(Array.length(paths) > 0)->Expect.toBe(true)
        t->expect(Array.getUnsafe(paths, 0))->Expect.toBe("/home/user/project/sub/AGENTS.md")
      },
    )

    test(
      "stops at root directory",
      t => {
        let paths = ContextLoader__Core.generateLocalPaths(
          "AGENTS.md",
          ~cwd="/home/user/project",
          ~root="/home/user/project",
        )

        t->expect(Array.length(paths))->Expect.toBe(1)
        t->expect(Array.getUnsafe(paths, 0))->Expect.toBe("/home/user/project/AGENTS.md")
      },
    )
  })

  describe("globalFilePaths", () => {
    test(
      "generates default global paths",
      t => {
        let paths = ContextLoader__Core.globalFilePaths(None)
        t->expect(Array.length(paths))->Expect.toBe(2)
      },
    )

    test(
      "uses custom config directory",
      t => {
        let paths = ContextLoader__Core.globalFilePaths(Some("/custom/config"))
        t
        ->expect(Array.some(paths, path => String.includes(path, "/custom/config")))
        ->Expect.toBe(true)
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

    test(
      "handles plain ~",
      t => {
        let result = ContextLoader__Core.expandTilde("~")
        let home = Bindings.Os.homedir()
        t->expect(String.startsWith(result, home))->Expect.toBe(true)
      },
    )

    test(
      "leaves absolute paths unchanged",
      t => {
        let result = ContextLoader__Core.expandTilde("/absolute/path")
        t->expect(result)->Expect.toBe("/absolute/path")
      },
    )
  })

  describe("filterEmpty", () => {
    test(
      "removes files with empty content",
      t => {
        let files = [
          ContextLoader__Core.makeLoadedFile("/a.md", "content", Local, ~discovered=true),
          ContextLoader__Core.makeLoadedFile("/b.md", "", Local, ~discovered=true),
          ContextLoader__Core.makeLoadedFile("/c.md", "more", Local, ~discovered=true),
        ]

        let filtered = ContextLoader__Core.filterEmpty(files)
        t->expect(Array.length(filtered))->Expect.toBe(2)
      },
    )
  })

  describe("calculateTotalSize", () => {
    test(
      "sums content lengths",
      t => {
        let files = [
          ContextLoader__Core.makeLoadedFile("/a.md", "abc", Local, ~discovered=true),
          ContextLoader__Core.makeLoadedFile("/b.md", "defgh", Local, ~discovered=true),
        ]

        let total = ContextLoader__Core.calculateTotalSize(files)
        t->expect(total)->Expect.toBe(8) // 3 + 5
      },
    )
  })

  describe("generateLocalCandidates", () => {
    test(
      "generates candidates for all file names in priority order",
      t => {
        let candidates = ContextLoader__Core.generateLocalCandidates(
          ~cwd="/home/user/project",
          ~root="/home/user/project",
        )

        // Should have 3 tuples (AGENTS.md, CLAUDE.md, CONTEXT.md)
        t->expect(Array.length(candidates))->Expect.toBe(3)

        // First should be AGENTS.md (highest priority)
        let (firstFilename, _) = Array.getUnsafe(candidates, 0)
        t->expect(firstFilename)->Expect.toBe("AGENTS.md")
      },
    )
  })

  describe("buildLoadedContext", () => {
    test(
      "builds context from loaded files",
      t => {
        let files = [
          ContextLoader__Core.makeLoadedFile("/a.md", "abc", Local, ~discovered=true),
          ContextLoader__Core.makeLoadedFile("/b.md", "defgh", Global, ~discovered=true),
        ]

        let context = ContextLoader__Core.buildLoadedContext(files)
        t->expect(Array.length(context.files))->Expect.toBe(2)
        t->expect(Array.length(context.content))->Expect.toBe(2)
        t->expect(context.totalSize)->Expect.toBe(8)
      },
    )
  })
})
