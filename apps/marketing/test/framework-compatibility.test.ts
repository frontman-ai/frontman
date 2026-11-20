import { readFileSync, readdirSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { expect, it } from 'vitest'

const { JSDOM } = createRequire(import.meta.url)('jsdom') as {
	JSDOM: new (html: string) => { window: { document: Document } }
}
const read = (path: string) => readFileSync(resolve('dist', path), 'utf8')
const documentFor = (path: string) => new JSDOM(read(`${path}index.html`)).window.document
const text = (element: Element) => element.textContent?.trim()
const route = '/tools/framework-compatibility/'
const source = '/docs/reference/compatibility/'

it('renders and exports the published compatibility summary and makes the tool discoverable', () => {
	const reference = documentFor(source.slice(1))
	const table = reference.querySelector('#compatibility-summary')?.parentElement?.nextElementSibling
	expect(table?.tagName).toBe('TABLE')
	const rows = Array.from(table!.querySelectorAll('tbody tr'))
	const expected = rows.map(row => {
		const [platform, integration, status, versions, access] = Array.from(row.querySelectorAll('td'), text)
		return { platform, integration, status, versions, access }
	})
	expect(expected.map(row => row.platform)).toEqual(['Next.js', 'Astro', 'Vite-based apps', 'WordPress'])

	const page = documentFor(route.slice(1))
	const cards = Array.from(page.querySelectorAll('[aria-labelledby="choose-stack"] details'))
	expect(cards.map(card => Array.from(card.querySelectorAll('summary, dd'), text)))
		.toEqual(expected.map(row => Object.values(row)))

	const download = page.querySelector('a[download="frontman-compatibility.json"]')
	const href = download?.getAttribute('href') ?? ''
	const prefix = 'data:application/json;charset=utf-8,'
	expect(href).toMatch(/^data:application\/json;charset=utf-8,/)
	expect(JSON.parse(decodeURIComponent(href.slice(prefix.length))))
		.toEqual({ source: `https://frontman.sh${source}`, integrations: expected })
	expect(page.querySelector(`a[href="${source}"]`)).toBeTruthy()

	const directory = documentFor('tools/')
	for (const [document, path] of [[page, route], [directory, '/tools/']] as const) {
		expect(document.querySelector('meta[name="robots"]')?.getAttribute('content') ?? '').not.toContain('noindex')
		expect(document.querySelector('link[rel="canonical"]')?.getAttribute('href')).toBe(`https://frontman.sh${path}`)
	}
	expect(directory.querySelector(`a[href="${route}"]`)).toBeTruthy()
	expect(reference.querySelector(`a[href="${route}"]`)).toBeTruthy()
	const sitemaps = readdirSync(resolve('dist')).filter(file => /^sitemap.*\.xml$/.test(file))
	const sitemap = sitemaps.map(read).join('\n')
	expect(sitemap).toContain(`<loc>https://frontman.sh${route}</loc>`)
	expect(sitemap).toContain('<loc>https://frontman.sh/tools/</loc>')
})
