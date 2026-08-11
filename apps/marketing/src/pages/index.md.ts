import type { APIRoute } from 'astro'

const body = `# Frontman

Frontman is an AI website editor for existing WordPress, Next.js, Astro, and Vite sites. Browser tools inspect the live page, local integrations handle filesystem or CMS operations, and a hosted or self-hosted server orchestrates the agent and persists task history. Relevant context is sent to your selected LLM provider to produce reviewable website updates.

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
