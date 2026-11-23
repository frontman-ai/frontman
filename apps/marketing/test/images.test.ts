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

const imageFor = (document: Document, selector: string) => {
	const image = document.querySelector<HTMLImageElement>(selector)
	expect(image, selector).not.toBeNull()
	return image!
}

const checkResponsiveOutput = async (
	image: HTMLImageElement,
	sourcePath: string,
	widths: number[],
	sizes: string
) => {
	const original = readFileSync(resolve('public', sourcePath))
	const source = await sharp(original).metadata()
	const width = Number(image.getAttribute('width'))
	const height = Number(image.getAttribute('height'))
	expect(width).toBeGreaterThan(0)
	expect(Math.abs(height - width * source.height! / source.width!)).toBeLessThanOrEqual(1)
	expect(image.getAttribute('sizes')).toBe(sizes)
	const candidates = image.getAttribute('srcset')!.split(',').map(candidate => {
		const [url, descriptor] = candidate.trim().split(/\s+/)
		expect(url).toMatch(/^\/_astro\/.+\.webp$/)
		expect(descriptor).toMatch(/^\d+w$/)
		return { url, width: Number(descriptor.slice(0, -1)) }
	})
	expect(candidates.map(candidate => candidate.width)).toEqual(widths)
	expect(candidates.some(candidate => candidate.url === image.getAttribute('src'))).toBe(true)
	for (const candidate of candidates) {
		const output = readFileSync(resolve('dist', candidate.url.slice(1)))
		const metadata = await sharp(output).metadata()
		expect(metadata.format).toBe('webp')
		expect(metadata.width).toBe(candidate.width)
		expect(Math.abs(metadata.height! - candidate.width * source.height! / source.width!)).toBeLessThanOrEqual(1)
		expect(metadata.width).toBeLessThanOrEqual(source.width!)
		await sharp(output).stats()
		if (candidate.width === widths[0]) {
			expect(output.byteLength).toBeLessThan(original.byteLength / 2)
		}
	}
}

describe('production image delivery', () => {
	it.each(['', 'chatgpt'])('serves an eager responsive click-to-play poster at /%s', async path => {
		const document = documentFor(path)
		const iframe = document.querySelector<HTMLIFrameElement>('.wp-hero iframe')!
		expect(iframe.getAttribute('loading')).toBe('eager')
		const preview = new JSDOM(iframe.getAttribute('srcdoc')!).window.document
		const image = imageFor(preview, 'img')
		expect(image.alt).toBe('Frontman conversation alongside the live storefront preview')
		expect(image.getAttribute('width')).toBe('1868')
		expect(image.getAttribute('height')).toBe('1080')
		expect(image.getAttribute('loading')).toBe('eager')
		expect(image.getAttribute('fetchpriority')).toBe('high')
		// The preview is an iframe: 100vw refers to the image slot, not the outer page.
		await checkResponsiveOutput(image, 'images/home-demo-poster.webp', [400, 640, 960, 1280, 1868], '100vw')
		expect(preview.querySelector('a')?.getAttribute('href')).toBe(
			'https://www.youtube-nocookie.com/embed/-4GD1GYwH8Y?autoplay=1&rel=0'
		)
	})

	it('serves lazy responsive homepage comparison images without changing their content', async () => {
		const document = documentFor('')
		const images = document.querySelectorAll<HTMLImageElement>('.wp-comparison img')
		expect(images).toHaveLength(2)
		const comparisons = [
			{ file: 'before', alt: 'AutonomyAI’s previous dark homepage, headed The OS for Building in Production' },
			{ file: 'after', alt: 'AutonomyAI’s redesigned light homepage, headed Better Delivery, Built with Autonomy' }
		]
		for (const [index, comparison] of comparisons.entries()) {
			const image = images[index]
			expect(image.alt).toBe(comparison.alt)
			expect(image.getAttribute('loading')).toBe('lazy')
			expect(image.getAttribute('decoding')).toBe('async')
			await checkResponsiveOutput(
				image,
				`blog/autonomyai-homepage-${comparison.file}.webp`,
				[400, 640, 960, 1280, 1600],
				'(max-width: 767px) calc(100vw - 48px), (max-width: 1200px) calc((100vw - 72px) / 2), 564px'
			)
		}
	})

	it.each([
		{
			page: 'autonomyai-wordpress-redesign-case-study',
			images: [
				{ file: 'autonomyai-homepage-before.webp', alt: 'AutonomyAI homepage before the Frontman redesign' },
				{ file: 'autonomyai-homepage-after.webp', alt: 'AutonomyAI homepage after the Frontman redesign' }
			]
		},
		{
			page: 'wordpress-maintenance-checklist',
			images: [
				{ file: 'wordpress-maintenance-playground-change-desktop.png', alt: 'Logged-out WordPress Playground page with the title Maintenance Loop Verified on desktop' },
				{ file: 'wordpress-maintenance-playground-change-mobile.png', alt: 'Logged-out WordPress Playground page with the title Maintenance Loop Verified at a 390 by 844 mobile viewport' },
				{ file: 'wordpress-maintenance-playground-restored.png', alt: 'Restored WordPress Playground page with the original Sample Page title' }
			]
		}
	])('reserves real intrinsic screenshot dimensions in $page', async ({ page, images }) => {
		const document = documentFor(`blog/${page}`)
		for (const { file, alt } of images) {
			const image = imageFor(document, `main img[src="/blog/${file}"]`)
			const original = readFileSync(resolve('public/blog', file))
			const metadata = await sharp(original).metadata()
			expect(image.alt).toBe(alt)
			expect(Number(image.getAttribute('width'))).toBe(metadata.width)
			expect(Number(image.getAttribute('height'))).toBe(metadata.height)
			expect(image.getAttribute('loading')).toBe('lazy')
			expect(image.getAttribute('decoding')).toBe('async')
			expect(readFileSync(resolve('dist/blog', file))).toEqual(original)
		}
	})
})
