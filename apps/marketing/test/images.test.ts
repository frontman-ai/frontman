import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import sharp from 'sharp'
import { describe, expect, it } from 'vitest'

const { JSDOM } = createRequire(import.meta.url)('jsdom') as {
	JSDOM: new (html: string) => { window: { document: Document } }
}

const documentFor = (path: string) =>
	new JSDOM(readFileSync(resolve('dist', path, 'index.html'), 'utf8')).window.document

describe('production image delivery', () => {
	it.each([
		'autonomyai-wordpress-redesign-case-study',
		'wordpress-maintenance-checklist',
	])('reserves screenshot dimensions and preserves the originals in %s', async page => {
		const document = documentFor(`blog/${page}`)
		const images = document.querySelectorAll('.post-body img[src^="/blog/"]')
		expect(images.length).toBeGreaterThan(0)
		for (const image of images) {
			const path = image.getAttribute('src')!.slice(1)
			const original = readFileSync(resolve('public', path))
			const metadata = await sharp(original).metadata()
			expect(Number(image.getAttribute('width'))).toBe(metadata.width)
			expect(Number(image.getAttribute('height'))).toBe(metadata.height)
			expect(image.getAttribute('loading')).toBe('lazy')
			expect(readFileSync(resolve('dist', path))).toEqual(original)
		}
	})
})
