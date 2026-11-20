import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

const { JSDOM } = createRequire(import.meta.url)('jsdom') as {
	JSDOM: { fragment(html: string): DocumentFragment }
}

const readPage = (path: string) =>
	JSDOM.fragment(readFileSync(join('dist', path, 'index.html'), 'utf8'))

describe('crawlable production HTML', () => {
	it.each(['/', '/pricing/', '/frameworks/', '/vs/openclaw/', '/blog/', '/docs/'])(
		'prerenders a single nonempty page heading at %s',
		(path) => {
			const headings = readPage(path).querySelectorAll('h1')
			expect(headings).toHaveLength(1)
			expect(headings[0]?.textContent?.trim()).toBeTruthy()
		},
	)

	it('prerenders role links and a separate setup link under Use cases', () => {
		const nav = readPage('/frameworks/').querySelector('nav[aria-label="Main navigation"]')
		const disclosure = Array.from(nav?.querySelectorAll('button') ?? [])
			.find(button => button.textContent?.trim() === 'Use cases')
		const submenuId = disclosure?.getAttribute('aria-controls')
		expect(submenuId).toBeTruthy()
		const submenu = nav?.querySelector(`#${submenuId}`)
		expect(submenu?.querySelector('a[href="/marketing-teams/"]')).toBeTruthy()
		expect(submenu?.querySelector('a[href="/use-cases/designers/"]')).toBeTruthy()
		expect(submenu?.querySelector('a[href="/use-cases/frontend-developers/"]')).toBeTruthy()
		const setupLink = submenu?.querySelector('a[href="/frameworks/"]')
		expect(setupLink?.textContent?.trim()).toBe('Next.js, Astro, and Vite setup')
		expect(setupLink?.getAttribute('aria-current')).toBe('page')
	})
})
