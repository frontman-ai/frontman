import { defineCollection } from 'astro:content'
import { z } from 'astro/zod'
import { glob } from 'astro/loaders'
import { docsLoader } from '@astrojs/starlight/loaders'
import { docsSchema } from '@astrojs/starlight/schema'

const blog = defineCollection({
	loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
	schema: () =>
		z.object({
			title: z.string(),
			description: z.string(),
			pubDate: z.date(),
			image: z.string(),
			author: z.string(),
		authorRole: z.string().optional(),
			tags: z.array(z.string()),
		updatedDate: z.date().optional(),
		faq: z
			.array(
				z.object({
					question: z.string(),
					answer: z.string()
				})
			)
			.optional(),
		video: z
			.object({
				name: z.string(),
				description: z.string(),
				youtubeId: z.string(),
				thumbnailUrl: z.string().optional(),
				uploadDate: z.string().optional()
			})
			.optional()
	})
})

const glossary = defineCollection({
	loader: glob({ pattern: '**/*.md', base: './src/content/glossary' }),
	schema: () =>
		z.object({
			title: z.string(),
			description: z.string(),
			pubDate: z.date()
		})
})

const lighthouse = defineCollection({
	loader: glob({ pattern: '**/*.md', base: './src/content/lighthouse' }),
	schema: () =>
		z.object({
			title: z.string(),
			description: z.string(),
			pubDate: z.date(),
			auditId: z.string(),
			category: z.enum(['performance', 'accessibility', 'seo', 'best-practices']),
			weight: z.number(),
			faq: z
				.array(
					z.object({
						question: z.string(),
						answer: z.string()
					})
				)
				.optional()
		})
})

const docs = defineCollection({
	loader: docsLoader(),
	schema: docsSchema(),
})

export const collections = {
	blog,
	glossary,
	lighthouse,
	docs,
}
