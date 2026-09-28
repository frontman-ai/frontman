import type { APIRoute } from 'astro'
import { getCollection } from 'astro:content'
import * as S from 'sury'
import { searchIndexSchema } from '../integrations/webmcp-validators.mjs'

const encodeIndex = S.parser(searchIndexSchema, S.jsonString)

export const GET: APIRoute = async ({ site }) => {
	const docs = await getCollection('docs', ({ data }) => !data.draft && data.pagefind)
	return new Response(encodeIndex(docs.map(({ id, data, body }) => ({
		title: data.title,
		url: new URL(id.replace(/(^|\/)index$/, '') + '/', site).href,
		content: body,
	}))), { headers: { 'Content-Type': 'application/json; charset=utf-8' } })
}

export const prerender = true
