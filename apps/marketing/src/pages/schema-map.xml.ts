import type { APIRoute } from 'astro'

const siteUrl = new URL(import.meta.env.SITE)
const origin = siteUrl.origin

const schemaMap = `<?xml version="1.0" encoding="UTF-8"?>
<schemaMap xmlns="https://nlweb.ai/schemas/schemamap/1.0">
  <feed>
    <loc>${origin}/feeds/structured-data.jsonl</loc>
    <type>application/ld+json-seq</type>
    <name>Frontman structured data feed</name>
    <description>Machine-readable Organization, SoftwareApplication, Product, Service, and FAQ entities for Frontman.</description>
  </feed>
  <feed>
    <loc>${origin}/rss.xml</loc>
    <type>application/rss+xml</type>
    <name>Frontman blog RSS</name>
    <description>Frontman articles and product updates.</description>
  </feed>
</schemaMap>`

export const GET: APIRoute = () => {
	return new Response(schemaMap, {
		headers: {
			'Content-Type': 'application/xml; charset=utf-8',
		},
	})
}

export const prerender = true
