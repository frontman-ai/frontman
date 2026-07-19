import {Buffer} from "node:buffer"

import {describe, expect, test, vi} from "vitest"

import {frontmanPropsInjectionPlugin} from "../src/vite-plugin-props-injection.mjs"

const runtimeId = "/project/node_modules/astro/dist/runtime/server/render/component.js"

function runtimeSource({parameters = "result, displayName, Component, props, slots", markHTML = true} = {}) {
  return `
${markHTML ? "function markHTMLString(value) { return value }" : ""}
function renderComponent(${parameters}) {
  if (Component && typeof Component.then === "function") {
    return Component.then(resolved => renderComponent(result, displayName, resolved, props, slots))
  }
  return {
    render(destination) {
      destination.write(markHTMLString("<h1>Rendered</h1>"))
    }
  }
}
export {renderComponent}
`
}

async function loadTransformed(code) {
  const transformed = frontmanPropsInjectionPlugin().transform(code, runtimeId, {ssr: true})
  expect(transformed).not.toBeNull()
  const url = `data:text/javascript;base64,${Buffer.from(transformed.code).toString("base64")}`
  return {transformed, module: await import(url)}
}

function decodeMarker(output) {
  const markers = [...output.matchAll(/__frontman_props__:([A-Za-z0-9+/=]+)/g)]
  expect(markers).toHaveLength(1)
  return JSON.parse(Buffer.from(markers[0][1], "base64").toString("utf8"))
}

describe("frontmanPropsInjectionPlugin", () => {
  test("fails closed and warns once for unknown Astro runtime shapes", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined)
    const plugin = frontmanPropsInjectionPlugin()

    expect(plugin.transform(runtimeSource({parameters: "a, b, c, d"}), runtimeId, {ssr: true})).toBeNull()
    expect(plugin.transform(runtimeSource({markHTML: false}), runtimeId, {ssr: true})).toBeNull()
    expect(warn).toHaveBeenCalledOnce()
    warn.mockRestore()
  })

  test("emits one marker for async recursion and provides a source map", async () => {
    const {transformed, module} = await loadTransformed(runtimeSource())
    const destination = {value: "", write(value) { this.value += value }}
    const Component = Promise.resolve({moduleId: "C:\\project\\src\\Greeting.astro"})

    const instance = await module.renderComponent({}, "Greeting", Component, {name: "Astro"}, {})
    instance.render(destination)

    const marker = decodeMarker(destination.value)
    expect(marker.moduleId).toBe("C:/project/src/Greeting.astro")
    expect(marker.props).toEqual({name: "Astro"})
    expect(transformed.map).toBeTruthy()
    expect(transformed.map.sources).toEqual([runtimeId])
  })

  test("redacts secrets and bounds nested prop values", async () => {
    const {module} = await loadTransformed(runtimeSource())
    const destination = {value: "", write(value) { this.value += value }}
    const props = {
      apiKey: "never expose this",
      privateKey: "private material",
      credentials: "login material",
      author: "Ada",
      profile: {name: "Ada", authorization: "Bearer secret"},
      items: Array.from({length: 80}, (_, index) => index),
      deep: {one: {two: {three: {four: {five: "hidden"}}}}},
      long: "x".repeat(5000),
      custom: new Date("2026-01-01T00:00:00Z"),
    }

    const instance = module.renderComponent({}, "Greeting", {moduleId: "/project/Greeting.astro"}, props, {})
    instance.render(destination)

    const marker = decodeMarker(destination.value)
    expect(marker.props.apiKey).toBe("[REDACTED]")
    expect(marker.props.privateKey).toBe("[REDACTED]")
    expect(marker.props.credentials).toBe("[REDACTED]")
    expect(marker.props.author).toBe("Ada")
    expect(marker.props.profile.authorization).toBe("[REDACTED]")
    expect(marker.props.items.at(-1)).toBe("[Truncated 30 items]")
    expect(marker.props.deep.one.two.three).toBe("[Max depth]")
    expect(marker.props.long).toMatch(/\[Truncated\]$/)
    expect(marker.props.custom).toBe("[Object]")
  })

  test("distinguishes repeated references from cycles", async () => {
    const {module} = await loadTransformed(runtimeSource())
    const destination = {value: "", write(value) { this.value += value }}
    const shared = {name: "Ada"}
    const circular = {}
    circular.self = circular

    const instance = module.renderComponent(
      {}, "Greeting", {moduleId: "/project/Greeting.astro"},
      {primary: shared, secondary: shared, circular}, {},
    )
    instance.render(destination)

    expect(decodeMarker(destination.value).props).toEqual({
      primary: {name: "Ada"},
      secondary: {name: "Ada"},
      circular: {self: "[Circular]"},
    })
  })

  test("does not change rendering when prop access throws", async () => {
    const {module} = await loadTransformed(runtimeSource())
    const destination = {value: "", write(value) { this.value += value }}
    const props = {}
    Object.defineProperty(props, "unsafe", {enumerable: true, get() { throw new Error("unsafe getter") }})

    const instance = module.renderComponent({}, "Greeting", {moduleId: "/project/Greeting.astro"}, props, {})
    instance.render(destination)

    expect(destination.value).toBe("<h1>Rendered</h1>")
  })

  test("redacts secret getters without reading them", async () => {
    const {module} = await loadTransformed(runtimeSource())
    const destination = {value: "", write(value) { this.value += value }}
    const props = {name: "Astro"}
    Object.defineProperty(props, "privateKey", {
      enumerable: true,
      get() { throw new Error("secret getter must not execute") },
    })

    const instance = module.renderComponent({}, "Greeting", {moduleId: "/project/Greeting.astro"}, props, {})
    instance.render(destination)

    expect(decodeMarker(destination.value).props).toEqual({
      name: "Astro",
      privateKey: "[REDACTED]",
    })
  })

  test("does not read properties beyond the collection limit", async () => {
    const {module} = await loadTransformed(runtimeSource())
    const destination = {value: "", write(value) { this.value += value }}
    const props = Object.fromEntries(Array.from({length: 50}, (_, index) => [`value${index}`, index]))
    Object.defineProperty(props, "overflow", {
      enumerable: true,
      get() { throw new Error("overflow getter must not execute") },
    })

    const instance = module.renderComponent({}, "Greeting", {moduleId: "/project/Greeting.astro"}, props, {})
    instance.render(destination)

    const captured = decodeMarker(destination.value).props
    expect(captured.value49).toBe(49)
    expect(captured.__truncated__).toBe(1)
    expect(captured).not.toHaveProperty("overflow")
  })

  test("ignores non-SSR and unrelated transforms", () => {
    const plugin = frontmanPropsInjectionPlugin()
    expect(plugin.transform(runtimeSource(), runtimeId, {ssr: false})).toBeNull()
    expect(plugin.transform(runtimeSource(), "/project/src/component.js", {ssr: true})).toBeNull()
  })
})
