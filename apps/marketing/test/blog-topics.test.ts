import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { describe, expect, it } from 'vitest'

const { JSDOM } = createRequire(import.meta.url)('jsdom') as {
	JSDOM: new (html: string) => { window: { document: Document } }
}

const page = (path: string) => new JSDOM(readFileSync(`dist${path}index.html`, 'utf8')).window.document
const links = (element: ParentNode, selector: string) =>
	Array.from(element.querySelectorAll<HTMLAnchorElement>(selector), link => link.getAttribute('href')!)

describe('blog reading guides', () => {
	it('connects the listing, curated topic sections, and their articles in built HTML', () => {
		const index = page('/blog/')
		const directory = page('/blog/tags/')
		const topics = links(index, 'nav[aria-label="Blog topics"] a[href^="/blog/tags/#"]')
		expect(topics).toHaveLength(4)
		expect(directory.querySelector('a[href="/blog/tags/wordpress/"]')).not.toBeNull()

		for (const topicUrl of topics) {
			const topic = directory.getElementById(topicUrl.split('#')[1])
			expect(topic, topicUrl).not.toBeNull()
			const posts = links(topic!, 'ol a')
			expect(posts.length).toBeGreaterThanOrEqual(3)
			expect(new Set(posts).size).toBe(posts.length)
			for (const post of posts) {
				const related = page(post).querySelector('section[aria-labelledby="related-posts-heading"]')
				expect(related, post).not.toBeNull()
				expect(links(related!, 'ul a')).toEqual(posts.filter(path => path !== post).slice(0, 3))
				expect(links(related!, 'a[href*="#"]')).toEqual([topicUrl])
			}
		}
	})

	it('omits recommendations for posts outside the reading guides', () => {
		expect(page('/blog/frontman-launch/').getElementById('related-posts-heading')).toBeNull()
	})
})
