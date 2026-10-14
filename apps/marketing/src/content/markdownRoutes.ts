export function markdownPath(pathname: string): string | undefined {
	const path = pathname.replace(/\/$/, '') || '/'
	switch (path) {
		case '/': return '/index.md'
		case '/pricing': return '/pricing.md'
		case '/frameworks': return '/frameworks.md'
		default:
			return /^\/docs(?:\/[\w-]+)*$/.test(path) ? `${path}.md` : undefined
	}
}
