export function markdownResponse(body: string, canonicalPath: string, robots?: string): Response {
	const title = body.match(/^# (.+)$/m)?.[1]
	if (!title) throw new Error(`Markdown title is missing: ${canonicalPath}`)
	const canonical = new URL(canonicalPath, import.meta.env.SITE).href
	return new Response(`---\ntitle: ${JSON.stringify(title)}\ncanonical: ${JSON.stringify(canonical)}\n${robots ? `robots: ${JSON.stringify(robots)}\n` : ''}---\n\n${body}`, {
		headers: {
			'Content-Type': 'text/markdown; charset=utf-8',
			Link: `<${canonical}>; rel="canonical"`,
			...(robots ? { 'X-Robots-Tag': robots } : {}),
		},
	})
}

// Static prerendering keeps the Markdown body but discards endpoint response headers.
// Read our JSON-quoted frontmatter fields to restore them at the Cloudflare boundary.
export async function restoreMarkdownHeaders(response: Response): Promise<Response> {
	const metadata = (await response.clone().text()).match(/^---\n([\s\S]*?)\n---\n/)?.[1]
	const canonical = metadata?.match(/^canonical: (".*")$/m)?.[1]
	if (!canonical) return response
	const headers = new Headers(response.headers)
	const link = `<${JSON.parse(canonical)}>; rel="canonical"`
	if (!headers.get('Link')?.includes(link)) headers.append('Link', link)
	const robots = metadata?.match(/^robots: (".*")$/m)?.[1]
	if (robots) headers.set('X-Robots-Tag', JSON.parse(robots))
	return new Response(response.body, { status: response.status, statusText: response.statusText, headers })
}
