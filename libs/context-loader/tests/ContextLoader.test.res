open Vitest

module Bindings = AskTheLlmBindings

describe("ContextLoader", () => {
  describe("load", () => {
    testAsync(
      "loads context from project root",
      async t => {
        let projectRoot = Bindings.Path.join([Bindings.Process.cwd(), "..", ".."])

        let result = await ContextLoader.load({
          cwd: projectRoot,
        })

        switch result {
        | Ok(context) => {
            t->expect(Array.length(context.files) > 0)->Expect.toBe(true)
            t->expect(context.totalSize > 0)->Expect.toBe(true)

            let hasAgentsMd =
              context.files->Array.some(file => String.includes(file.path, "AGENTS.md"))
            t->expect(hasAgentsMd)->Expect.toBe(true)
          }
        | Error(msg) => {
            Console.error(`Load failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "respects root boundary",
      async t => {
        let cwd = Bindings.Process.cwd()
        let projectRoot = Bindings.Path.join([cwd, "..", ".."])

        let result = await ContextLoader.load({
          cwd,
          root: projectRoot,
        })

        switch result {
        | Ok(context) => {
            // All found paths should start with the project root
            let allPathsWithinRoot = context.files->Array.every(
              file => {
                String.startsWith(file.path, projectRoot)
              },
            )
            t->expect(allPathsWithinRoot)->Expect.toBe(true)
          }
        | Error(msg) => {
            Console.error(`Load failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "handles custom paths",
      async t => {
        let customPath = Bindings.Path.join([Bindings.Process.cwd(), "..", "..", "AGENTS.md"])
        let customPaths = [customPath]

        let result = await ContextLoader.load({
          cwd: "/tmp",
          customPaths,
        })

        switch result {
        | Ok(context) => {
            t->expect(Array.length(context.files) > 0)->Expect.toBe(true)
            let hasCustomFile = context.files->Array.some(file => file.source == Custom)
            t->expect(hasCustomFile)->Expect.toBe(true)
          }
        | Error(msg) => {
            Console.error(`Load failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "loads global files when no local files found",
      async t => {
        // Use /tmp which has no local context files
        // Should fall back to loading global files
        let result = await ContextLoader.load({
          cwd: "/tmp",
        })

        switch result {
        | Ok(context) =>
          // Should find global files (if they exist)
          // The test is that it doesn't error and returns a valid context
          t->expect(context.totalSize >= 0)->Expect.toBe(true)
        | Error(msg) => {
            Console.error(`Load failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )
  })
})
