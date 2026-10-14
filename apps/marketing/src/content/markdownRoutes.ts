export function markdownPath(pathname: string): string | undefined {
	const path = pathname.replace(/\/$/, '') || '/'
	switch (path) {
		case '/': return '/index.md'
		case '/pricing': return '/pricing.md'
		case '/frameworks': return '/frameworks.md'
		case '/changelog': return '/changelog.md'
		case '/.well-known/api-catalog': return '/.well-known/api-catalog.md'
		case '/api/llms.txt': return '/api/llms.txt.md'
		default:
			return /^\/docs(?:\/[\w-]+)*$/.test(path) ? `${path}.md` : undefined
	}
}
