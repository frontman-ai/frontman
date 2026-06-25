import type { APIRoute } from 'astro'

const siteUrl = new URL(import.meta.env.SITE)
const origin = siteUrl.origin

const apiCatalog = {
	linkset: [
		{
			anchor: origin,
			'service-desc': [
				{
					href: `${origin}/.well-known/api-catalog`,
					type: 'application/linkset+json',
					title: 'Frontman API catalog',
				},
			],
			'describedby': [
				{ href: `${origin}/docs/`, type: 'text/html', title: 'Frontman documentation' },
				{ href: `${origin}/docs/api-keys/`, type: 'text/html', title: 'Frontman auth documentation' },
				{ href: `${origin}/docs/reference/architecture/`, type: 'text/html', title: 'Frontman architecture' },
			],
			'alternate': [
				{ href: `${origin}/index.md`, type: 'text/markdown', title: 'Frontman markdown homepage' },
				{ href: `${origin}/llms.txt`, type: 'text/plain', title: 'Frontman llms.txt' },
				{ href: `${origin}/llms-full.txt`, type: 'text/plain', title: 'Frontman full LLM context' },
			],
			'https://schemas.agentskills.io/rels/skills-index': [
				{ href: `${origin}/.well-known/agent-skills/index.json`, type: 'application/json', title: 'Frontman agent skills index' },
			],
			'https://modelcontextprotocol.io/rels/server-card': [
				{ href: `${origin}/.well-known/mcp/server-card.json`, type: 'application/json', title: 'Frontman MCP server card' },
			],
		},
	],
}

export const GET: APIRoute = () => {
	return new Response(JSON.stringify(apiCatalog, null, 2), {
		headers: {
			'Content-Type': 'application/linkset+json; charset=utf-8',
		},
	})
}

export const prerender = true
