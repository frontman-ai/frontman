import type { APIRoute } from 'astro'

const body = `# Frontman

Your WordPress site. Your changes. No agency handoff. Frontman is an AI editor for marketing leads who know what their existing site needs but lack WordPress expertise or agency availability. Describe one update, inspect the page, and refine it. WordPress-native writes persist to the connected installation. Published content on a live site can change immediately; preview is not a universal approval gate. Frontman for WordPress is production-ready. Start with staging and backups; recovery depends on the changed surface.

## WordPress First, Frameworks Second

- WordPress: https://frontman.sh/
- Install the WordPress plugin: https://wordpress.org/plugins/frontman-agentic-ai-editor/
- WordPress setup guide: https://frontman.sh/docs/integrations/wordpress/
- Next.js, Astro, and Vite: https://frontman.sh/frameworks/
- Framework installation: https://frontman.sh/frameworks/#install

Framework integrations require a running supported Next.js, Astro, or Vite development environment and permitted workspace access. Developers review source changes, run tests, and deploy through their normal workflow. Check production guards and runtime exposure rather than assume automatic stripping. A hosted or self-hosted server orchestrates the agent and persists task history. Relevant context is sent to your selected LLM provider.

## Core Capabilities

- Select rendered elements and ask Frontman to change copy, spacing, color, layout, menus, or page content.
- Edit Gutenberg blocks, Elementor sections, and navigation on your existing WordPress site.
- Separate Next.js, Astro, and Vite integrations use browser and source context for developer-reviewed changes.
- Connect a supported AI provider account or save a supported provider key; provider access and costs are separate.
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

WordPress requires WordPress 6.0+, PHP 7.4+, and administrator access. Open Frontman from the WordPress admin menu. Sign in to Frontman with GitHub or Google and arrange service access; see https://frontman.sh/pricing/. AI-provider access and costs are separate. Current settings support Anthropic and OpenAI OAuth connections, and saved keys for Anthropic, OpenRouter, Fireworks AI, and NVIDIA. See https://frontman.sh/docs/api-keys/. Framework integrations connect to the Frontman service over authenticated WebSocket sessions.

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
