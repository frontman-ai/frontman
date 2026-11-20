import type { CollectionEntry } from 'astro:content'

// Each list is ordered as a reading path. Tags remain a separate, exhaustive index.
export const blogTopics = [
	{
		id: 'browser-aware-coding',
		title: 'Browser-aware AI coding',
		description: 'Understand what coding agents miss when they only see source code, then try a workflow that gives the agent context from a running Next.js app.',
		posts: [
			'what-are-browser-aware-ai-coding-tools',
			'ai-coding-agents-blind-to-ui',
			'runtime-context-gap',
			'tutorial-nextjs-runtime-context',
			'edit-nextjs-visually'
		]
	},
	{
		id: 'choosing-coding-tools',
		title: 'Choosing an AI coding tool',
		description: 'Start with the comparison for frontend teams, then narrow your options by codebase size, open-source requirements, or the tools you already use.',
		posts: [
			'best-ai-coding-agents-frontend-development-teams-2026',
			'6-ai-coding-tools-production',
			'best-open-source-ai-coding-tools-2026',
			'frontman-vs-cursor-vs-claude-code'
		]
	},
	{
		id: 'wordpress-tools',
		title: 'Choosing WordPress tools',
		description: 'Compare AI plugins, options for connecting an external AI agent via MCP, and visual builders for editing pages.',
		posts: [
			'best-wordpress-ai-plugins-2026',
			'best-wordpress-mcp-servers-and-plugins-2026',
			'best-wordpress-visual-website-builders'
		]
	},
	{
		id: 'wordpress-maintenance',
		title: 'WordPress editing and maintenance',
		description: 'Use the maintenance checklist to plan routine work, or jump to a guide for headers and footers, mobile layouts, or Elementor performance.',
		posts: [
			'wordpress-maintenance-checklist',
			'how-to-edit-wordpress-header-footer',
			'how-to-make-wordpress-website-mobile-friendly',
			'how-to-make-elementor-website-faster'
		]
	}
]

export function resolveBlogTopics(posts: CollectionEntry<'blog'>[]) {
	const byId = new Map(posts.map(post => [post.id, post]))
	return blogTopics.map(topic => ({
		...topic,
		posts: topic.posts.map(id => {
			const post = byId.get(id)
			if (!post) throw new Error(`Blog topic "${topic.id}" references missing post "${id}"`)
			return post
		})
	}))
}
