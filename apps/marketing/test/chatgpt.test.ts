import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const { JSDOM } = createRequire(import.meta.url)('jsdom') as {
	JSDOM: new (html: string) => { window: { document: Document } }
}

const documentFor = (path: string) =>
	new JSDOM(readFileSync(resolve('dist', path, 'index.html'), 'utf8')).window.document

describe('ChatGPT landing page production HTML', () => {
	it('shows the existing editor video without claiming it records ChatGPT', () => {
		const document = documentFor('chatgpt')
		expect(document.querySelectorAll('h1')).toHaveLength(1)
		expect(document.querySelector('h1')?.textContent).toContain('From ChatGPT.')
		expect(document.querySelector('iframe')?.getAttribute('src')).toBe(
			'https://www.youtube-nocookie.com/embed/-4GD1GYwH8Y'
		)
		expect(document.querySelector('#demo figcaption')?.textContent).toContain('WordPress editor in action')
		expect(document.querySelector('[rel="canonical"]')?.getAttribute('href')).toBe('https://frontman.sh/chatgpt/')
	})

	it('uses the homepage fold structure and click-to-play preview on both pages', () => {
		for (const path of ['', 'chatgpt']) {
			const document = documentFor(path)
			const hero = document.querySelector('main > section')
			expect(hero?.classList.contains('wp-hero'), path).toBe(true)
			const grid = hero?.querySelector('.wp-hero__grid')
			expect(grid?.children).toHaveLength(2)
			expect(grid?.children[0].querySelector('h1')).not.toBeNull()
			expect(grid?.children[0].querySelector('.wp-lead')).not.toBeNull()
			expect(grid?.children[0].querySelector('.wp-actions .button')).not.toBeNull()
			expect(grid?.children[1].id).toBe('demo')

			const preview = new JSDOM(hero?.querySelector('iframe')?.getAttribute('srcdoc') ?? '').window.document
			expect(preview.querySelector('img')?.getAttribute('src')).toMatch(/^\/_astro\/home-demo-poster\..+\.webp$/)
			expect(preview.querySelector('img')?.getAttribute('srcset')).toContain('400w')
			expect(preview.querySelector('a')?.getAttribute('href')).toBe(
				'https://www.youtube-nocookie.com/embed/-4GD1GYwH8Y?autoplay=1&rel=0'
			)
		}
		const home = documentFor('')
		const chatgpt = documentFor('chatgpt')
		expect(home.querySelector('.wp-hero .button')?.getAttribute('href')).toBe(
			'https://wordpress.org/plugins/frontman-agentic-ai-editor/'
		)
		expect(home.querySelector('.wp-hero .button')?.getAttribute('data-ga-label')).toBe('wordpress_home_hero')
		expect(chatgpt.querySelector('.wp-hero .button')?.getAttribute('href')).toBe('#connect')
		expect(chatgpt.querySelector('.wp-hero a[href="#jobs"]')).not.toBeNull()
	})

	it('leads with customer jobs and keeps practical details in the FAQ', () => {
		const document = documentFor('chatgpt')
		expect(document.querySelectorAll('main > section')[1]?.id).toBe('jobs')
		expect(document.querySelector('#requirements')).toBeNull()
		expect(document.querySelector('main')?.textContent).not.toContain('Before you connect')
		expect(document.querySelectorAll('.jobs li')).toHaveLength(3)
		const faqText = document.querySelector('.faqs')?.textContent ?? ''
		expect(faqText).toContain('active Frontman subscription or eligible subscription trial')
		expect(faqText).toContain('cancellation requested or recorded does not grant access')
		expect(faqText).toContain('Free editor uses do not include')
		expect(faqText).toContain('do not need a separate AI provider key')
		expect(faqText).toContain('published pages immediately')
		expect(faqText).toContain('switch to General')
		expect(document.querySelector('#connect')?.textContent).toContain('same Frontman account')
		expect(document.querySelector('#connect a')?.getAttribute('href')).toBe('https://api.frontman.sh/wordpress/connect')
		for (const anchor of document.querySelectorAll<HTMLAnchorElement>('a[href^="#"]')) {
			expect(document.getElementById(anchor.hash.slice(1)), anchor.href).not.toBeNull()
		}
		for (const script of document.querySelectorAll('script[type="application/ld+json"]')) {
			expect(() => JSON.parse(script.textContent ?? '')).not.toThrow()
		}
		const faq = Array.from(document.querySelectorAll('script[type="application/ld+json"]'))
			.flatMap(script => JSON.parse(script.textContent ?? '{}')['@graph'] ?? [])
			.find(entry => entry['@type'] === 'FAQPage')
		expect(faq.mainEntity).toHaveLength(document.querySelectorAll('.faqs details').length)
	})

	it('is discoverable from the homepage, shared navigation and footer', () => {
		const document = documentFor('')
		expect(document.querySelector('.header a[href="/chatgpt/"]')).not.toBeNull()
		expect(document.querySelector('main a[href="/chatgpt/"]')).not.toBeNull()
		expect(document.querySelector('.footer a[href="/chatgpt/"]')).not.toBeNull()
	})

	it('corrects Frontman claims without changing the seven competitor rankings', () => {
		const document = documentFor('blog/best-wordpress-mcp-servers-and-plugins-2026')
		const text = document.querySelector('main')?.textContent ?? ''
		expect(text).toContain('Frontman capability update, November 11, 2026')
		expect(text).toContain('rankings remain as of July 31, 2026')
		expect(text).not.toContain('Frontman is not an MCP server')
		expect(text).not.toContain('non-MCP alternative')
		expect(document.querySelector('main a[href="/chatgpt/"]')).not.toBeNull()
		const faq = Array.from(document.querySelectorAll('script[type="application/ld+json"]'))
			.map(script => JSON.parse(script.textContent ?? '{}'))
			.find(entry => entry['@type'] === 'FAQPage')
		const accessAnswer = faq.mainEntity.find((entry: { name: string }) => entry.name === 'Is Frontman a WordPress MCP server?')
		expect(accessAnswer.acceptedAnswer.text).toContain('eligible subscription trial')
		const rankings = Array.from(document.querySelectorAll('h2'))
			.map(heading => heading.textContent?.trim() ?? '')
			.filter(heading => /^[1-7]\. /.test(heading))
		expect(rankings).toEqual([
			'1. Royal MCP: recommended starting point for a focused plugin',
			'2. WordPress MCP Adapter: best official foundation for developers',
			'3. Easy MCP AI: best for SEO, content, and analytics workflows',
			'4. StifLi Flex MCP: best when rollback is a selection requirement',
			'5. AI Engine: best when you also need a broad AI framework',
			'6. miniOrange Secure MCP Server: governance-focused, but early',
			'7. InstaWP MCP Server: best separate Node.js option for multiple sites'
		])
	})
})
