import { describe, expect, it } from 'vitest'
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import {
	countPostsByTag,
	isIndexableTagCount,
	parseFrontmatterTags
} from '../utils/tagIndexability.mjs'

describe('tag indexability', () => {
	it('keeps archives with fewer than three posts out of search', () => {
		expect(isIndexableTagCount(0)).toBe(false)
		expect(isIndexableTagCount(1)).toBe(false)
		expect(isIndexableTagCount(2)).toBe(false)
	})

	it('allows archives with at least three posts to be indexed', () => {
		expect(isIndexableTagCount(3)).toBe(true)
		expect(isIndexableTagCount(10)).toBe(true)
	})

	it('counts each post once for every assigned tag', () => {
		const counts = countPostsByTag([
			{ data: { tags: ['ai', 'tutorial'] } },
			{ data: { tags: ['ai'] } },
			{ data: { tags: ['ai', 'workflow'] } }
		])

		expect(counts.get('ai')).toBe(3)
		expect(counts.get('tutorial')).toBe(1)
		expect(counts.get('workflow')).toBe(1)
	})

	it('parses inline and block-list frontmatter tags identically', () => {
		expect(parseFrontmatterTags("---\ntags: ['ai', 'tutorial']\n---")).toEqual(['ai', 'tutorial'])
		expect(parseFrontmatterTags('---\ntags:\n  - ai\n  - tutorial\n---')).toEqual([
			'ai',
			'tutorial'
		])
	})

	it('applies the policy to rendered robots directives and sitemap entries', async () => {
		const [tagPage, sitemapConfig] = await Promise.all([
			readFile(resolve(import.meta.dirname, '../pages/blog/tags/[tag].astro'), 'utf8'),
			readFile(resolve(import.meta.dirname, '../../astro.config.mjs'), 'utf8')
		])

		expect(tagPage).toContain('noindex={!shouldIndex}')
		expect(sitemapConfig).toContain('!isIndexableTagCount(blogTagCounts.get(tagMatch[1]) ?? 0)')
		expect(sitemapConfig).toContain('return undefined')
	})
})
