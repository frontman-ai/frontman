export function blogTransitionName(path: string): string {
	const normalizedPath = decodeURI(path).replace(/\/$/, '')
	return `blog-title-${Array.from(normalizedPath, (char) => char.codePointAt(0)!.toString(16)).join('-')}`
}
