import type { APIRoute } from 'astro'

const body = `# Frontman

Frontman is an AI WordPress editor plugin for existing sites. Describe changes to posts, pages, Gutenberg blocks, Elementor pages, menus, templates, settings, and WooCommerce data beside live preview. Frontman for WordPress is production-ready and battle-tested. Only administrators can access the workspace. Keep backups and review changes in the live preview.

## Choose Your Workflow

- WordPress: https://frontman.sh/
- Install the WordPress plugin: https://wordpress.org/plugins/frontman-agentic-ai-editor/
- WordPress setup guide: https://frontman.sh/docs/integrations/wordpress/
- Next.js, Astro, and Vite: https://frontman.sh/frameworks/
- Framework installation: https://frontman.sh/frameworks/#install

Framework integrations inspect the live page and source context to produce reviewable code edits. A hosted or self-hosted server orchestrates the agent and persists task history. Relevant context is sent to your selected LLM provider.

## Core Capabilities

- Select rendered elements and ask Frontman to change copy, spacing, color, layout, menus, or page content.
- Use runtime context from Next.js, Astro, Vite, React, Vue, Svelte, and WordPress.
- Bring your own Claude, ChatGPT, or OpenRouter API key.
- Keep developers in control with local development edits and normal git diffs for code-backed sites.
- Run Frontman Pro hosted or self-host from the source-available repository.

## Developer Resources

- Documentation: https://frontman.sh/docs/
- Installation: https://frontman.sh/docs/installation/
- API keys and auth: https://frontman.sh/docs/api-keys/
- Configuration: https://frontman.sh/docs/reference/configuration/
- Architecture: https://frontman.sh/docs/reference/architecture/
- Self-hosting: https://frontman.sh/docs/reference/self-hosting/
- Agent card: https://frontman.sh/.well-known/agent-card.json
- MCP server card: https://frontman.sh/.well-known/mcp/server-card.json
- Agent skills index: https://frontman.sh/.well-known/agent-skills/index.json
- API catalog: https://frontman.sh/.well-known/api-catalog
- GitHub: https://github.com/frontman-ai/frontman

## Authentication And Access

Frontman hosted accounts use OAuth sign-in with GitHub or Google. AI provider access is bring-your-own-key: users connect Claude, ChatGPT, or OpenRouter credentials from Frontman settings. Local framework integrations connect to the Frontman service over authenticated WebSocket sessions.

## Support

- Contact: https://frontman.sh/contact/
- Privacy: https://frontman.sh/privacy/
- Terms: https://frontman.sh/terms/
`

export const GET: APIRoute = () => {
	return new Response(body, {
		headers: {
			'Content-Type': 'text/markdown; charset=utf-8',
		},
	})
}

export const prerender = true
