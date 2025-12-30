open Vitest

module Bindings = FrontmanBindings

let fixturesPath = Bindings.Path.join([Bindings.Process.cwd(), "tests", "fixtures"])

describe("ContextLoader", () => {
  describe("load", () => {
    testAsync(
      "loads context from simple project root",
      async t => {
        let projectRoot = Bindings.Path.join([fixturesPath, "simple-project"])

        let result = await ContextLoader.load({
          cwd: projectRoot,
          globalConfigDir: "/nonexistent",
        })

        switch result {
        | Ok(context) => {
            t->expect(Array.length(context.files))->Expect.toBe(1)
            t->expect(context.totalSize > 0)->Expect.toBe(true)

            let hasAgentsMd =
              context.files->Array.some(file => String.includes(file.path, "AGENTS.md"))
            t->expect(hasAgentsMd)->Expect.toBe(true)
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "respects root boundary with nested structure",
      async t => {
        let projectRoot = Bindings.Path.join([fixturesPath, "nested-project"])
        let deepCwd = Bindings.Path.join([projectRoot, "sub", "deep"])

        let result = await ContextLoader.load({
          cwd: deepCwd,
          root: projectRoot,
          globalConfigDir: "/nonexistent",
        })

        switch result {
        | Ok(context) => {
            // Should find AGENTS.md at root
            t->expect(Array.length(context.files))->Expect.toBe(1)

            // Should find the root AGENTS.md
            let hasRootAgents =
              context.files->Array.some(file => String.includes(file.path, "nested-project/AGENTS.md"))
            t->expect(hasRootAgents)->Expect.toBe(true)
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "respects file priority (AGENTS > CLAUDE > CONTEXT)",
      async t => {
        let projectRoot = Bindings.Path.join([fixturesPath, "priority-test"])

        let result = await ContextLoader.load({
          cwd: projectRoot,
          globalConfigDir: "/nonexistent",
        })

        switch result {
        | Ok(context) => {
            // Should only load AGENTS.md (highest priority)
            t->expect(Array.length(context.files))->Expect.toBe(1)

            let loadedFile = Array.getUnsafe(context.files, 0)
            t->expect(String.includes(loadedFile.path, "AGENTS.md"))->Expect.toBe(true)
            t
            ->expect(String.includes(loadedFile.content, "AGENTS.md has highest priority"))
            ->Expect.toBe(true)
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "loads all files from root to CWD in multi-level structure with correct ordering",
      async t => {
        let projectRoot = Bindings.Path.join([fixturesPath, "multi-level"])
        let deepCwd = Bindings.Path.join([projectRoot, "level1", "level2"])

        let result = await ContextLoader.load({
          cwd: deepCwd,
          root: projectRoot,
          globalConfigDir: "/nonexistent",
        })

        switch result {
        | Ok(context) => {
            // Should load all 3 AGENTS.md files from root, level1, and level2
            // One file per directory, ordered root → CWD
            t->expect(Array.length(context.files))->Expect.toBe(3)

            // Verify ordering: root → level1 → level2
            let rootFile = Array.getUnsafe(context.files, 0)
            let level1File = Array.getUnsafe(context.files, 1)
            let level2File = Array.getUnsafe(context.files, 2)

            t
            ->expect(
              String.includes(rootFile.path, "multi-level/AGENTS.md") &&
              !String.includes(rootFile.path, "level1"),
            )
            ->Expect.toBe(true)
            t
            ->expect(
              String.includes(level1File.path, "level1/AGENTS.md") &&
              !String.includes(level1File.path, "level2"),
            )
            ->Expect.toBe(true)
            t->expect(String.includes(level2File.path, "level2/AGENTS.md"))->Expect.toBe(true)
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "loads one file per directory with mixed filenames",
      async t => {
        // Fixture structure: /AGENTS.md, /src/AGENTS.md, /src/backend/CLAUDE.md
        // Should load all 3 files (one per directory)
        let projectRoot = Bindings.Path.join([fixturesPath, "codex-behavior"])
        let deepCwd = Bindings.Path.join([projectRoot, "src", "backend"])

        let result = await ContextLoader.load({
          cwd: deepCwd,
          root: projectRoot,
          globalConfigDir: "/nonexistent",
        })

        switch result {
        | Ok(context) => {
            // Should load all 3 files: root AGENTS.md, src AGENTS.md, backend CLAUDE.md
            t->expect(Array.length(context.files))->Expect.toBe(3)

            // Verify we have the right files
            let rootFile = Array.getUnsafe(context.files, 0)
            let srcFile = Array.getUnsafe(context.files, 1)
            let backendFile = Array.getUnsafe(context.files, 2)

            // Root should be AGENTS.md
            t
            ->expect(
              String.includes(rootFile.path, "codex-behavior/AGENTS.md") &&
              !String.includes(rootFile.path, "src"),
            )
            ->Expect.toBe(true)

            // Src should be AGENTS.md
            t
            ->expect(
              String.includes(srcFile.path, "src/AGENTS.md") &&
              !String.includes(srcFile.path, "backend"),
            )
            ->Expect.toBe(true)

            // Backend should be CLAUDE.md (not AGENTS.md)
            t->expect(String.includes(backendFile.path, "backend/CLAUDE.md"))->Expect.toBe(true)
            t->expect(String.includes(backendFile.content, "Backend Level CLAUDE.md"))->Expect.toBe(
              true,
            )
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "filters out empty files",
      async t => {
        let projectRoot = Bindings.Path.join([fixturesPath, "empty-files"])
        let subDir = Bindings.Path.join([projectRoot, "sub"])

        let result = await ContextLoader.load({
          cwd: subDir,
          root: projectRoot,
          globalConfigDir: "/nonexistent",
        })

        switch result {
        | Ok(context) => {
            // sub/AGENTS.md is empty, root AGENTS.md has content
            // Should filter out empty and keep only root AGENTS.md
            t->expect(Array.length(context.files))->Expect.toBe(1)

            let loadedFile = Array.getUnsafe(context.files, 0)
            t->expect(String.includes(loadedFile.path, "empty-files/AGENTS.md"))->Expect.toBe(true)
            t->expect(!String.includes(loadedFile.path, "sub"))->Expect.toBe(true)
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "handles custom paths",
      async t => {
        let customPath = Bindings.Path.join([fixturesPath, "simple-project", "AGENTS.md"])
        let customPaths = [customPath]
        let noContextDir = Bindings.Path.join([fixturesPath, "no-context"])

        let result = await ContextLoader.load({
          cwd: noContextDir,
          root: noContextDir,
          customPaths,
          globalConfigDir: "/nonexistent",
        })

        switch result {
        | Ok(context) => {
            t->expect(Array.length(context.files))->Expect.toBe(1)
            let hasCustomFile = context.files->Array.some(file => file.source == Custom)
            t->expect(hasCustomFile)->Expect.toBe(true)
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "always includes global files even when local files exist",
      async t => {
        let projectRoot = Bindings.Path.join([fixturesPath, "simple-project"])
        let globalConfigDir = Bindings.Path.join([fixturesPath, "global-mock"])

        let result = await ContextLoader.load({
          cwd: projectRoot,
          globalConfigDir,
        })

        switch result {
        | Ok(context) => {
            // Should find both global and local files
            t->expect(Array.length(context.files) >= 2)->Expect.toBe(true)
            let hasGlobalFile = context.files->Array.some(file => file.source == Global)
            let hasLocalFile = context.files->Array.some(file => file.source == Local)
            t->expect(hasGlobalFile)->Expect.toBe(true)
            t->expect(hasLocalFile)->Expect.toBe(true)

            // Global file should come FIRST
            let firstFile = Array.getUnsafe(context.files, 0)
            t->expect(firstFile.source == Global)->Expect.toBe(true)
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )
  })
})
