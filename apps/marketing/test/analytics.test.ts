import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
/// @ts-expect-error The installed JSDOM dependency does not ship type declarations.
import { JSDOM } from 'jsdom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { createConsentScript } from '../src/integrations/consent.mjs'
import { agentInstructions, setupInstallAgent } from '../src/integrations/install-agent.mjs'

const pages: { window: { close: () => void } }[] = []

const createPage = async (path: string) => {
  const dom = new JSDOM(readFileSync(resolve('dist', `.${path}index.html`), 'utf8'), {
    url: `https://frontman.sh${path}`,
    runScripts: 'outside-only',
    pretendToBeVisual: true,
  })
  pages.push(dom)
  const { window } = dom
  const scripts = [...window.document.querySelectorAll('script:not([src])')]
    .filter(script => script.textContent.includes('window.trackEvent ='))
  expect(scripts, path).toHaveLength(1)
  window.eval(createConsentScript())
  window.eval(scripts[0].textContent)
  await new Promise(resolve => window.document.addEventListener('DOMContentLoaded', resolve, { once: true }))
  return window
}

const events = (window: any) => window.dataLayer.map((args: ArrayLike<unknown>) => Array.from(args))
  .filter((args: unknown[]) => args[0] === 'event')

afterEach(() => {
  pages.splice(0).forEach(page => page.window.close())
})

describe('consented analytics in production HTML', () => {
  it.each(['/', '/blog/getting-started/', '/frameworks/', '/docs/installation/'])(
    'loads one analytics runtime only after consent on %s', async path => {
      const window = await createPage(path)
      const scripts = () => window.document.querySelectorAll('script[src*="googletagmanager.com"]')
      expect(scripts()).toHaveLength(0)
      window.trackEvent('before_consent')
      window.astroConsent.set({ analytics: false })
      expect(scripts()).toHaveLength(0)
      window.astroConsent.set({ analytics: true })
      expect(scripts()).toHaveLength(1)
      expect(events(window)).toEqual([])
      window.trackEvent('accepted')
      window.astroConsent.set({ analytics: false })
      window.trackEvent('after_revocation')
      expect(events(window).map((args: unknown[]) => args[1])).toEqual(['accepted'])
    },
  )

  it('records successful agent copies, not clicks or failures, through the consent gate', async () => {
    const window = await createPage('/frameworks/')
    const clipboard = { writeText: vi.fn().mockRejectedValueOnce(new Error('Clipboard denied')).mockResolvedValue(undefined) }
    setupInstallAgent(window.document, clipboard as unknown as Clipboard)
    const button = window.document.querySelector('[data-copy-agent-instructions]')
    const status = window.document.querySelector('[data-copy-agent-status]')
    expect(button.hasAttribute('data-ga-event')).toBe(false)
    window.astroConsent.set({ analytics: true })

    button.click()
    await vi.waitFor(() => expect(status.textContent).toContain('Could not copy'))
    expect(events(window)).toEqual([])
    button.click()
    expect(events(window)).toEqual([])
    await vi.waitFor(() => expect(events(window)).toHaveLength(1))
    expect(events(window)[0]).toEqual(['event', 'copy_agent_install_instructions', {
      event_category: 'engagement',
      event_label: 'install_step',
      destination: 'nextjs',
      page_path: '/frameworks/',
    }])

    window.astroConsent.set({ analytics: false })
    window.document.querySelector('[data-framework="astro"]').click()
    button.click()
    await vi.waitFor(() => expect(status.textContent).toContain('Astro setup instructions copied'))
    expect(clipboard.writeText).toHaveBeenLastCalledWith(agentInstructions.astro)
    expect(events(window)).toHaveLength(1)
    window.astroConsent.set({ analytics: true })
    expect(events(window)).toHaveLength(1)
  })
})
