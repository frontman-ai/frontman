import type { APIRoute } from 'astro'

const siteUrl = new URL(import.meta.env.SITE)
const origin = siteUrl.origin

const agentCard = {
	name: 'Frontman',
	description:
		'AI website editor for existing WordPress, Next.js, Astro, and Vite sites. Uses live page context, CSS, screenshots, CMS or component context, routes, and logs to make reviewable updates.',
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
			id: 'visual-website-editing',
			name: 'Visual website editing',
			description: 'Select live website elements and request WordPress updates or source-code changes using runtime context.',
			tags: ['website-editor', 'visual-editing', 'wordpress'],
		},
		{
			id: 'runtime-context',
			name: 'Runtime context collection',
			description: 'Collect DOM, CSS, screenshots, CMS or component context, routes, and server logs for website editing agents.',
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
