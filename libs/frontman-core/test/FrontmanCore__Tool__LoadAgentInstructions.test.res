open Vitest

module Tool = FrontmanCore__Tool__LoadAgentInstructions
module Bindings = FrontmanBindings
module Protocol = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let fixturesPath = Bindings.Path.join([
  Bindings.Process.cwd(),
  "test",
  "fixtures",
  "load-agent-instructions",
])

// ============================================
// Test Helpers
// ============================================

let fixture = name => Bindings.Path.join([fixturesPath, name])

let makeCtx = (sourceRoot: string): Protocol.serverExecutionContext => {
  projectRoot: sourceRoot,
  sourceRoot,
}

/** Filter results to only files within a specific directory (tool walks up to /) */
let filterWithinDir = (files: array<Tool.instructionFile>, dir: string) =>
  files->Array.filter(f => String.startsWith(f.fullPath, dir))

/** Execute tool and filter results to fixture directory */
let executeAndFilter = async (dir, ~startPath=?) => {
  let ctx = makeCtx(dir)
  let result = await Tool.execute(ctx, {startPath: ?startPath})
  result->Result.map(files => filterWithinDir(files, dir))
}

/** Assert result is Ok and run assertions on the filtered files */
let assertOk = (t, result, assertions) => {
  switch result {
  | Ok(files) => assertions(files)
  | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
  }
}

/** Check if any file path contains the given substring */
let hasPathContaining = (files: array<Tool.instructionFile>, substring) =>
  files->Array.some(f => String.includes(f.fullPath, substring))

/** Check if a file path contains one string but not another */
let hasPathWith = (files: array<Tool.instructionFile>, ~containing, ~excluding) =>
  files->Array.some(f =>
    String.includes(f.fullPath, containing) && !String.includes(f.fullPath, excluding)
  )

