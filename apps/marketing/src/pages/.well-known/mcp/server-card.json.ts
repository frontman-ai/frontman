import type { APIRoute } from 'astro'

const siteUrl = new URL(import.meta.env.SITE)
const origin = siteUrl.origin

const serverCard = {
  name: 'Frontman marketing site discovery',
  description:
    'Static discovery card for Frontman marketing resources. Frontman product MCP servers run inside local framework dev servers, not as a public remote MCP endpoint on the marketing site.',
  homepage: origin,
  resources: [
    { name: 'LLMs summary', url: `${origin}/llms.txt`, contentType: 'text/plain' },
    { name: 'Full LLM context', url: `${origin}/llms-full.txt`, contentType: 'text/plain' },
    { name: 'API catalog', url: `${origin}/.well-known/api-catalog`, contentType: 'application/linkset+json' },
    { name: 'Agent skills', url: `${origin}/.well-known/agent-skills/index.json`, contentType: 'application/json' },
  ],
  tools: [],
}

export const GET: APIRoute = () => {
  return new Response(JSON.stringify(serverCard, null, 2), {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
  })
}
