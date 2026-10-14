import { expect, test } from 'vitest'
import { readFileSync } from 'node:fs'
import { onRequest } from '../../functions/_middleware'

const assets = { fetch: async () => new Response('# Markdown', { headers: { 'Content-Type': 'text/markdown; charset=utf-8', Vary: 'Origin', Link: '</custom>; rel="help"', 'X-Content-Type-Options': 'nosniff', ETag: '"md"' } }) }
const next = async () => new Response('HTML', { headers: { 'Content-Type': 'text/html', Vary: 'Accept-Encoding', ETag: '"html"' } })
const request = (path: string, accept?: string, method = 'GET') => new Request(`https://frontman.sh${path}`, { method, headers: accept ? { Accept: accept } : {} })
const run = (req: Request, fetch: (lookup: Request) => Promise<Response> = assets.fetch, fallback = next) => onRequest({ request: req, env: { ASSETS: { fetch } }, next: fallback })

test('quality and specificity select GET/HEAD representations, with explicit Markdown winning ties', async () => {
	for (const [accept, markdown] of [
		[undefined, false], ['*/*', false], ['text/*', false], ['application/json', false],
		['text/markdown', true], [' TEXT/MARKDOWN ; q=0.8 , text/html;q=0.5', true],
		['text/markdown;q=0', false], ['text/markdown;q=0,*/*;q=1', false],
		['text/markdown;q=0.8,text/*;q=0.9', false], ['text/markdown;q=0.8,text/html;q=0.9', false],
		['text/markdown;q=0.8,text/html;q=0.8', true], ['text/markdown;q=0.8,text/html;q=0,*/*;q=1', true],
		['text/markdown;q=wat', false], ['text/markdown;q=1.1', false], ['text/markdown;q=-1', false],
		['text/markdown;q', false], ['text/markdown;q=0.1234', false],
		['text/markdown;foo=bar', false], ['text/markdown;charset=utf-8', true],
	] as const) {
		for (const method of ['GET', 'HEAD']) {
			const response = await run(request('/pricing/', accept, method))
			expect(response.headers.get('Content-Type')).toContain(markdown ? 'text/markdown' : 'text/html')
			expect(await response.text()).toBe(method === 'HEAD' ? '' : markdown ? '# Markdown' : 'HTML')
			expect(response.headers.get('Cache-Control')).toBe('no-store')
			expect(response.headers.get('Vary')).toContain('Accept')
			expect(response.headers.get('ETag')).toBeNull()
		}
	}
})

test('agent JSON wins for known routes and first mode value, but never for POST/OPTIONS', async () => {
	for (const [path, canonical, description] of [
		['/', 'https://frontman.sh/', 'WordPress'],
		['/frameworks', 'https://frontman.sh/frameworks/', 'Next.js'],
		['/frameworks/', 'https://frontman.sh/frameworks/', 'Next.js'],
	]) {
		for (const method of ['GET', 'HEAD']) {
			const response = await run(request(`${path}?mode=agent&mode=other`, 'text/markdown', method))
			expect(response.headers.get('Content-Type')).toContain('application/json')
			expect(response.headers.get('Cache-Control')).toBe('no-store')
			if (method === 'HEAD') { expect(await response.text()).toBe(''); continue }
			const body = await response.json()
			expect(body.canonicalUrl).toBe(canonical)
			expect(body.description).toContain(description)
			expect(body.developerResources.openApi).toBe('https://frontman.sh/openapi.json')
			expect(body.developerResources.agentResourceDirectory).toBe('https://frontman.sh/.well-known/ard.json')
			expect(response.headers.get('Link')).toContain('</.well-known/api-catalog>; rel="api-catalog"')
			expect(response.headers.get('Link')).toContain('</openapi.json>; rel="service-desc"')
			expect(response.headers.get('Link')).toContain('</.well-known/ard.json>; rel="ard"')
			expect(body.apiEndpoints.every((endpoint: { url: string }) => !endpoint.url.includes('/user/') && !endpoint.url.includes('socket-token'))).toBe(true)
			expect(JSON.stringify(body)).not.toMatch(/agent-card|server-card/)
		}
	}
	for (const method of ['POST', 'OPTIONS']) {
		const unchanged = new Response('method unchanged', { status: 405 })
		expect(await run(request('/?mode=agent', 'text/markdown', method), assets.fetch, async () => unchanged)).toBe(unchanged)
	}
	expect(await (await run(request('/?mode=other&mode=agent'))).text()).toBe('HTML')
	expect(await (await run(request('/docs/?mode=agent', 'text/markdown'))).text()).toBe('# Markdown')
})

test('query/credential/validator canaries never reach assets or response links', async () => {
	const req = new Request('https://frontman.sh/docs/installation/?utm_source=keep&token=canary&target=https://evil.test', {
		headers: { Accept: 'text/markdown', Cookie: 'secret', Authorization: 'Bearer secret', Referer: 'https://private.test', 'If-None-Match': '"html"', 'If-Modified-Since': 'yesterday', Range: 'bytes=0-9', 'If-Range': '"html"' },
	})
	const response = await run(req, async (lookup) => {
		expect(lookup.url).toBe('https://frontman.sh/docs/installation.md')
		expect(lookup.method).toBe('GET')
		expect([...lookup.headers]).toEqual([])
		return assets.fetch()
	})
	expect(req.url).toContain('utm_source=keep')
	expect(response.headers.get('Link')).not.toMatch(/canary|evil|private/)
	expect(response.headers.get('Link')).toContain('</docs/installation.md>')
	expect(response.headers.get('Link')).toContain('</custom>')
	expect(response.headers.get('Vary')).toBe('Origin, Accept, User-Agent')
})

