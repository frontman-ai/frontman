export const minimumIndexableTagPosts = 3

export const isIndexableTagCount = (count) => count >= minimumIndexableTagPosts

export const countPostsByTag = (posts) => {
	const counts = new Map()

	for (const post of posts) {
		for (const tag of post.data.tags) {
			counts.set(tag, (counts.get(tag) ?? 0) + 1)
		}
	}

	return counts
}
