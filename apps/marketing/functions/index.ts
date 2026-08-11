const agentModeBody = {
	name: 'Frontman',
	canonicalUrl: 'https://frontman.sh/',
	description:
		'Frontman is an AI frontend agent that sees your live DOM, component tree, CSS, routes, and logs so it can turn visual requests into real code edits.',
	capabilities: [
		'Browser-aware visual editing for running web apps',
		'Live DOM, computed CSS, screenshots, component tree, routes, and logs as agent context',
		'Reviewable source-code edits with hot reload feedback',
		'Next.js, Astro, Vite, React, Vue, Svelte, and WordPress support',
		'Bring-your-own Claude, ChatGPT, or OpenRouter API key support',
	],
	developerResources: {
		docs: 'https://frontman.sh/docs/',
		installation: 'https://frontman.sh/docs/installation/',
		auth: 'https://frontman.sh/docs/api-keys/',
		configuration: 'https://frontman.sh/docs/reference/configuration/',
		architecture: 'https://frontman.sh/docs/reference/architecture/',
		markdownHomepage: 'https://frontman.sh/index.md',
		llms: 'https://frontman.sh/llms.txt',
		fullLlms: 'https://frontman.sh/llms-full.txt',
		apiCatalog: 'https://frontman.sh/.well-known/api-catalog',
		agentCard: 'https://frontman.sh/.well-known/agent-card.json',
		mcpServerCard: 'https://frontman.sh/.well-known/mcp/server-card.json',
		agentSkills: 'https://frontman.sh/.well-known/agent-skills/index.json',
		github: 'https://github.com/frontman-ai/frontman',
	},
	authentication: {
		signIn: 'GitHub or Google OAuth for hosted accounts',
		modelAccess: 'Users bring their own Claude, ChatGPT, or OpenRouter API keys',
		sessionApi: 'Authenticated browser sessions expose socket-token and user settings APIs',
	},
	apiEndpoints: [
		{ method: 'GET', url: 'https://api.frontman.sh/health/ready', purpose: 'Readiness check' },
		{ method: 'GET', url: 'https://api.frontman.sh/api/integrations/latest-versions', purpose: 'Latest integration package versions' },
		{ method: 'GET', url: 'https://api.frontman.sh/api/socket-token', purpose: 'Authenticated socket token for the browser client' },
		{ method: 'GET', url: 'https://api.frontman.sh/api/user/me', purpose: 'Authenticated current user metadata' },
		{ method: 'GET', url: 'https://api.frontman.sh/api/user/api-keys', purpose: 'Authenticated AI provider key status' },
	],
}

type PagesContext = {
	request: Request
	next: () => Promise<Response>
}

export const onRequest = async (context: PagesContext) => {
	const url = new URL(context.request.url)

	if (url.searchParams.get('mode') === 'agent') {
		return new Response(JSON.stringify(agentModeBody, null, 2), {
			headers: { 'Content-Type': 'application/json; charset=utf-8' },
		})
	}

	return context.next()
}
