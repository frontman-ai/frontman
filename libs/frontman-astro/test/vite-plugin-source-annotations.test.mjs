import {describe, expect, test} from "vitest"

import {annotationCaptureScript} from "../src/annotation-capture.mjs"
import {frontmanSourceAnnotationsPlugin} from "../src/vite-plugin-source-annotations.mjs"

async function transform(code, id = "/project/src/pages/index.astro") {
  return frontmanSourceAnnotationsPlugin().transform.handler(code, id)
}

describe("frontmanSourceAnnotationsPlugin", () => {
  test("annotates literal rendered elements with exact source locations", async () => {
    const result = await transform(`---
const props = {id: "title"}
---
<p>café</p>
<section>
  <h1 {...props}>Title</h1>
  <Widget />
  <my-card />
  <slot />
  <svg><path /></svg>
</section>
<script>console.log("ignored")</script>
<style>p { color: red }</style>
`)

    expect(result.code).toContain('<p data-frontman-source-file="/project/src/pages/index.astro" data-frontman-source-loc="4:1">')
    expect(result.code).toContain('<section data-frontman-source-file="/project/src/pages/index.astro" data-frontman-source-loc="5:1">')
    expect(result.code).toContain('<h1 data-frontman-source-file="/project/src/pages/index.astro" data-frontman-source-loc="6:3" {...props}>')
    expect(result.code).toContain('<my-card data-frontman-source-file="/project/src/pages/index.astro" data-frontman-source-loc="8:3" />')
    expect(result.code).toContain('<svg data-frontman-source-file="/project/src/pages/index.astro" data-frontman-source-loc="10:3"><path data-frontman-source-file="/project/src/pages/index.astro" data-frontman-source-loc="10:8" /></svg>')
    expect(result.code).toContain("<Widget />")
    expect(result.code).toContain("<slot />")
    expect(result.code).toContain('<script>console.log("ignored")</script>')
    expect(result.code).toContain("<style>p { color: red }</style>")
    expect(result.map).toBeTruthy()
    expect(result.map.sources).toEqual(["/project/src/pages/index.astro"])
  })

  test("converts compiler byte offsets after unicode to UTF-16 indexes", async () => {
    const result = await transform("<p>😀</p><strong>after</strong>")

    expect(result.code).toContain('</p><strong data-frontman-source-file="/project/src/pages/index.astro" data-frontman-source-loc="1:10">after</strong>')
  })

  test("skips subrequests and existing annotations", async () => {
    const code = '<main data-frontman-source-file="existing">Content</main>'

    expect(await transform(code)).toBeNull()
    expect(await transform("<main>Content</main>", "/project/src/pages/index.astro?astro&type=style&index=0")).toBeNull()
    expect(await transform("<main>Content</main>", "/project/src/pages/index.ts")).toBeNull()
  })

  test("capture script prefers Frontman attributes and preserves Astro fallback", () => {
    expect(annotationCaptureScript).toContain("[data-frontman-source-file], [data-astro-source-file]")
    expect(annotationCaptureScript).toContain("data-frontman-source-loc")
    expect(annotationCaptureScript).toContain("data-astro-source-loc")
  })
})
