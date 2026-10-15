import { markdownPath } from '../src/content/markdownRoutes'

const agentModeBody = {
	name: 'Frontman',
	resourceType: 'Public product information, not an executable A2A agent or remote MCP service.',
	canonicalUrl: 'https://frontman.sh/',
	description:
		'Frontman is an AI WordPress editor plugin for existing sites. Describe changes to content, blocks, Elementor pages, menus, templates, settings, and WooCommerce data beside live preview. Framework integrations are also available.',
	capabilities: [
		'WordPress-native editing beside live site preview',
		'Live DOM, computed CSS, screenshots, component tree, routes, and logs as agent context',
		'WordPress updates or framework source-code edits with live preview feedback',
		'Next.js, Astro, Vite, React, Vue, Svelte, and WordPress support',
		'Supported AI-provider account connections or saved provider keys, with separate provider costs',
	],
	developerResources: {
		wordpressPlugin: 'https://wordpress.org/plugins/frontman-agentic-ai-editor/',
		wordpressSetup: 'https://frontman.sh/docs/integrations/wordpress/',
		frameworks: 'https://frontman.sh/frameworks/',
		docs: 'https://frontman.sh/docs/',
		installation: 'https://frontman.sh/docs/installation/',
		auth: 'https://frontman.sh/auth.md',
		providerAccess: 'https://frontman.sh/docs/api-keys/',
		pricing: 'https://frontman.sh/pricing.md',
		markdownFrameworks: 'https://frontman.sh/frameworks.md',
		configuration: 'https://frontman.sh/docs/reference/configuration/',
		architecture: 'https://frontman.sh/docs/reference/architecture/',
		markdownHomepage: 'https://frontman.sh/index.md',
		llms: 'https://frontman.sh/llms.txt',
		fullLlms: 'https://frontman.sh/llms-full.txt',
		apiCatalog: 'https://frontman.sh/.well-known/api-catalog',
		openApi: 'https://frontman.sh/openapi.json',
		agentResourceDirectory: 'https://frontman.sh/.well-known/ard.json',
		discoveryNote: 'ARD is an evolving proposal describing public read-only resources, not an editing protocol.',
		agentSkills: 'https://frontman.sh/.well-known/agent-skills/index.json',
		github: 'https://github.com/frontman-ai/frontman',
	},
	authentication: {
		signIn: 'GitHub or Google OAuth for hosted accounts',
		modelAccess: 'Connect supported Anthropic/OpenAI accounts or save supported Anthropic, OpenRouter, Fireworks AI, or NVIDIA keys; provider access and costs are separate.',
		sessionApi: 'Socket-token, user settings, and provider credential endpoints require authenticated embedded-client access; they are not public agent APIs. Browser login is not a public OAuth API for third-party agents.',
		publicReads: 'Marketing, pricing, documentation, Markdown, search index, and published agent skills require no key or sign-in.',
	},
	apiEndpoints: [
		{ method: 'GET', url: 'https://api.frontman.sh/health/ready', purpose: 'Readiness check' },
		{ method: 'GET', url: 'https://api.frontman.sh/api/integrations/latest-versions', purpose: 'Latest integration package versions; values may be null or omitted after timeouts' },
	],
}

const frameworkAgentModeBody = {
	...agentModeBody,
	canonicalUrl: 'https://frontman.sh/frameworks/',
	description: 'Frontman is an AI frontend agent for Next.js, Astro, and Vite. Click elements in your running app and turn visual requests into reviewable source-code edits.',
	capabilities: [
		'Click-to-edit frontend source changes with hot reload',
		'Live DOM, computed CSS, screenshots, component tree, routes, and logs as agent context',
		'Next.js, Astro, Vite, React, Vue, and Svelte support',
		'Supported AI-provider account connections or saved provider keys, with separate provider costs',
	],
}

type PagesContext = {
	request: Request
	next: () => Promise<Response>
	env: { ASSETS: { fetch: (request: Request) => Promise<Response> } }
}

const securityHeaders = {
	'X-Content-Type-Options': 'nosniff',
	'Referrer-Policy': 'strict-origin-when-cross-origin',
	'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload',
	'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=(), shared-storage=(), attribution-reporting=()',
	'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline' https://www.googletagmanager.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://api.frontman.sh https://www.googletagmanager.com https://www.google-analytics.com https://region1.analytics.google.com; frame-src 'self' https://www.googletagmanager.com https://www.youtube-nocookie.com; worker-src 'self' blob:; base-uri 'self'; form-action 'self'; frame-ancestors 'self' https://rankinpublic.xyz",
}
const discoveryLink = '</llms.txt>; rel="alternate"; type="text/plain", </llms-full.txt>; rel="alternate"; type="text/plain", </sitemap-index.xml>; rel="sitemap"; type="application/xml", </rss.xml>; rel="alternate"; type="application/rss+xml", </.well-known/api-catalog>; rel="api-catalog"; type="application/linkset+json", </openapi.json>; rel="service-desc"; type="application/json", </.well-known/ard.json>; rel="ard"; type="application/json"'