test('unknown routes, missing twins, direct assets and canonical redirects retain their status/type', async () => {
	for (const path of ['/index.md', '/pricing.md', '/docs/installation.md']) {
		const unchanged = new Response('original', { status: path.includes('.md') ? 200 : 404 })
		expect(await run(request(path, 'text/markdown'), async () => { throw new Error('Unexpected lookup') }, async () => unchanged)).toBe(unchanged)
	}
	for (const status of [200, 404]) {
		const html = new Response('HTML fallback', { status, headers: { 'Content-Type': 'text/html' } })
		const fallback = await run(request('/docs/missing/', 'text/markdown'), async () => html, async () => html)
		expect(fallback.status).toBe(status)
		expect(fallback.headers.get('Content-Type')).toContain(status === 404 ? 'text/markdown' : 'text/html')
		expect(fallback.headers.get('Link') ?? '').not.toContain('/docs/missing.md')
	}
	const redirect = await run(request('/frameworks', 'text/markdown'), async () => { throw new Error('Redirect lookup') }, async () => new Response(null, { status: 301, headers: { Location: '/frameworks/' } }))
	expect(redirect.status).toBe(301)
	expect(redirect.headers.get('Location')).toBe('/frameworks/')
	expect(redirect.headers.get('Link')).not.toContain('text/markdown')
	const varyStar = await run(request('/'), assets.fetch, async () => new Response('HTML', { headers: { Vary: '*' } }))
	expect(varyStar.headers.get('Vary')).toBe('*')
	const selected = await run(request('/', 'text/markdown'), async () => new Response('# Markdown', { headers: { 'Content-Type': 'text/markdown', 'Content-Encoding': 'gzip', 'Referrer-Policy': 'no-referrer', Vary: 'Origin, aCcEpT' } }))
	expect(selected.headers.get('Content-Encoding')).toBe('gzip')
	expect(selected.headers.get('Referrer-Policy')).toBe('no-referrer')
	expect(selected.headers.get('Vary')).toBe('Origin, aCcEpT, User-Agent')
})

test('HTML conditional validators cannot produce Markdown 304; security policy matches static headers', async () => {
	const staticHeaders = readFileSync(new URL('../../public/_headers', import.meta.url), 'utf8')
	for (const path of ['/', '/?mode=agent']) {
		const response = await run(request(path, 'text/markdown'), assets.fetch, async () => new Response(null, { status: 304, headers: { ETag: '"html"' } }))
		expect(response.status).toBe(200)
		for (const header of ['Content-Security-Policy', 'Permissions-Policy', 'Strict-Transport-Security', 'X-Content-Type-Options', 'Referrer-Policy']) {
			const value = staticHeaders.split('\n').find(line => line.trim().startsWith(`${header}:`))!.trim().slice(header.length + 2)
			expect(response.headers.get(header)).toBe(value)
		}
		expect(response.headers.get('CDN-Cache-Control')).toBe('no-store')
	}
})

test('AI bot user agents receive Markdown without changing human HTML or agent JSON', async () => {
	for (const agent of [
		'GPTBot/1.0', 'ClaudeBot/1.0', 'Claude-SearchBot/1.0', 'ChatGPT-User/1.0', 'PerplexityBot/1.0',
		'Google-Extended/1.0', 'Applebot-Extended/1.0', 'ora-agent/1.0', 'DeepSeekBot/1.0',
		'Mozilla/5.0 AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15 (Applebot/0.1; +http://www.apple.com/go/applebot)',
		'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; OAI-SearchBot/1.0; +https://openai.com/searchbot',
	]) {
		const response = await run(new Request('https://frontman.sh/', { headers: { 'User-Agent': agent, Accept: 'text/html' } }))
		expect(await response.text()).toBe('# Markdown')
		expect(response.headers.get('Vary')).toContain('User-Agent')
	}
	for (const agent of ['Mozilla/5.0', 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)']) {
		const human = await run(new Request('https://frontman.sh/', { headers: { 'User-Agent': agent, Accept: 'text/html' } }))
		expect(await human.text()).toBe('HTML')
	}
	const agentJson = await run(new Request('https://frontman.sh/?mode=agent', { headers: { 'User-Agent': 'OAI-SearchBot/1.0', Accept: 'text/html' } }))
	expect(agentJson.headers.get('Content-Type')).toContain('application/json')
	expect((await agentJson.json()).name).toBe('Frontman')
})

test('missing resources retain 404 and give agents Markdown help without looking up assets', async () => {
	for (const path of ['/missing/?mode=agent', '/docs/missing/', '/missing.md']) {
		for (const method of ['GET', 'HEAD']) {
			const response = await run(request(path, 'text/markdown', method), async () => { throw new Error('Unexpected lookup') },
				async () => new Response('HTML 404', { status: 404, headers: { 'Content-Type': 'text/html' } }))
			expect(response.status).toBe(404)
			expect(response.headers.get('Content-Type')).toContain('text/markdown')
			expect(await response.text()).toBe(method === 'HEAD' ? '' : '# Page not found\n\nThis Frontman resource does not exist. Find documentation and supported resources in [llms.txt](https://frontman.sh/llms.txt).\n')
		}
	}
	const original = new Response('HTML 404', { status: 404 })
	expect(await run(request('/missing/', 'text/html'), assets.fetch, async () => original)).toBe(original)
})

test('both sequential representation orders remain distinct and uncacheable', async () => {
	for (const sequence of [['text/html', 'text/markdown'], ['text/markdown', 'text/html']]) {
		for (const accept of [...sequence, ...sequence]) {
			const response = await run(request('/', accept))
			expect(await response.text()).toBe(accept === 'text/html' ? 'HTML' : '# Markdown')
			expect(response.headers.get('Cache-Control')).toBe('no-store')
		}
	}
})
