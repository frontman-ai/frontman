import { preview } from 'astro'
import { stat } from 'node:fs/promises'
import { resolve } from 'node:path'
import { chromium, type Browser, type Page } from 'playwright'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'

let server: Awaited<ReturnType<typeof preview>>
let browser: Browser
let origin: string

beforeAll(async () => {
	server = await preview({ root: new URL('../../', import.meta.url).pathname, server: { host: '127.0.0.1', port: 0 }, logLevel: 'silent' })
	origin = `http://127.0.0.1:${server.port}`
	browser = await chromium.launch({
		executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
	})
}, 60_000)

afterAll(async () => {
	await browser?.close()
	await server?.stop()
})

async function contrast(page: Page, selector: string) {
	return page.locator(selector).evaluateAll(elements => {
		const luminance = (color: string) => {
			const values = color.match(/[\d.]+/g)!.slice(0, 3).map(Number).map(value => {
				const channel = value / 255
				return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
			})
			return values[0] * 0.2126 + values[1] * 0.7152 + values[2] * 0.0722
		}
		return elements.map(element => {
			let background: Element | null = element
			while (background && getComputedStyle(background).backgroundColor === 'rgba(0, 0, 0, 0)') {
				background = background.parentElement
			}
			if (!background) throw new Error('No opaque background for contrast measurement')
			const foreground = luminance(getComputedStyle(element).color)
			const backdrop = luminance(getComputedStyle(background).backgroundColor)
			return (Math.max(foreground, backdrop) + 0.05) / (Math.min(foreground, backdrop) + 0.05)
		})
	})
}

describe.each([390, 1440])('production contrast at %ipx', width => {
	it('keeps article tags readable and text links identifiable without color', async () => {
		const page = await browser.newPage({ viewport: { width, height: 900 } })
		try {
			await page.goto(`${origin}/blog/best-frontend-coding-agent/`)
			for (const selector of ['.post-header__tags .badge', '.author-link', '.post-body p a']) {
				const ratios = await contrast(page, selector)
				expect(ratios.length, selector).toBeGreaterThan(0)
				for (const ratio of ratios) expect(ratio, selector).toBeGreaterThanOrEqual(4.5)
			}
			for (const selector of ['.author-link', '.post-body p a']) {
				const decorations = await page.locator(selector).evaluateAll(elements =>
					elements.map(element => getComputedStyle(element).textDecorationLine))
				for (const decoration of decorations) expect(decoration, selector).toContain('underline')
			}
			await page.locator('.post-header__tags .badge').first().hover()
			for (const ratio of await contrast(page, '.post-header__tags .badge')) {
				expect(ratio).toBeGreaterThanOrEqual(4.5)
			}
		} finally {
			await page.close()
		}
	})

	it('keeps docs metadata readable in both color themes', async () => {
		const page = await browser.newPage({ viewport: { width, height: 900 } })
		try {
			await page.goto(`${origin}/docs/integrations/nextjs/`)
			for (const theme of ['light', 'dark']) {
				await page.locator('html').evaluate((element, theme) => element.setAttribute('data-theme', theme), theme)
				const ratios = await contrast(page, 'footer .meta a')
				expect(ratios.length).toBeGreaterThan(0)
				for (const ratio of ratios) expect(ratio, theme).toBeGreaterThanOrEqual(4.5)
			}
		} finally {
			await page.close()
		}
	})

	it('loads smaller responsive homepage images at normal and high pixel density', async () => {
		for (const deviceScaleFactor of [1, 2]) {
			const page = await browser.newPage({ viewport: { width, height: 900 }, deviceScaleFactor })
			try {
				await page.goto(`${origin}/`)
				const poster = page.frameLocator('.wp-hero iframe').locator('img')
				const comparisons = page.locator('.wp-comparison img')
				for (const [image, source] of [
					[poster, 'images/home-demo-poster.webp'],
					[comparisons.nth(0), 'blog/autonomyai-homepage-before.webp'],
					[comparisons.nth(1), 'blog/autonomyai-homepage-after.webp'],
				] as const) {
					await image.scrollIntoViewIfNeeded()
					await image.evaluate(async element => {
						await (element as HTMLImageElement).decode()
					})
					const selected = await image.evaluate(element => {
						const image = element as HTMLImageElement
						const candidate = image.srcset.split(',').find(candidate =>
							new URL(candidate.trim().split(/\s+/)[0], document.baseURI).href === image.currentSrc)
						if (!candidate) throw new Error('Browser did not select a srcset candidate')
						return {
							url: image.currentSrc,
							width: Number(candidate.trim().split(/\s+/)[1].slice(0, -1)),
							slot: image.getBoundingClientRect().width,
						}
					})
					expect(selected.width).toBeGreaterThanOrEqual(selected.slot * deviceScaleFactor)
					const response = await page.request.get(selected.url)
					expect(response.status()).toBe(200)
					const bytes = (await response.body()).byteLength
					expect(bytes).toBeLessThan((await stat(resolve('public', source))).size)
				}
			} finally {
				await page.close()
			}
		}
	})
})
