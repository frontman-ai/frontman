import type { APIRoute } from 'astro'
import { getCollection } from 'astro:content'
import { docsMarkdown } from '../content/docsMarkdown'

export async function getStaticPaths() {
	const docs = await getCollection('docs', ({ data }) => !data.draft)
	const rawSnippets = import.meta.glob<string>('../content/docs/snippets/**/*.txt', { query: '?raw', import: 'default', eager: true })
	const imageUrls = import.meta.glob<string>('../assets/docs/**/*.png', { query: '?url&no-inline', import: 'default', eager: true })
	const images = Object.fromEntries(Object.entries(imageUrls).map(([path, url]) => [path.split('/assets/docs/')[1], url]))
	const snippets = Object.fromEntries(Object.entries(rawSnippets).map(([path, code]) => [path.split('/snippets/')[1], code]))
	return docs.map(({ id, data, body }) => {
		if (body === undefined) throw new Error(`Documentation body is missing: ${id}`)
		return { params: { doc: id.replace(/(^|\/)index$/, '') }, props: { markdown: docsMarkdown(data.title, body, snippets, images) } }
	})
}
export const GET: APIRoute = ({ props }) => new Response(props.markdown, {
	headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
})
export const prerender = true
