import {describe, expect, test, vi} from "vitest"

import {
  createSatteriContentFilePlugin,
  registerContentFilePlugin,
} from "../src/markdown-content-file.mjs"
import {rehypeContentFile} from "../src/rehype-content-file.mjs"

describe("registerContentFilePlugin", () => {
  test("returns legacy when no processor is configured", () => {
    expect(registerContentFilePlugin(undefined, {projectRoot: "/project"})).toBe("legacy")
  })

  test("composes with Satteri without replacing existing options", () => {
    const existing = {name: "existing"}
    const processor = {name: "satteri", options: {hastPlugins: [existing], features: {gfm: true}}}

    expect(registerContentFilePlugin(processor, {projectRoot: "/project"})).toBe("satteri")
    expect(processor.options.features).toEqual({gfm: true})
    expect(processor.options.hastPlugins[0]).toBe(existing)
    expect(processor.options.hastPlugins[1]).toBeTypeOf("function")

    registerContentFilePlugin(processor, {projectRoot: "/project"})
    expect(processor.options.hastPlugins).toHaveLength(2)
  })

  test("composes with unified and preserves existing plugins", () => {
    const existing = () => undefined
    const processor = {name: "unified", options: {rehypePlugins: [existing]}}
    const options = {projectRoot: "/project"}

    expect(registerContentFilePlugin(processor, options)).toBe("unified")
    expect(processor.options.rehypePlugins).toEqual([existing, [rehypeContentFile, options]])
  })

  test("reports unknown processors without mutation", () => {
    const processor = {name: "custom", options: {}}

    expect(registerContentFilePlugin(processor, {projectRoot: "/project"})).toBe("unsupported")
    expect(processor).toEqual({name: "custom", options: {}})
  })
})

describe("createSatteriContentFilePlugin", () => {
  test("inserts one content marker before the first rendered element", () => {
    const insertBefore = vi.fn()
    const plugin = createSatteriContentFilePlugin({projectRoot: "/project"})
    const context = {
      fileURL: new URL("file:///project/src/pages/docs.md"),
      insertBefore,
    }
    const first = {type: "element", tagName: "h1"}

    plugin.element.visit(first, context)
    plugin.element.visit({type: "element", tagName: "p"}, context)

    expect(insertBefore).toHaveBeenCalledOnce()
    expect(insertBefore).toHaveBeenCalledWith(first, {
      type: "comment",
      value: " __frontman_content_file__:src/pages/docs.md ",
    })
  })

  test("does nothing when Satteri has no file URL", () => {
    const insertBefore = vi.fn()
    const plugin = createSatteriContentFilePlugin({projectRoot: "/project"})

    plugin.element.visit({type: "element", tagName: "p"}, {fileURL: undefined, insertBefore})

    expect(insertBefore).not.toHaveBeenCalled()
  })
})
