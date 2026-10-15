export function docsMarkdown(title: string, body: string, snippets: Record<string, string>, images: Record<string, string> = {}): string {
	const markdown = body
		.replace(/\]\(((?:\.\.\/)+assets\/docs\/[^)\s]+)\)/g, (_, source: string) => {
			const name = source.split('/assets/docs/')[1]
			const url = images[name]
			if (url === undefined) throw new Error(`Missing documentation image: ${name}`)
			return `](${url})`
		})
		.replace(/^import CodeFromFile from ['"][^'"]+['"];?\s*$/gm, '')
		.replace(/<CodeFromFile snippet="([^"]+)"\s*\/>/g, (_, name: string) => {
			const code = snippets[name]
			if (code === undefined) throw new Error(`Missing documentation snippet: ${name}`)
			const lang = name.replace(/\.txt$/, '').split('.').pop()
			return `\n\`\`\`${lang}\n${code.trimEnd()}\n\`\`\`\n`
		})
	return `# ${title}\n\n${markdown.trim()}\n`
}
