import type { APIRoute } from 'astro'

const siteUrl = new URL(import.meta.env.SITE)
const origin = siteUrl.origin

const serverCard = {
  name: 'Frontman MCP discovery',
  description:
    'Discovery card for Frontman agent integration. Frontman framework plugins expose browser and dev-server context to AI agents during local development.',
  homepage: origin,
  documentation: `${origin}/docs/reference/architecture/`,
  auth: `${origin}/docs/api-keys/`,
  transports: [
    {
      type: 'local-dev-server',
      description: 'Next.js, Astro, Vite, and WordPress integrations expose project-aware tools from the running app.',
    },
    {
      type: 'websocket',
      url: 'wss://api.frontman.sh/socket',
      description: 'Authenticated hosted agent session transport used by the Frontman browser client.',
    },
  ],
  resources: [
    { name: 'LLMs summary', url: `${origin}/llms.txt`, contentType: 'text/plain' },
    { name: 'Full LLM context', url: `${origin}/llms-full.txt`, contentType: 'text/plain' },
    { name: 'Markdown homepage', url: `${origin}/index.md`, contentType: 'text/markdown' },
    { name: 'API catalog', url: `${origin}/.well-known/api-catalog`, contentType: 'application/linkset+json' },
    { name: 'Agent skills', url: `${origin}/.well-known/agent-skills/index.json`, contentType: 'application/json' },
  ],
  tools: [
    {
      name: 'inspect_dom',
      description: 'Inspect selected elements, computed styles, bounding boxes, and source mappings in a local app.',
    },
    {
      name: 'read_dev_context',
      description: 'Read routes, logs, build state, and framework metadata from the local dev server.',
    },
    {
      name: 'apply_source_edit',
      description: 'Apply reviewable source-code edits and rely on hot reload for feedback.',
    },
  ],
}

export const GET: APIRoute = () => {
  return new Response(JSON.stringify(serverCard, null, 2), {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
  })
}
