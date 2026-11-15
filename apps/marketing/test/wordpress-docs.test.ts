import { readFileSync, readdirSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const { JSDOM } = createRequire(import.meta.url)('jsdom') as {
	JSDOM: new (html: string) => { window: { document: Document } }
}

const read = (path: string) => readFileSync(resolve('dist', path), 'utf8')
const documentFor = (path: string) =>
	new JSDOM(read(`${path}/index.html`)).window.document

describe('WordPress documentation production output', () => {
	it('serves discoverable HTML and Markdown for the built guides', () => {
		const guides = readdirSync(resolve('dist/docs/wordpress'), { withFileTypes: true })
			.filter(entry => entry.isDirectory()).map(entry => entry.name)
		const search = JSON.parse(read('search-index.json')) as { url: string }[]
		const sitemap = readdirSync(resolve('dist'))
			.filter(file => /^sitemap.*\.xml$/.test(file)).map(read).join('\n')
		const index = documentFor('docs')
		expect(guides).toContain('choose-interface')
		for (const slug of guides) {
			const path = `/docs/wordpress/${slug}/`
			const document = documentFor(path.slice(1, -1))
			expect(document.querySelectorAll('h1')).toHaveLength(1)
			expect(document.querySelector('link[rel="canonical"]')?.getAttribute('href'))
				.toBe(`https://frontman.sh${path}`)
			expect(document.querySelector('meta[name="robots"]')?.getAttribute('content') ?? '')
				.not.toContain('noindex')
			const markdownPath = `${path.slice(0, -1)}.md`
			expect(document.querySelector('link[type="text/markdown"]')?.getAttribute('href')).toBe(markdownPath)
			expect(read(markdownPath.slice(1))).toContain(`# ${document.querySelector('h1')?.textContent?.trim()}`)
			expect(index.querySelector(`a[href="${path}"]`), path).toBeTruthy()
			expect(search.some(entry => entry.url === `https://frontman.sh${path}`), path).toBe(true)
			expect(sitemap).toContain(`https://frontman.sh${path}`)
		}
	})

	it('separates interface choice, MCP connections and shared editing workflows', () => {
		const document = documentFor('docs/wordpress/choose-interface')
		const groups = Array.from(document.querySelectorAll('nav.sidebar details'))
		const mcp = groups.find(group => group.querySelector(':scope > summary')?.textContent?.includes('MCP Connections'))
		const editing = groups.find(group => group.querySelector(':scope > summary')?.textContent?.includes('Editing Workflows'))
		expect(mcp?.querySelector('a[href="/docs/wordpress/multiple-sites/"]')).toBeTruthy()
		expect(editing?.querySelector('a[href="/docs/wordpress/posts-and-pages/"]')).toBeTruthy()
		expect(editing?.querySelector('a[href="/docs/wordpress/multiple-sites/"]')).toBeNull()
		const chooser = document.querySelector('.sl-markdown-content')
		expect(chooser?.querySelector('a[href="/docs/integrations/wordpress/#use-the-frontman-editor"]')).toBeTruthy()
		expect(chooser?.querySelector('a[href="/docs/wordpress/connect-agent/"]')).toBeTruthy()
	})

	it('does not imply that WooCommerce creates require the update/delete confirmation field', () => {
		const content = documentFor('docs/integrations/wordpress')
			.querySelector('.sl-markdown-content')?.textContent ?? ''
		expect(content).toContain('WooCommerce endpoint tools using PUT or DELETE, and metadata writes, require confirm=true')
		expect(content).toContain('WooCommerce POST create tools do not require that field')
	})
})
