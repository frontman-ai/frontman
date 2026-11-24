import { preview } from 'astro'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { onRequest } from '../functions/_middleware'

let server: Awaited<ReturnType<typeof preview>>
let origin: string

beforeAll(async () => {
	server = await preview({ root: new URL('../', import.meta.url).pathname, trailingSlash: 'ignore', server: { host: '127.0.0.1', port: 0 }, logLevel: 'silent' })
	origin = `http://127.0.0.1:${server.port}`
}, 60_000)

afterAll(async () => {
	await server?.stop()
})

const fetchAsset = (request: Request) => {
	const url = new URL(request.url)
	const headers = new Headers(request.headers)
	headers.set('Accept', '*/*')
	return fetch(new URL(url.pathname + url.search, origin), {
		method: request.method, headers, redirect: 'manual',
	})
}

const requestPage = (path: string, method = 'GET', headers?: HeadersInit) => {
	const request = new Request(`https://frontman.sh${path}`, { method, headers })
	return onRequest({ request, next: () => fetchAsset(request), env: { ASSETS: { fetch: fetchAsset } } })
}

const readDist = (path: string) => readFileSync(join('dist', path), 'utf8')
const docPaths = readdirSync('dist/docs', { recursive: true })
	.filter((file) => String(file).endsWith('.md'))
	.map((file) => `/docs/${String(file).replace(/\.md$/, '')}/`)
const alternatePaths = ['/', '/pricing/', '/frameworks/', '/changelog/', '/.well-known/api-catalog', '/api/llms.txt', '/docs/', ...docPaths]
const markdownAt = (path: string) => path === '/' ? '/index.md' : `${path.replace(/\/$/, '')}.md`
const canonicalLink = (path: string) => `<https://frontman.sh${path}>; rel="canonical"`

describe('Markdown routing through real prerendered assets', () => {
	it('restores canonical HTTP links on every published direct and negotiated alternate', async () => {
		expect(docPaths.length).toBeGreaterThan(0)
		for (const path of alternatePaths) {
			const markdownPath = markdownAt(path)
			const asset = await fetchAsset(new Request(`https://frontman.sh${markdownPath}`))
			expect(asset.status, markdownPath).toBe(200)
			expect(asset.headers.get('Link'), markdownPath).toBeNull()
			const body = await asset.text()
			for (const method of ['GET', 'HEAD']) {
				for (const target of [markdownPath, path]) {
					const response = await requestPage(`${target}?utm_source=test`, method, { Accept: 'text/markdown' })
					expect(response.status, `${method} ${target}`).toBe(200)
					expect(response.headers.get('Content-Type'), target).toContain('text/markdown')
					expect(response.headers.get('Link'), target).toContain(canonicalLink(path))
					expect(response.headers.get('Link')?.match(/rel="canonical"/g), target).toHaveLength(1)
					expect(response.headers.get('Link'), target).not.toContain('utm_source')
					if (target === path) expect(response.headers.get('Link'), target).toContain('</llms.txt>; rel="alternate"')
					expect(await response.text(), `${method} ${target}`).toBe(method === 'HEAD' ? '' : body)
				}
			}
		}
	}, 60_000)

	it('keeps auth.md self-canonical and gives bot-negotiated Markdown the HTML canonical', async () => {
		for (const method of ['GET', 'HEAD']) {
			const auth = await requestPage('/auth.md', method)
			expect(auth.status).toBe(200)
			expect(auth.headers.get('Link')).toContain(canonicalLink('/auth.md'))
			const bot = await requestPage('/docs/installation/', method, { 'User-Agent': 'ClaudeBot/1.0', Accept: 'text/html' })
			expect(bot.headers.get('Content-Type')).toContain('text/markdown')
			expect(bot.headers.get('Link')).toContain(canonicalLink('/docs/installation/'))
			if (method === 'HEAD') expect(await bot.text()).toBe('')
		}
	})

	it('preserves documentation robots metadata without making indexable Markdown noindex', async () => {
		for (const [path, robots] of [
			['/docs/reference/env-vars/', 'noindex,follow'],
			['/docs/guides/', 'noindex,nofollow'],
			['/docs/installation/', undefined],
			['/pricing/', undefined],
		] as const) {
			const html = await requestPage(path, 'GET', { Accept: 'text/html' })
			expect(html.status, path).toBe(200)
			expect(html.headers.get('Content-Type'), path).toContain('text/html')
			const head = (await html.text()).split('</head>', 1)[0]
			if (robots) expect(head).toContain(`<meta name="robots" content="${robots}"`)
			else expect(head).not.toMatch(/<meta[^>]+name="robots"[^>]+content="[^"]*noindex/)
			for (const method of ['GET', 'HEAD']) {
				for (const target of [path, markdownAt(path)]) {
					const response = await requestPage(target, method, { Accept: 'text/markdown' })
					expect(response.status, `${method} ${target}`).toBe(200)
					expect(response.headers.get('Content-Type'), target).toContain('text/markdown')
					expect(response.headers.get('X-Robots-Tag'), `${method} ${target}`).toBe(robots ?? null)
				}
			}
		}
		const sitemap = readdirSync('dist').filter((file) => /^sitemap.*\.xml$/.test(file)).map(readDist).join('\n')
		expect(sitemap).not.toContain('https://frontman.sh/docs/reference/env-vars/')
	})

	it('does not invent canonicals for missing pages or change human HTML to Markdown', async () => {
		const html = await requestPage('/docs/installation/', 'GET', { Accept: 'text/html' })
		expect(html.headers.get('Content-Type')).toContain('text/html')
		expect(await html.text()).toContain('<link rel="canonical" href="https://frontman.sh/docs/installation/"')
		for (const path of ['/docs/not-a-real-doc/', '/docs/not-a-real-doc.md']) {
			const response = await requestPage(path, 'GET', { Accept: 'text/markdown' })
			expect(response.status).toBe(404)
			expect(response.headers.get('Link')).not.toContain('rel="canonical"')
		}
	})
})
