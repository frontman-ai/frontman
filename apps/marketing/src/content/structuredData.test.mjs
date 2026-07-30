import { describe, expect, it } from 'vitest'
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { createWebPageSchema, getWebPageId } from '../utils/structuredData.mjs'

describe('WebPage structured data', () => {
	it('identifies each non-home page by its canonical URL and metadata', () => {
		expect(
			createWebPageSchema({
				url: 'https://frontman.sh/features/',
				title: 'Frontman Features',
				description: 'Explore Frontman capabilities.'
			})
		).toEqual({
			'@type': 'WebPage',
			'@id': 'https://frontman.sh/features/#webpage',
			url: 'https://frontman.sh/features/',
			name: 'Frontman Features',
			description: 'Explore Frontman capabilities.'
		})
	})

	it('limits homepage speakable selectors to the homepage', () => {
		const homepage = createWebPageSchema({
			url: 'https://frontman.sh/',
			title: 'Frontman',
			description: 'AI website editor.'
		})
		const docs = createWebPageSchema({
			url: 'https://frontman.sh/docs/',
			title: 'Frontman Docs',
			description: 'Frontman documentation.'
		})

		expect(homepage.speakable).toBeDefined()
		expect(docs.speakable).toBeUndefined()
	})

	it('shares one WebPage identifier with article and release schemas', async () => {
		const [postLayout, releaseLayout] = await Promise.all([
			readFile(resolve(import.meta.dirname, '../layouts/PostLayout.astro'), 'utf8'),
			readFile(resolve(import.meta.dirname, '../layouts/ReleasesLayout.astro'), 'utf8')
		])

		expect(getWebPageId('https://frontman.sh/blog/example/')).toBe(
			'https://frontman.sh/blog/example/#webpage'
		)
		expect(postLayout).toContain('getWebPageId(Astro.url.href)')
		expect(releaseLayout).toContain('getWebPageId(Astro.url.href)')
	})

	it('uses page-specific WebPage schema in both marketing and docs heads', async () => {
		const [marketingHead, docsHead] = await Promise.all([
			readFile(
				resolve(import.meta.dirname, '../components/blocks/head/partials/StructuredData.astro'),
				'utf8'
			),
			readFile(resolve(import.meta.dirname, '../components/starlight/Head.astro'), 'utf8')
		])

		expect(marketingHead).toContain('createWebPageSchema({ url: pageUrl, title, description })')
		expect(docsHead).toContain(
			'createWebPageSchema({ url: pageUrl, title: pageTitle, description: pageDescription })'
		)
	})
})
