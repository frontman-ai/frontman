import type { APIRoute } from 'astro'

const origin = new URL(import.meta.env.SITE).origin
const catalogUrl = `${origin}/.well-known/api-catalog`
const endpoints = [
	{ href: `${origin}/search-index.json`, type: 'application/json', title: 'Public documentation index' },
	{ href: 'https://api.frontman.sh/api/integrations/latest-versions', type: 'application/json', title: 'Latest framework adapter versions' },
]
const apiCatalog = {
	linkset: [
		{ anchor: catalogUrl, item: endpoints },
		...endpoints.map(({ href }) => ({
			anchor: href,
			'service-desc': [{ href: `${origin}/openapi.json`, type: 'application/json', title: 'Public read-only OpenAPI description' }],
			'service-doc': [{ href: `${origin}/api/llms.txt`, type: 'text/plain', title: 'Public reads and authentication boundaries' }],
		})),
	],
}

const headers = {
	'Content-Type': 'application/linkset+json; profile="https://www.rfc-editor.org/info/rfc9727"; charset=utf-8',
	Link: `<${catalogUrl}>; rel="api-catalog"`,
}
export const GET: APIRoute = () => new Response(JSON.stringify(apiCatalog, null, 2), { headers })
export const HEAD: APIRoute = () => new Response(null, { headers })
export const prerender = true
