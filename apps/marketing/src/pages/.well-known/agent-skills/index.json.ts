import type { APIRoute } from 'astro'
import { createHash } from 'node:crypto'

const siteUrl = new URL(import.meta.env.SITE)
const origin = siteUrl.origin

const skillDocs = [
  {
    name: 'marketing-site-navigation',
    type: 'site-resource',
    description: 'Discover the main Frontman marketing pages and documentation entry points.',
    url: `${origin}/`,
  },
  {
    name: 'docs',
    type: 'documentation',
    description: 'Read Frontman installation, integration, troubleshooting, and self-hosting docs.',
    url: `${origin}/docs/`,
  },
  {
    name: 'markdown-negotiation',
    type: 'content-negotiation',
    description: 'Request markdown responses for the homepage with Accept: text/markdown.',
    url: `${origin}/`,
  },
  {
    name: 'webmcp-site-tools',
    type: 'browser-tools',
    description: 'Use lightweight WebMCP tools for on-site navigation such as opening docs or jumping to install.',
    url: `${origin}/`,
  },
]

const skills = skillDocs.map((skill) => ({
  ...skill,
  sha256: createHash('sha256').update(JSON.stringify(skill)).digest('hex'),
}))

const index = {
  $schema: 'https://agentskills.io/schemas/agent-skills-index-v0.2.0.json',
  skills,
}

export const GET: APIRoute = () => {
  return new Response(JSON.stringify(index, null, 2), {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
  })
}
