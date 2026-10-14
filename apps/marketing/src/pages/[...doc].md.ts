import type { APIRoute } from 'astro'
import { getCollection } from 'astro:content'
import { docsMarkdown } from '../content/docsMarkdown'
import { markdownResponse } from '../content/markdownResponse'
import changelog from '../../../../CHANGELOG.md?raw'
import apiGuide from '../../public/api/llms.txt?raw'
import { specification } from './openapi.json'

export async function getStaticPaths() {
	const docs = await getCollection('docs', ({ data }) => !data.draft)
	const rawSnippets = import.meta.glob<string>('../content/docs/snippets/**/*.txt', { query: '?raw', import: 'default', eager: true })
	const imageUrls = import.meta.glob<string>('../assets/docs/**/*.png', { query: '?url&no-inline', import: 'default', eager: true })
	const images = Object.fromEntries(Object.entries(imageUrls).map(([path, url]) => [path.split('/assets/docs/')[1], url]))
	const snippets = Object.fromEntries(Object.entries(rawSnippets).map(([path, code]) => [path.split('/snippets/')[1], code]))
	const paths = docs.map(({ id, data, body }) => {
		if (body === undefined) throw new Error(`Documentation body is missing: ${id}`)
		const path = id.replace(/(^|\/)index$/, '').replace(/\/$/, '')
		return { params: { doc: path }, props: { markdown: docsMarkdown(data.title, body, snippets, images), canonical: `/${path}/` } }
	})
	return [...paths,
		{ params: { doc: 'changelog' }, props: { markdown: changelog, canonical: '/changelog/' } },
		{ params: { doc: 'api/llms.txt' }, props: { markdown: apiGuide, canonical: '/api/llms.txt' } },
		{ params: { doc: '.well-known/api-catalog' }, props: {
			markdown: `# Frontman API catalog\n\nPublic read-only resources; no credentials required.\n\n${Object.entries(specification.paths).map(([path, entry]) => `- GET ${'servers' in entry ? entry.servers[0].url : import.meta.env.SITE}${path}: ${entry.get.summary}`).join('\n')}\n\nOpenAPI: https://frontman.sh/openapi.json\nAccess: https://frontman.sh/auth.md\n`,
			canonical: '/.well-known/api-catalog',
		} },
	]
}
export const GET: APIRoute = ({ props }) => markdownResponse(props.markdown, props.canonical)
export const prerender = true
