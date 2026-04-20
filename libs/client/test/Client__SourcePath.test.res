open Vitest

module SourcePath = Client__SourcePath

// ── extractFilename ────────────────────────────────────────────────────

describe("extractFilename", () => {
  test("extracts filename from Unix path", t => {
    t->expect(SourcePath.extractFilename("/src/components/Hero.vue"))->Expect.toBe("Hero.vue")
  })

  test("extracts filename from Windows path", t => {
    t->expect(SourcePath.extractFilename("C:\\Users\\dev\\src\\App.vue"))->Expect.toBe("App.vue")
  })

  test("handles bare filename (no directory)", t => {
    t->expect(SourcePath.extractFilename("App.vue"))->Expect.toBe("App.vue")
  })

  test("handles deeply nested paths", t => {
    t
    ->expect(SourcePath.extractFilename("/a/b/c/d/e/Component.vue"))
    ->Expect.toBe("Component.vue")
  })

  test("works with .astro files", t => {
    t
    ->expect(SourcePath.extractFilename("/src/layouts/Layout.astro"))
    ->Expect.toBe("Layout.astro")
  })

  test("works with mixed separators", t => {
    t
    ->expect(SourcePath.extractFilename("C:\\project/src\\views/Home.vue"))
    ->Expect.toBe("Home.vue")
  })

  test("handles repeated mixed separators", t => {
    t
    ->expect(SourcePath.extractFilename("C:\\Users\\dev/src\\components/Leaf.vue"))
    ->Expect.toBe("Leaf.vue")
  })
})

// ── isNodeModulesPath ──────────────────────────────────────────────────

describe("isNodeModulesPath", () => {
  test("detects node_modules paths", t => {
    t
    ->expect(SourcePath.isNodeModulesPath("/project/node_modules/vue/dist/vue.js"))
    ->Expect.toBe(true)
  })

  test("returns false for source paths", t => {
    t->expect(SourcePath.isNodeModulesPath("/project/src/App.vue"))->Expect.toBe(false)
  })

  test("detects nested node_modules (scoped packages)", t => {
    t
    ->expect(SourcePath.isNodeModulesPath("/project/node_modules/@vue/runtime-core/index.js"))
    ->Expect.toBe(true)
  })

  test("returns false for paths that contain 'modules' but not 'node_modules'", t => {
    t->expect(SourcePath.isNodeModulesPath("/src/modules/auth/Login.vue"))->Expect.toBe(false)
  })
})
