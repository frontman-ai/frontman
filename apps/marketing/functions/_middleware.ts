const agentModeBody = {
	name: 'Frontman',
	canonicalUrl: 'https://frontman.sh/',
	description:
		'Frontman is an AI WordPress editor plugin for existing sites. Describe changes to content, blocks, Elementor pages, menus, templates, settings, and WooCommerce data beside live preview. Framework integrations are also available.',
	capabilities: [
		'WordPress-native editing beside live site preview',
		'Live DOM, computed CSS, screenshots, component tree, routes, and logs as agent context',
		'WordPress updates or framework source-code edits with live preview feedback',
		'Next.js, Astro, Vite, React, Vue, Svelte, and WordPress support',
		'Bring-your-own Claude, ChatGPT, or OpenRouter API key support',
	],
	developerResources: {
		wordpressPlugin: 'https://wordpress.org/plugins/frontman-agentic-ai-editor/',
		wordpressSetup: 'https://frontman.sh/docs/integrations/wordpress/',
		frameworks: 'https://frontman.sh/frameworks/',
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

const frameworkAgentModeBody = {
	...agentModeBody,
	canonicalUrl: 'https://frontman.sh/frameworks/',
	description: 'Frontman is an AI frontend agent for Next.js, Astro, and Vite. Click elements in your running app and turn visual requests into reviewable source-code edits.',
	capabilities: [
		'Click-to-edit frontend source changes with hot reload',
		'Live DOM, computed CSS, screenshots, component tree, routes, and logs as agent context',
		'Next.js, Astro, Vite, React, Vue, and Svelte support',
		'Bring-your-own Claude, ChatGPT, or OpenRouter API key support',
	],
}

type PagesContext = {
	request: Request
	next: () => Promise<Response>
}

export const onRequest = async (context: PagesContext) => {
	const url = new URL(context.request.url)

	const isFrameworks = url.pathname === '/frameworks' || url.pathname === '/frameworks/'

	if (url.searchParams.get('mode') === 'agent' && (url.pathname === '/' || isFrameworks)) {
		const body = isFrameworks ? frameworkAgentModeBody : agentModeBody
		return new Response(JSON.stringify(body, null, 2), {
			headers: { 'Content-Type': 'application/json; charset=utf-8' },
		})
	}

	return context.next()
}