function prefersMarkdown(accept: string | null): boolean {
	const ranges = (accept ?? '').split(',').map((range) => {
		const [type, ...params] = range.trim().toLowerCase().split(';').map(part => part.trim())
		const qIndex = params.findIndex(param => /^q(?:=|$)/.test(param))
		const q = qIndex < 0 ? '1' : params[qIndex].slice(2)
		const supported = params.slice(0, qIndex < 0 ? undefined : qIndex).every(param => /^charset=(?:utf-8|"utf-8")$/.test(param))
		return { type: supported ? type : '', quality: /^(?:0(?:\.\d{0,3})?|1(?:\.0{0,3})?)$/.test(q) ? Number(q) : 0 }
	})
	const quality = (type: string) => {
		for (const match of [type, 'text/*', '*/*']) {
			const matching = ranges.filter(range => range.type === match)
			if (matching.length) return Math.max(...matching.map(range => range.quality))
		}
		return 0
	}
	return ranges.some(range => range.type === 'text/markdown') && quality('text/markdown') > 0 && quality('text/markdown') >= quality('text/html')
}

function negotiatedResponse(response: Response, request: Request, alternate?: string): Response {
	const headers = new Headers(response.headers)
	for (const name of ['ETag', 'Last-Modified', 'Content-Length']) headers.delete(name)
	for (const [name, value] of Object.entries(securityHeaders)) {
		if (!headers.has(name)) headers.set(name, value)
	}
	const vary = headers.get('Vary')?.split(',').map(value => value.trim()) ?? []
	if (!vary.some(value => ['accept', '*'].includes(value.toLowerCase()))) vary.push('Accept')
	if (!vary.some(value => ['user-agent', '*'].includes(value.toLowerCase()))) vary.push('User-Agent')
	headers.set('Vary', vary.join(', '))
	headers.set('Cache-Control', 'no-store')
	headers.set('CDN-Cache-Control', 'no-store')
	headers.set('Cloudflare-CDN-Cache-Control', 'no-store')
	headers.set('Link', `${headers.get('Link') ?? discoveryLink}${alternate ? `, <${alternate}>; rel="alternate"; type="text/markdown"` : ''}`)
	return new Response(request.method === 'HEAD' ? null : response.body, { status: response.status, statusText: response.statusText, headers })
}

export const onRequest = async (context: PagesContext) => {
	const { request } = context
	if (!['GET', 'HEAD'].includes(request.method)) return context.next()
	const url = new URL(request.url)
	const alternate = markdownPath(url.pathname)
	const isFrameworks = url.pathname === '/frameworks' || url.pathname === '/frameworks/'

	if (url.searchParams.get('mode') === 'agent' && (url.pathname === '/' || isFrameworks)) {
		const body = isFrameworks ? frameworkAgentModeBody : agentModeBody
		return negotiatedResponse(new Response(JSON.stringify(body, null, 2), {
			headers: { 'Content-Type': 'application/json; charset=utf-8' },
		}), request, alternate!)
	}
	const bot = /\b(?:GPTBot|ClaudeBot|Claude-SearchBot|ChatGPT-User|OAI-SearchBot|PerplexityBot|Applebot|Google-Extended|Applebot-Extended|ora-agent|DeepSeekBot)\b/i.test(request.headers.get('User-Agent') ?? '')
	const wantsMarkdown = prefersMarkdown(request.headers.get('Accept')) || bot
	const html = await context.next()
	if (html.status === 404 && wantsMarkdown) return negotiatedResponse(new Response('# Page not found\n\nThis Frontman resource does not exist. Find documentation and supported resources in [llms.txt](https://frontman.sh/llms.txt).\n', {
		status: 404, headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
	}), request)
	if (!alternate || html.status === 404) return html
	if (html.status >= 300 && html.status < 400 && html.status !== 304) return negotiatedResponse(html, request)
	const markdown = await context.env.ASSETS.fetch(new Request(new URL(alternate, url.origin), { method: 'GET' }))
	if (!markdown.ok || markdown.headers.get('Content-Type')?.split(';')[0] !== 'text/markdown') return negotiatedResponse(html, request)
	return negotiatedResponse(wantsMarkdown ? markdown : html, request, alternate)
}
