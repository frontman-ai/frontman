export function markdownResponse(body: string, canonicalPath: string): Response {
	const title = body.match(/^# (.+)$/m)?.[1]
	if (!title) throw new Error(`Markdown title is missing: ${canonicalPath}`)
	const canonical = new URL(canonicalPath, import.meta.env.SITE).href
	return new Response(`---\ntitle: ${JSON.stringify(title)}\ncanonical: ${JSON.stringify(canonical)}\n---\n\n${body}`, {
		headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
	})
}
