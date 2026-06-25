import type { APIRoute } from 'astro'

const siteUrl = new URL(import.meta.env.SITE)
const origin = siteUrl.origin

const agentCard = {
	name: 'Frontman',
	description:
		'Browser-aware AI frontend agent that uses live DOM, CSS, screenshots, component context, routes, and logs to edit real source files.',
	url: origin,
	provider: {
		name: 'Frontman AI',
		url: origin,
	},
	version: '1.0.0',
	documentationUrl: `${origin}/docs/`,
	contactUrl: `${origin}/contact/`,
	capabilities: {
		streaming: true,
		pushNotifications: false,
		stateTransitionHistory: true,
	},
	defaultInputModes: ['text/plain'],
	defaultOutputModes: ['text/plain', 'application/json', 'text/x-diff'],
	skills: [
		{
			id: 'visual-frontend-editing',
			name: 'Visual frontend editing',
			description: 'Select live UI elements and request source-code changes using runtime context.',
			tags: ['frontend', 'ai-coding-agent', 'visual-editing'],
		},
		{
			id: 'runtime-context',
			name: 'Runtime context collection',
			description: 'Collect DOM, CSS, screenshots, component tree, routes, and server logs for coding agents.',
			tags: ['mcp', 'browser', 'dev-server'],
		},
		{
			id: 'lighthouse-audits',
			name: 'Lighthouse audits',
			description: 'Run performance and accessibility audits inside the Frontman workflow.',
			tags: ['performance', 'accessibility'],
		},
	],
	endpoints: {
		documentation: `${origin}/docs/`,
		llms: `${origin}/llms.txt`,
		mcp: `${origin}/.well-known/mcp/server-card.json`,
		apiCatalog: `${origin}/.well-known/api-catalog`,
	},
}

export const GET: APIRoute = () => {
	return new Response(JSON.stringify(agentCard, null, 2), {
		headers: {
			'Content-Type': 'application/json; charset=utf-8',
		},
	})
}

export const prerender = true