describe("LoadAgentInstructions", () => {
  // ===========================================
  // Priority Logic
  // ===========================================
  describe("priority logic", () => {
    testAsync(
      "Agents.md wins over CLAUDE.md at same level",
      async t => {
        let result = await executeAndFilter(fixture("priority-agents-over-claude"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            let file = files->Array.getUnsafe(0)
            t->expect(hasPathContaining([file], "Agents.md"))->Expect.toBe(true)
            t->expect(hasPathContaining([file], "CLAUDE"))->Expect.toBe(false)
          },
        )
      },
    )

    testAsync(
      "any Agents variant skips all CLAUDE variants at same level",
      async t => {
        let result = await executeAndFilter(fixture("priority-agents-over-claude"))

        t->assertOk(
          result,
          files => {
            t->expect(hasPathContaining(files, "CLAUDE"))->Expect.toBe(false)
          },
        )
      },
    )

    testAsync(
      "hidden .claude/Agents.md has priority over CLAUDE.md",
      async t => {
        let result = await executeAndFilter(fixture("hidden-agents-priority"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            t->expect(hasPathContaining(files, ".claude/Agents.md"))->Expect.toBe(true)
          },
        )
      },
    )

    testAsync(
      "CLAUDE.md returned when no Agents exist",
      async t => {
        let result = await executeAndFilter(fixture("claude-only"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            let file = files->Array.getUnsafe(0)
            t->expect(hasPathContaining([file], "CLAUDE.md"))->Expect.toBe(true)
            t->expect(file.content)->Expect.toBe("claude content")
          },
        )
      },
    )
  })

  // ===========================================
  // Multiple Files Same Level
  // ===========================================
  describe("multiple files at same level", () => {
    testAsync(
      "multiple Agents variants coexist",
      async t => {
        let result = await executeAndFilter(fixture("multiple-agents-variants"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(3)
          },
        )
      },
    )

    testAsync(
      "all three Agents variants are returned",
      async t => {
        let result = await executeAndFilter(fixture("multiple-agents-variants"))

        t->assertOk(
          result,
          files => {
            t
            ->expect(hasPathWith(files, ~containing="Agents.md", ~excluding=".claude"))
            ->Expect.toBe(true)
            t->expect(hasPathContaining(files, ".claude/Agents.md"))->Expect.toBe(true)
            t->expect(hasPathContaining(files, "Agents.local.md"))->Expect.toBe(true)
          },
        )
      },
    )

    testAsync(
      "all three CLAUDE variants returned when no Agents",
      async t => {
        let result = await executeAndFilter(fixture("multiple-claude-variants"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(3)
            t
            ->expect(hasPathWith(files, ~containing="CLAUDE.md", ~excluding=".claude"))
            ->Expect.toBe(true)
            t->expect(hasPathContaining(files, ".claude/CLAUDE.md"))->Expect.toBe(true)
            t->expect(hasPathContaining(files, "CLAUDE.local.md"))->Expect.toBe(true)
          },
        )
      },
    )
  })

  // ===========================================
  // Upward Traversal
  // ===========================================
  describe("upward traversal", () => {
    testAsync(
      "finds file in parent when none in startPath",
      async t => {
        let parentDir = fixture("parent-only")
        let childDir = Bindings.Path.join([parentDir, "child"])
        let ctx = makeCtx(childDir)
        let result = await Tool.execute(ctx, {})

        t->assertOk(
          result->Result.map(files => filterWithinDir(files, parentDir)),
          files => {
            t->expect(hasPathContaining(files, "parent-only/CLAUDE.md"))->Expect.toBe(true)
          },
        )
      },
    )

    testAsync(
      "collects from multiple levels",
      async t => {
        let multiLevelDir = fixture("multi-level")
        let deepDir = Bindings.Path.join([multiLevelDir, "child", "deep"])
        let ctx = makeCtx(deepDir)
        let result = await Tool.execute(ctx, {})

        t->assertOk(
          result->Result.map(files => filterWithinDir(files, multiLevelDir)),
          files => {
            t->expect(Array.length(files))->Expect.toBe(3)
          },
        )
      },
    )

    testAsync(
      "result ordering: startPath first, then parents",
      async t => {
        let multiLevelDir = fixture("multi-level")
        let deepDir = Bindings.Path.join([multiLevelDir, "child", "deep"])
        let ctx = makeCtx(deepDir)
        let result = await Tool.execute(ctx, {})

        t->assertOk(
          result->Result.map(files => filterWithinDir(files, multiLevelDir)),
          files => {
            let first = files->Array.getUnsafe(0)
            let second = files->Array.getUnsafe(1)
            let third = files->Array.getUnsafe(2)

            t->expect(hasPathContaining([first], "deep/Agents.md"))->Expect.toBe(true)
            t->expect(hasPathContaining([second], "child/CLAUDE.md"))->Expect.toBe(true)
            t
            ->expect(hasPathWith([third], ~containing="multi-level/Agents.md", ~excluding="child"))
            ->Expect.toBe(true)
          },
        )
      },
    )

    testAsync(
      "each level is independent (Agents at child, CLAUDE at parent)",
      async t => {
        let deepDir = Bindings.Path.join([fixture("multi-level"), "child", "deep"])
        let ctx = makeCtx(deepDir)
        let result = await Tool.execute(ctx, {})

        t->assertOk(
          result,
          files => {
            t->expect(hasPathContaining(files, "deep/Agents.md"))->Expect.toBe(true)
            t->expect(hasPathContaining(files, "child/CLAUDE.md"))->Expect.toBe(true)
          },
        )
      },
    )
  })

  // ===========================================
  // startPath Parameter
  // ===========================================
  describe("startPath parameter", () => {
    testAsync(
      "default startPath uses sourceRoot",
      async t => {
        let result = await executeAndFilter(fixture("multi-level"))

        t->assertOk(
          result,
          files => {
            t
            ->expect(hasPathWith(files, ~containing="multi-level/Agents.md", ~excluding="child"))
            ->Expect.toBe(true)
          },
        )
      },
    )

    testAsync(
      "relative startPath is resolved from sourceRoot",
      async t => {
        let result = await executeAndFilter(fixture("multi-level"), ~startPath="child/deep")

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(3)
            let first = files->Array.getUnsafe(0)
            t->expect(hasPathContaining([first], "deep/Agents.md"))->Expect.toBe(true)
          },
        )
      },
    )
  })

  // ===========================================
  // Edge Cases
  // ===========================================
  describe("edge cases", () => {
    testAsync(
      "returns empty array when no instruction files in fixture",
      async t => {
        let emptyDir = fixture("empty")
        let subdir = Bindings.Path.join([emptyDir, "subdir"])
        let ctx = makeCtx(subdir)
        let result = await Tool.execute(ctx, {})

        t->assertOk(
          result->Result.map(files => filterWithinDir(files, emptyDir)),
          files => {
            t->expect(Array.length(files))->Expect.toBe(0)
          },
        )
      },
    )

    testAsync(
      ".claude as file (not directory) is handled gracefully",
      async t => {
        let result = await executeAndFilter(fixture("dotclaude-as-file"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            t->expect(hasPathContaining(files, "CLAUDE.md"))->Expect.toBe(true)
          },
        )
      },
    )

    testAsync(
      ".claude directory exists but is empty",
      async t => {
        let result = await executeAndFilter(fixture("dotclaude-empty"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            t->expect(hasPathContaining(files, "CLAUDE.md"))->Expect.toBe(true)
          },
        )
      },
    )
  })

  // ===========================================
  // Content Loading
  // ===========================================
  describe("content loading", () => {
    testAsync(
      "content is correctly loaded",
      async t => {
        let result = await executeAndFilter(fixture("content-check"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            t->expect((files->Array.getUnsafe(0)).content)->Expect.toBe("Hello World")
          },
        )
      },
    )

    testAsync(
      "empty file returns empty content",
      async t => {
        let result = await executeAndFilter(fixture("empty-file"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            t->expect((files->Array.getUnsafe(0)).content)->Expect.toBe("")
          },
        )
      },
    )

    testAsync(
      "unicode content is preserved",
      async t => {
        let result = await executeAndFilter(fixture("unicode-content"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            t->expect((files->Array.getUnsafe(0)).content)->Expect.toBe(`Hello 🌍 世界 café`)
          },
        )
      },
    )
  })

  // ===========================================
  // Case-Insensitive Discovery (Issue #114)
  // ===========================================
  describe("case-insensitive discovery", () => {
    testAsync(
      "discovers lowercase agents.md file",
      async t => {
        let result = await executeAndFilter(fixture("case-insensitive-agents"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            let file = files->Array.getUnsafe(0)
            t->expect(hasPathContaining([file], "agents.md"))->Expect.toBe(true)
            t->expect(file.content)->Expect.toBe("lowercase agents content")
          },
        )
      },
    )

    testAsync(
      "discovers lowercase claude.md file",
      async t => {
        let result = await executeAndFilter(fixture("case-insensitive-claude"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            let file = files->Array.getUnsafe(0)
            t->expect(hasPathContaining([file], "claude.md"))->Expect.toBe(true)
            t->expect(file.content)->Expect.toBe("lowercase claude content")
          },
        )
      },
    )

    testAsync(
      "discovers files with uppercase extensions (Agents.MD)",
      async t => {
        let result = await executeAndFilter(fixture("case-variations"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.Int.toBeGreaterThan(0)
            t->expect(hasPathContaining(files, "Agents.MD"))->Expect.toBe(true)
          },
        )
      },
    )

    testAsync(
      "discovers hidden .claude/agents.md with lowercase",
      async t => {
        let result = await executeAndFilter(fixture("case-variations"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.Int.toBeGreaterThan(0)
            t->expect(hasPathContaining(files, ".claude/agents.md"))->Expect.toBe(true)
          },
        )
      },
    )
  })

  // ===========================================
  // Root Detection / Termination (Issue #432)
  // ===========================================
  describe("root detection and termination", () => {
    testAsync(
      "walkUpDirectories terminates at filesystem root",
      async t => {
        // walkUpDirectories should terminate when Path.dirname(current) == current
        // On Unix: path.dirname("/") === "/" → stops
        // On Windows: path.dirname("C:\\") === "C:\\" → stops
        let results = await Tool.walkUpDirectories("/", [])
        t->expect(Array.length(results))->Expect.toBe(0)
      },
    )

    testAsync(
      "walkUpDirectories terminates from a shallow path near root",
      async t => {
        // Starting from /tmp (2 levels from root) should not hang
        let results = await Tool.walkUpDirectories("/tmp", [])
        // Just verify it terminates and returns an array — we don't care about specific files
        t->expect(Array.length(results))->Expect.Int.toBeGreaterThanOrEqual(0)
      },
    )

    testAsync(
      "execute terminates from deep nested fixture path",
      async t => {
        // This exercises the full walk-up from a deep path to root
        let deepPath = Bindings.Path.join([
          fixture("deeply-nested"),
          "a",
          "b",
          "c",
          "d",
          "e",
          "f",
          "g",
          "h",
          "i",
          "j",
        ])
        let ctx = makeCtx(deepPath)
        let result = await Tool.execute(ctx, {})
        // Verify it terminates and returns Ok
        switch result {
        | Ok(_) => t->expect(true)->Expect.toBe(true)
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )
  })

  // ===========================================
  // Path Handling
  // ===========================================
  describe("path handling", () => {
    testAsync(
      "fullPath is absolute",
      async t => {
        let result = await executeAndFilter(fixture("content-check"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            t
            ->expect(String.startsWith((files->Array.getUnsafe(0)).fullPath, "/"))
            ->Expect.toBe(true)
          },
        )
      },
    )

    testAsync(
      "paths with spaces are handled correctly",
      async t => {
        let result = await executeAndFilter(fixture("spaces in path"))

        t->assertOk(
          result,
          files => {
            t->expect(Array.length(files))->Expect.toBe(1)
            let file = files->Array.getUnsafe(0)
            t->expect(hasPathContaining([file], "spaces in path"))->Expect.toBe(true)
            t->expect(file.content)->Expect.toBe("spaces test")
          },
        )
      },
    )

    testAsync(
      "deeply nested directories (10+ levels) are traversed",
      async t => {
        let deepPath = Bindings.Path.join([
          fixture("deeply-nested"),
          "a",
          "b",
          "c",
          "d",
          "e",
          "f",
          "g",
          "h",
          "i",
          "j",
        ])
        let ctx = makeCtx(deepPath)
        let result = await Tool.execute(ctx, {})

        t->assertOk(
          result,
          files => {
            let hasDeepFile =
              files->Array.some(
                f => hasPathContaining([f], "deeply-nested") && hasPathContaining([f], "Agents.md"),
              )
            t->expect(hasDeepFile)->Expect.toBe(true)
          },
        )
      },
    )
  })
})
