import type { APIRoute } from 'astro'

const robotsTxt = `
User-agent: *
Allow: /

# AI crawlers — explicitly allowed so Frontman appears in AI-generated answers
User-agent: GPTBot
Allow: /

User-agent: ChatGPT-User
Allow: /

User-agent: Google-Extended
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: anthropic-ai
Allow: /

User-agent: ClaudeBot
Allow: /

User-agent: CCBot
Allow: /

User-agent: cohere-ai
Allow: /

User-agent: OAI-SearchBot
Allow: /

User-agent: Applebot-Extended
Allow: /

Sitemap: ${new URL('sitemap-index.xml', import.meta.env.SITE).href}
`.trim()

export const GET: APIRoute = () => {
	return new Response(robotsTxt, {
		headers: {
			'Content-Type': 'text/plain; charset=utf-8'
		}
	})
}
