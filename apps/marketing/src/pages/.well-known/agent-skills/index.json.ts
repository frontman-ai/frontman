import type { APIRoute } from 'astro'
import { createHash } from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

const siteUrl = new URL(import.meta.env.SITE)
const origin = siteUrl.origin
const appRoot = process.cwd()

const skillDocs = [
  {
    name: 'frontman-site-navigation',
    type: 'skill-md',
    description: 'Discover Frontman product pages, documentation, API catalog, and support resources.',
    url: `${origin}/skills/frontman-site-navigation/SKILL.md`,
    file: 'public/skills/frontman-site-navigation/SKILL.md',
  },
  {
    name: 'frontman-installation',
    type: 'skill-md',
    description: 'Install Frontman in Next.js, Astro, Vite, and WordPress projects.',
    url: `${origin}/skills/frontman-installation/SKILL.md`,
    file: 'public/skills/frontman-installation/SKILL.md',
  },
  {
    name: 'frontman-agent-usage',
    type: 'skill-md',
    description: 'Use Frontman as a browser-aware frontend coding agent with runtime context.',
    url: `${origin}/skills/frontman-agent-usage/SKILL.md`,
    file: 'public/skills/frontman-agent-usage/SKILL.md',
  },
]

const skills = skillDocs.map((skill) => ({
  name: skill.name,
  type: skill.type,
  description: skill.description,
  url: skill.url,
  digest: `sha256:${createHash('sha256').update(fs.readFileSync(path.join(appRoot, skill.file))).digest('hex')}`,
}))

const index = {
  $schema: 'https://schemas.agentskills.io/discovery/0.2.0/schema.json',
  skills,
}

export const GET: APIRoute = () => {
  return new Response(JSON.stringify(index, null, 2), {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
  })
}
