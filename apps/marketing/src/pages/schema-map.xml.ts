import type { APIRoute } from 'astro'

const origin = new URL(import.meta.env.SITE).origin

const schemaMap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:sf="http://schema.org/schemas/schemafeed/0.1">
  <url>
    <loc>${origin}/feeds/structured-data.jsonl</loc>
    <sf:contentType>structuredData/schema.org</sf:contentType>
  </url>
  <url>
    <loc>${origin}/rss.xml</loc>
    <sf:contentType>structuredData/rss</sf:contentType>
  </url>
</urlset>`

export const GET: APIRoute = () => new Response(schemaMap, {
	headers: { 'Content-Type': 'application/xml; charset=utf-8' },
})
export const prerender = true
