import { readFileSync, readdirSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const origin = 'https://frontman.sh'
const readDist = (path: string) => readFileSync(resolve('dist', path), 'utf8')
const pageAt = (pathname: string) => readDist(`.${pathname}index.html`).split('</head>', 1)[0]
const sitemapUrls = () => readdirSync('dist')
	.filter((file) => /^sitemap-.*-\d+\.xml$/.test(file))
	.flatMap((file) => Array.from(readDist(file).matchAll(/<loc>(.*?)<\/loc>/g), ([, url]) => url))

describe('production SEO metadata', () => {
	it('emits distinct titles and descriptions and one self-canonical per sitemap URL', () => {
		const urls = sitemapUrls()
		expect(urls).not.toHaveLength(0)
		expect(new Set(urls).size).toBe(urls.length)

		const titles = new Map<string, string>()
		const descriptions = new Map<string, string>()
		for (const url of urls) {
			const path = new URL(url).pathname
			const head = pageAt(path)
			expect(url, path).toBe(`${origin}${path}`)
			expect(Array.from(head.matchAll(/<link rel="canonical" href="([^"]+)"/g), ([, href]) => href), path)
				.toEqual([url])
			expect(head, path).not.toMatch(/<meta name="robots" content="[^"]*\bnoindex\b/)
			for (const [pattern, seen] of [
				[/<title>([^<]+)<\/title>/, titles],
				[/<meta name="description" content="([^"]+)"/, descriptions],
			] as const) {
				const value = head.match(pattern)?.[1].trim().replace(/\s+/g, ' ').toLowerCase() ?? ''
				expect(value, path).not.toBe('')
				expect(seen.get(value), `Duplicate metadata at ${path}: ${value}`).toBeUndefined()
				seen.set(value, path)
			}
		}
	})

	it('keeps configured permanent aliases out of the sitemap and points them at real pages', () => {
		const sitemap = new Set(sitemapUrls())
		const redirects = readDist('_redirects').split('\n').map((line) => line.trim())
			.filter((line) => line && !line.startsWith('#'))
		expect(redirects).not.toHaveLength(0)
		for (const rule of redirects) {
			const [source, target, status] = rule.split(/\s+/)
			expect(status, rule).toBe('301')
			expect(sitemap.has(new URL(source, origin).href), rule).toBe(false)
			expect(sitemap.has(new URL(`${source.replace(/\/$/, '')}/`, origin).href), rule).toBe(false)
			expect(sitemap.has(new URL(target, origin).href), rule).toBe(true)
		}
	})
})
