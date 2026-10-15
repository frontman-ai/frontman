import { readFileSync } from 'node:fs'
/// @ts-expect-error The installed JSDOM dependency does not ship type declarations.
import { JSDOM } from 'jsdom'
import { afterEach, describe, expect, test, vi } from 'vitest'
import { agentInstructions, setupInstallAgent } from './install-agent.mjs'
import { createHomepageTools, registerHomepageTools } from './webmcp.mjs'

const pages: { window: { close: () => void } }[] = []
const names = ['search_frontman', 'ask_question', 'how_to_install', 'list_features', 'open_docs', 'jump_to_install']
const source = (path: string) => readFileSync(new URL(path, import.meta.url), 'utf8')
const createPage = (fixture: string, route: string) => {
  const page = new JSDOM(source(`./fixtures/webmcp-${fixture}.html`), { url: `https://frontman.sh${route}` })
  pages.push(page)
  return page.window.document
}

afterEach(() => {
  vi.unstubAllEnvs()
  pages.splice(0).forEach(page => page.window.close())
})

test('registration belongs to each supported page, not its framework hero', () => {
  for (const page of ['index', 'frameworks']) {
    expect(source(`../pages/${page}.astro`)).toContain("import { registerHomepageTools } from '../integrations/webmcp.mjs'")
  }
  expect(source('../components/blocks/hero/HomeCTA.astro')).not.toContain('registerHomepageTools')
})

describe.each([
  ['wordpress', '/'],
  ['frameworks', '/frameworks/'],
])('%s real page tool contracts', (fixture, route) => {
  test('registers and executes every read-only tool without support submission', async () => {
    const document = createPage(fixture, route)
    const original = document.documentElement.outerHTML
    const registerTool = vi.fn()
    Object.defineProperty(document, 'modelContext', { value: { registerTool } })
    document.defaultView!.fetch = vi.fn(async () => new Response(JSON.stringify([
      { title: 'WordPress setup', url: '/docs/integrations/wordpress/', content: 'WordPress 6.0+ and PHP 7.4+.' },
    ])))
    document.defaultView!.confirm = vi.fn(() => false)
    vi.stubEnv('FRONTMAN_API_ORIGIN', 'https://support.invalid')
    await registerHomepageTools(document)
    const tools = registerTool.mock.calls.map(([tool]) => tool)
    expect(tools.map(tool => tool.name)).toEqual(names)
    const options = { signal: new AbortController().signal }
    const readTools = tools.filter(tool => tool.annotations?.readOnlyHint)
    expect(readTools.map(tool => tool.name)).toEqual(['search_frontman', 'how_to_install', 'list_features'])
    const result: Record<string, any> = {}
    for (const tool of readTools) {
      result[tool.name] = await tool.execute(tool.name === 'search_frontman' ? { query: 'WordPress' } : {}, options)
    }
    expect(result.search_frontman).toEqual({ status: 'found', results: [
      { title: 'WordPress setup', url: '/docs/integrations/wordpress/', excerpt: 'WordPress 6.0+ and PHP 7.4+.' },
    ] })
    expect(tools[0].description).toMatch(/documentation only/)
    expect(result.list_features.highlights.length).toBeGreaterThan(0)
    expect(result.list_features.features.length).toBeGreaterThan(0)
    switch (fixture) {
      case 'wordpress':
        for (const text of ['Plugins', 'activate', 'GitHub or Google', 'WordPress 6.0+', 'PHP 7.4+', 'Administrator access', 'costs are separate', 'change immediately', 'no universal undo', '/docs/integrations/wordpress/']) {
          expect(result.how_to_install).toContain(text)
        }
        expect(result.how_to_install).not.toContain('npx ')
        expect(result.list_features.highlights[1].title).toContain('Elementor')
        expect(result.list_features.features).toContain('Work with WooCommerce data when WooCommerce is active')
        break
      case 'frameworks':
        for (const [framework, instructions] of Object.entries(agentInstructions)) {
          document.querySelector('[data-install-agent]')!.dataset.agentFramework = framework
          await expect(tools.find(tool => tool.name === 'how_to_install').execute({}, options)).resolves.toBe(instructions)
        }
        expect(result.list_features.features[0].title).toBe('Live DOM & component tree')
        break
    }
    await expect(tools.find(tool => tool.name === 'ask_question').execute({ question: 'Can you help with setup?' }, options))
      .resolves.toEqual({ status: 'cancelled', submitted: false })
    expect(document.defaultView!.fetch).toHaveBeenCalledExactlyOnceWith('/search-index.json', { ...options, credentials: 'omit', referrerPolicy: 'no-referrer' })
    document.querySelector('[data-install-agent]')?.setAttribute('data-agent-framework', 'nextjs')
    expect(document.documentElement.outerHTML).toBe(original)
  })

  test('no API leaves normal installation, links and disclosure content intact', async () => {
    const document = createPage(fixture, route)
    const original = document.documentElement.outerHTML
    await registerHomepageTools(document)
    expect(document.documentElement.outerHTML).toBe(original)
    expect(document.querySelector('#install')).not.toBeNull()
    expect(document.querySelector('a[href="/pricing/"]')).not.toBeNull()
    expect(document.defaultView!.location.pathname).toBe(route)
  })

  test('cancellation prevents every tool from doing work', async () => {
    const document = createPage(fixture, route)
    const registerTool = vi.fn()
    Object.defineProperty(document, 'modelContext', { value: { registerTool } })
    document.defaultView!.fetch = vi.fn()
    document.defaultView!.confirm = vi.fn()
    await registerHomepageTools(document)
    const controller = new AbortController()
    const reason = new Error('Cancelled')
    controller.abort(reason)
    for (const [tool] of registerTool.mock.calls) {
      const input = tool.name === 'search_frontman' ? { query: 'setup' } : tool.name === 'ask_question' ? { question: 'Help?' } : {}
      await expect(tool.execute(input, { signal: controller.signal })).rejects.toBe(reason)
    }
    expect(document.defaultView!.fetch).not.toHaveBeenCalled()
    expect(document.defaultView!.confirm).not.toHaveBeenCalled()
  })
})

