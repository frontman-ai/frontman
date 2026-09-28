export const minimumIndexableTagPosts = 3

export const isIndexableTagCount = (count) => count >= minimumIndexableTagPosts

const parseTag = (value) => value.trim().replace(/^['"]|['"]$/g, '')

export const parseFrontmatterTags = (source) => {
	const frontmatter = source.match(/^---\s*\n([\s\S]*?)\n---/)?.[1] ?? source
	const lines = frontmatter.split('\n')
	const tagsLineIndex = lines.findIndex((line) => /^tags:\s*/.test(line))
	if (tagsLineIndex === -1) return []

	const inlineValue = lines[tagsLineIndex].replace(/^tags:\s*/, '').trim()
	if (inlineValue.length > 0) {
		if (!inlineValue.startsWith('[') || !inlineValue.endsWith(']')) {
			throw new Error('Blog tags must use a YAML array')
		}

		return inlineValue.slice(1, -1).split(',').map(parseTag).filter(Boolean)
	}

	const tags = []
	for (const line of lines.slice(tagsLineIndex + 1)) {
		const item = line.match(/^\s+-\s+(.+)$/)?.[1]
		if (!item) break
		tags.push(parseTag(item))
	}
	return tags
}

export const countPostsByTag = (posts) => {
	const counts = new Map()

	for (const post of posts) {
		for (const tag of post.data.tags) {
			counts.set(tag, (counts.get(tag) ?? 0) + 1)
		}
	}

	return counts
}
