import type { APIRoute } from 'astro'
import { getEntry } from 'astro:content'
import { docsMarkdown } from '../content/docsMarkdown'

export const GET: APIRoute = async () => {
	const installation = await getEntry('docs', 'docs/installation')
	const limitations = await getEntry('docs', 'docs/using/limitations')
	if (!installation || !limitations || installation.body === undefined || limitations.body === undefined) throw new Error('Framework documentation is missing')
	return new Response(`# Frontman for Next.js, Astro, and Vite

Frontman edits your existing framework site in a supported development environment. Developers review source changes, run tests, and deploy normally. Provider access and costs are separate.

- Pricing: https://frontman.sh/pricing.md
- Authentication and access: https://frontman.sh/auth.md
- Compatibility: https://frontman.sh/docs/reference/compatibility/

${docsMarkdown(installation.data.title, installation.body, {}).replace(/^#/gm, '##')}
${docsMarkdown(limitations.data.title, limitations.body, {}).replace(/^#/gm, '##')}`, {
		headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
	})
}
export const prerender = true