test('WordPress features include real capabilities rather than framework-only selectors', async () => {
  const document = createPage('wordpress', '/')
  const tool = createHomepageTools(document).find(tool => tool.name === 'list_features')!
  const result = await tool.execute({}, { signal: new AbortController().signal })
  expect(result.highlights[1].title).toContain('Elementor')
  expect(result.features).toContain('Work with WooCommerce data when WooCommerce is active')
})

test('setup links retain local contrast/underline styles and copy status names the button', () => {
  const wordpress = createPage('wordpress', '/')
  expect(wordpress.querySelectorAll('.wp-install__details a')).toHaveLength(4)
  expect([...wordpress.querySelectorAll('.wp-install__details a')].every(a => a.classList.contains('wp-setup-link'))).toBe(true)
  const frameworks = createPage('frameworks', '/frameworks/')
  expect(frameworks.querySelectorAll('.install-subtitle a')).toHaveLength(2)
  expect([...frameworks.querySelectorAll('.install-subtitle a')].every(a => a.classList.contains('install-guide-link'))).toBe(true)
  const install = source('../components/blocks/install/InstallSteps.astro')
  expect(install).toContain('@apply text-primary-700 underline underline-offset-4')
  expect(source('./install-agent.mjs')).not.toContain('button.setAttribute("aria-label"')
  expect(source('../pages/frameworks.astro').match(/class="underline underline-offset-4" href="https:\/\/(www.npmjs.com|github.com)/g)).toHaveLength(4)
})

test('copy names follow initial, failure, retry success and selected-stack labels', async () => {
  const document = createPage('frameworks', '/frameworks/')
  const clipboard = { writeText: vi.fn().mockRejectedValueOnce(new Error('Clipboard denied')).mockResolvedValue(undefined) }
  setupInstallAgent(document, clipboard as unknown as Clipboard)
  const button = document.querySelector('[data-copy-agent-instructions]')
  const label = document.querySelector('[data-copy-agent-label]')
  const expectName = (name: string) => {
    expect(button.getAttribute('aria-label')).toBeNull()
    expect(button.getAttribute('aria-labelledby')).toBeNull()
    expect(label.textContent).toBe(name)
    expect(button.textContent.trim()).toBe(name)
  }
  expectName('Copy for agent')
  button.click()
  await vi.waitFor(() => expectName('Copy failed'))
  button.click()
  await vi.waitFor(() => expectName('Copied!'))
  expect(clipboard.writeText).toHaveBeenNthCalledWith(1, agentInstructions.nextjs)
  expect(clipboard.writeText).toHaveBeenNthCalledWith(2, agentInstructions.nextjs)
  document.querySelector('[data-framework="astro"]').click()
  expectName('Copy for agent')
  expect(document.querySelector('[data-install-agent]').dataset.agentFramework).toBe('astro')
  button.click()
  await vi.waitFor(() => expectName('Copied!'))
  expect(clipboard.writeText).toHaveBeenLastCalledWith(agentInstructions.astro)
  expect(document.querySelector('[data-copy-agent-status]').textContent).toBe('Astro setup instructions copied to clipboard.')
})

test('unsupported routes do not advertise tools requiring homepage content', async () => {
  const document = createPage('wordpress', '/pricing/')
  const registerTool = vi.fn()
  Object.defineProperty(document, 'modelContext', { value: { registerTool } })
  await registerHomepageTools(document)
  expect(registerTool).not.toHaveBeenCalled()
})

test('failed registration cancels previously registered tools and surfaces its error', async () => {
  const document = createPage('wordpress', '/')
  const error = new Error('Registration refused')
  const registerTool = vi.fn().mockResolvedValueOnce(undefined).mockRejectedValueOnce(error)
  Object.defineProperty(document, 'modelContext', { value: { registerTool } })
  await expect(registerHomepageTools(document)).rejects.toBe(error)
  expect(registerTool.mock.calls[0][1].signal.aborted).toBe(true)
})
