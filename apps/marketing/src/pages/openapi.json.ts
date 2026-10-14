import type { APIRoute } from 'astro'
import * as S from 'sury'
import { searchIndexSchema } from '../integrations/webmcp-validators.mjs'

const origin = new URL(import.meta.env.SITE).origin
const versionsSchema = S.schema({ versions: S.record(S.nullable(S.string)) })

export const specification = {
	openapi: '3.1.0',
	info: {
		title: 'Frontman public read-only resources',
		version: '1.0.0',
		description: 'Public documentation and integration metadata. No sign-in or API key is required. These reads do not edit websites or expose authenticated product sessions.',
	},
	servers: [{ url: origin }],
	security: [],
	paths: {
		'/search-index.json': {
			get: {
				operationId: 'readDocumentationIndex',
				summary: 'Read the public documentation search index',
				description: 'Returns non-draft, searchable documentation with titles, canonical URLs, and Markdown source. Search locally; this is not a product or pricing index.',
				security: [],
				responses: {
					'200': {
						description: 'Public documentation entries',
						content: { 'application/json': {
							schema: S.toJSONSchema(searchIndexSchema),
							example: [{ title: 'Installation', url: `${origin}/docs/installation/`, content: '# Installation\nChoose your integration.' }],
						} },
					},
				},
			},
		},
		'/api/integrations/latest-versions': {
			servers: [{ url: 'https://api.frontman.sh' }],
			get: {
				operationId: 'readLatestIntegrationVersions',
				summary: 'Read latest framework adapter package versions',
				description: 'Reads npm metadata for @frontman-ai/nextjs, @frontman-ai/astro, and @frontman-ai/vite. Results may be cached for 30 minutes. Failed registry reads can be null; timed-out packages can be omitted. WordPress has no npm adapter entry.',
				security: [],
				responses: {
					'200': {
						description: 'Package-name map; incomplete results are possible',
						content: { 'application/json': {
							schema: S.toJSONSchema(versionsSchema),
							example: { versions: { '@frontman-ai/nextjs': '0.0.1', '@frontman-ai/astro': null } },
						} },
					},
				},
			},
		},
	},
}

export const GET: APIRoute = () => new Response(JSON.stringify(specification, null, 2), {
	headers: { 'Content-Type': 'application/json; charset=utf-8' },
})
export const prerender = true
