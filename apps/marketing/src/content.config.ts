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
			seoTitle: z.string().optional(),
			description: z.string(),
			pubDate: z.date(),
			image: z.string(),
			imageWidth: z.number(),
			imageHeight: z.number(),
			imageAlt: z.string(),
			author: z.enum(['Danni Friedland', 'Itay Adler']),
			authorRole: z.literal('Co-founder, Frontman'),
			authorUrl: z.enum(['/authors/danni-friedland/', '/authors/itay-adler/']),
			articleSection: z.enum([
				'Problem Diagnosis',
				'Product Announcement',
				'Tutorial',
				'Comparison or Buyer Guide',
				'Technical Explainer',
				'Operational Audit'
			]),
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
			comparisonItems: z
				.array(
					z.object({
						name: z.string(),
						url: z.string(),
						description: z.string().optional()
					})
				)
				.optional(),
			softwareApplication: z
				.object({
					name: z.string(),
					url: z.string(),
					applicationCategory: z.string(),
					operatingSystem: z.string(),
					description: z.string(),
					codeRepository: z.string().optional(),
					license: z.string().optional(),
					featureList: z.array(z.string()).optional(),
					offers: z
						.array(
							z.object({
								name: z.string(),
								price: z.string(),
								priceCurrency: z.string(),
								url: z.string(),
								category: z.string().optional(),
								description: z.string().optional()
							})
						)
						.optional()
				})
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

const releases = defineCollection({
	loader: glob({ pattern: '**/*.md', base: './src/content/releases' }),
	schema: () =>
		z.object({
			title: z.string(),
			description: z.string(),
			month: z.string(),
			year: z.number(),
			pubDate: z.date(),
			updatedDate: z.date().optional(),
			image: z.string().optional(),
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
	releases,
	docs,
}
