import {JSDOM} from "jsdom"
import {afterEach, describe, expect, test, vi} from "vitest"
import {agentInstructions, setupInstallAgent} from "./install-agent.mjs"

const pages = []

const createPage = clipboard => {
  const dom = new JSDOM(`<!doctype html><html><body>
    <section data-install-agent data-agent-framework="nextjs">
      <button class="framework-tab active" data-framework="nextjs" aria-pressed="true">Next.js</button>
      <button class="framework-tab" data-framework="astro" aria-pressed="false">Astro</button>
      <button class="framework-tab" data-framework="vite" aria-pressed="false">Vite</button>
      <button class="framework-tab" data-framework="wordpress" aria-pressed="false">WordPress</button>
      <button data-copy-agent-instructions>
        <svg data-copy-agent-icon></svg>
        <svg data-copy-agent-success-icon hidden></svg>
        <span data-copy-agent-label>Copy for agent</span>
      </button>
      <span data-copy-agent-status aria-live="polite"></span>
    </section>
  </body></html>`, {url: "https://frontman.sh/"})
  pages.push(dom)
  setupInstallAgent(dom.window.document, clipboard)
  return dom
}

const flushPromises = () => new Promise(resolve => setTimeout(resolve, 0))

const createDeferred = () => {
  let resolve
  const promise = new Promise(resolvePromise => {
    resolve = resolvePromise
  })
  return {promise, resolve}
}

afterEach(() => {
  vi.restoreAllMocks()
  for (const page of pages.splice(0)) page.window.close()
})

describe("coding-agent installation instructions", () => {
  test.each([
    ["nextjs", "npx @frontman-ai/nextjs install"],
    ["astro", "npx astro add @frontman-ai/astro"],
    ["vite", "npx @frontman-ai/vite install"],
  ])("provides safe %s instructions", (framework, command) => {
    const instructions = agentInstructions[framework]

    expect(instructions).toContain(command)
    expect(instructions).toContain("https://frontman.sh/docs/installation/")
    expect(instructions).toContain("git status")
    expect(instructions).toContain("actual local origin")
    expect(instructions).toContain("Do not enter credentials or complete OAuth")
    expect(instructions).not.toMatch(/localhost:\d+/)
  })

  test("warns the agent to review Next.js production exposure", () => {
    expect(agentInstructions.nextjs).toContain("production")
    expect(agentInstructions.nextjs).toContain("middleware or proxy")
  })

  test("keeps WordPress installation manual and staging-first", () => {
    expect(agentInstructions.wordpress).toContain("staging site")
    expect(agentInstructions.wordpress).toContain("backup")
    expect(agentInstructions.wordpress).toContain("wp-admin")
    expect(agentInstructions.wordpress).toContain("Confirm I have WordPress administrator access")
    expect(agentInstructions.wordpress).toContain("Do not ask for or enter credentials")
    expect(agentInstructions.wordpress).not.toContain("npx")
  })
})

describe("coding-agent instruction copy control", () => {
  test("copies instructions for the selected framework and shows success", async () => {
    const clipboard = {writeText: vi.fn().mockResolvedValue(undefined)}
    const page = createPage(clipboard)
    const {document} = page.window

    document.querySelector('[data-framework="astro"]').click()
    document.querySelector("[data-copy-agent-instructions]").click()
    await flushPromises()

    expect(clipboard.writeText).toHaveBeenCalledWith(agentInstructions.astro)
    expect(document.querySelector("[data-copy-agent-label]").textContent).toBe("Copied!")
    expect(document.querySelector("[data-copy-agent-instructions]").getAttribute("aria-label")).toBe(
      "Copy setup instructions for coding agent",
    )
    expect(document.querySelector("[data-copy-agent-status]").textContent).toBe(
      "Astro setup instructions copied to clipboard.",
    )
    expect(document.querySelector("[data-copy-agent-icon]").hasAttribute("hidden")).toBe(true)
    expect(document.querySelector("[data-copy-agent-success-icon]").hasAttribute("hidden")).toBe(false)
  })

  test("shows an accessible error when clipboard writing fails", async () => {
    const clipboard = {writeText: vi.fn().mockRejectedValue(new Error("denied"))}
    const page = createPage(clipboard)
    const {document} = page.window

    document.querySelector("[data-copy-agent-instructions]").click()
    await flushPromises()

    expect(document.querySelector("[data-copy-agent-label]").textContent).toBe("Copy failed")
    expect(document.querySelector("[data-copy-agent-status]").textContent).toBe(
      "Could not copy Next.js setup instructions. Try again.",
    )
    expect(document.querySelector("[data-copy-agent-icon]").hasAttribute("hidden")).toBe(false)
    expect(document.querySelector("[data-copy-agent-success-icon]").hasAttribute("hidden")).toBe(true)
  })

  test("resets copy feedback when framework selection changes", async () => {
    const clipboard = {writeText: vi.fn().mockResolvedValue(undefined)}
    const page = createPage(clipboard)
    const {document} = page.window

    document.querySelector("[data-copy-agent-instructions]").click()
    await flushPromises()
    document.querySelector('[data-framework="vite"]').click()

    expect(document.querySelector("[data-copy-agent-label]").textContent).toBe("Copy for agent")
    expect(document.querySelector("[data-copy-agent-status]").textContent).toBe("")
    expect(document.querySelector("[data-copy-agent-icon]").hasAttribute("hidden")).toBe(false)
    expect(document.querySelector("[data-copy-agent-success-icon]").hasAttribute("hidden")).toBe(true)
  })

  test("exposes the selected framework to assistive technology", () => {
    const page = createPage({writeText: vi.fn().mockResolvedValue(undefined)})
    const {document} = page.window

    document.querySelector('[data-framework="astro"]').click()

    expect(document.querySelector('[data-framework="nextjs"]').getAttribute("aria-pressed")).toBe("false")
    expect(document.querySelector('[data-framework="astro"]').getAttribute("aria-pressed")).toBe("true")
  })

  test("ignores stale clipboard feedback after framework selection changes", async () => {
    const deferred = createDeferred()
    const page = createPage({writeText: vi.fn().mockReturnValue(deferred.promise)})
    const {document} = page.window

    document.querySelector("[data-copy-agent-instructions]").click()
    document.querySelector('[data-framework="astro"]').click()
    deferred.resolve()
    await flushPromises()

    expect(document.querySelector("[data-copy-agent-label]").textContent).toBe("Copy for agent")
    expect(document.querySelector("[data-copy-agent-status]").textContent).toBe("")
    expect(document.querySelector("[data-copy-agent-icon]").hasAttribute("hidden")).toBe(false)
    expect(document.querySelector("[data-copy-agent-success-icon]").hasAttribute("hidden")).toBe(true)
  })
})
