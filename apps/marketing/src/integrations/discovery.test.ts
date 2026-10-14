import { beforeAll, expect, test, vi } from 'vitest'
import type { APIRoute, APIContext } from 'astro'
import { createHash } from 'node:crypto'
import { existsSync, readFileSync } from 'node:fs'
import * as S from 'sury'
import { parse as parseYaml } from 'yaml'
import Ajv2020 from 'ajv/dist/2020.js'
import { searchIndexSchema } from './webmcp-validators.mjs'
import ardSchema from './fixtures/ard-entry.schema.json'

const read = (path: string) => readFileSync(path, 'utf8')
const call = async (route: APIRoute) => await route({} as APIContext)
beforeAll(() => { vi.stubEnv('SITE', 'https://frontman.sh') })

const ajv = new Ajv2020({ strict: false })
	.addFormat('uri', (value: string) => S.is(S.url, value))
	.addFormat('date-time', (value: string) => S.is(S.isoDateTime, value))

test('OpenAPI describes only existing public reads with the actual response schemas', async () => {
	const { GET, specification } = await import('../pages/openapi.json')
	expect((await call(GET)).headers.get('Content-Type')).toContain('application/json')
	expect(specification.openapi).toBe('3.1.0')
	expect(specification.security).toEqual([])
	const docs = specification.paths['/search-index.json'].get
	expect(docs.responses['200'].content['application/json'].schema).toEqual(S.toJSONSchema(searchIndexSchema))
	const operations = Object.values(specification.paths).map(path => path.get)
	expect(new Set(operations.map(op => op.operationId)).size).toBe(operations.length)
	for (const op of operations) {
		expect(op.security).toEqual([])
		expect(op.description.length).toBeGreaterThan(20)
	}
	const versions = specification.paths['/api/integrations/latest-versions']
	expect(versions.servers).toEqual([{ url: 'https://api.frontman.sh' }])
	const validate = ajv.compile(versions.get.responses['200'].content['application/json'].schema)
	expect(validate({ versions: {} })).toBe(true)
	expect(validate({ versions: { '@frontman-ai/astro': null, '@frontman-ai/nextjs': '0.0.1' } })).toBe(true)
	expect(validate({ versions: { '@frontman-ai/astro': 123 } })).toBe(false)
	expect(validate({})).toBe(false)
	const router = read('../frontman_server/lib/frontman_server_web/router.ex')
	expect(router).toMatch(/pipe_through\(:api\)[\s\S]*get\("\/integrations\/latest-versions"/)
	const controller = read('../frontman_server/lib/frontman_server_web/controllers/integrations_controller.ex')
	expect(controller).toContain('json(conn, %{versions: versions})')
	expect(controller).toContain('{package, nil}')
	expect(controller).toContain('{:exit, _reason}, acc -> acc')
	expect(Object.keys(specification.paths)).toEqual(['/search-index.json', '/api/integrations/latest-versions'])
})

test('RFC 9727 catalog items are endpoints with description and documentation links; HEAD carries discovery', async () => {
	const { GET, HEAD } = await import('../pages/.well-known/api-catalog')
	const response = await call(GET)
	expect(response.headers.get('Content-Type')).toContain('application/linkset+json; profile="https://www.rfc-editor.org/info/rfc9727"')
	const { linkset } = await response.json()
	expect(linkset[0].item.map((item: { href: string }) => item.href)).toEqual([
		'https://frontman.sh/search-index.json', 'https://api.frontman.sh/api/integrations/latest-versions',
	])
	for (const item of linkset[0].item) {
		expect(item.href).not.toBe(linkset[0].anchor)
		const entry = linkset.find((entry: { anchor: string }) => entry.anchor === item.href)
		expect(entry['service-desc'][0].href).toBe('https://frontman.sh/openapi.json')
		expect(entry['service-doc'][0].href).toBe('https://frontman.sh/api/llms.txt')
	}
	const head = await call(HEAD)
	expect(head.headers.get('Link')).toBe('<https://frontman.sh/.well-known/api-catalog>; rel="api-catalog"')
	expect(head.headers.get('Content-Type')).toBe(response.headers.get('Content-Type'))
	expect(await head.text()).toBe('')
})

test('ARD validates against the pinned current schema and resolves real artifacts with matching digests', async () => {
	const { GET } = await import('../pages/.well-known/ard.json')
	const { GET: skillsGET } = await import('../pages/.well-known/agent-skills/index.json')
	const response = await call(GET)
	const body = await response.text()
	const manifest = S.parser(S.jsonString, S.json)(body)
	const validate = ajv.compile({ ...ardSchema, $ref: '#/$defs/ArdManifest' })
	expect(validate(manifest), JSON.stringify(validate.errors)).toBe(true)
	const { entries } = await (await call(GET)).json()
	const { skills } = await (await call(skillsGET)).json()
	expect(entries.length).toBe(skills.length + 1)
	for (const skill of skills) {
		const artifact = readFileSync(`public${new URL(skill.url).pathname}`)
		expect(skill.digest).toBe(`sha256:${createHash('sha256').update(artifact).digest('hex')}`)
		const entry = entries.find((entry: { url: string }) => entry.url === skill.url)
		expect(entry.type).toBe('text/markdown; profile="urn:air:agent-skills"')
		expect(entry.representativeQueries.length).toBeGreaterThanOrEqual(2)
	}
	expect(entries.filter((entry: { type: string }) => /mcp|a2a/.test(entry.type))).toEqual([])
	expect(entries.at(-1).url).toBe('https://frontman.sh/openapi.json')
})

test('every advertised skill frontmatter matches its identity, digest, and ARD entry', async () => {
	const { GET } = await import('../pages/.well-known/agent-skills/index.json')
	const { GET: ardGET } = await import('../pages/.well-known/ard.json')
	const { skills } = await (await call(GET)).json()
	const { entries } = await (await call(ardGET)).json()
	expect(skills.length).toBeGreaterThan(0)
	for (const skill of skills) {
		const artifact = read(`public${new URL(skill.url).pathname}`)
		const frontmatter = artifact.match(/^---\n([\s\S]*?)\n---\n/)
		expect(frontmatter, skill.name).not.toBeNull()
		const metadata = S.parser(S.schema({ name: S.string, description: S.string }))(parseYaml(frontmatter![1]))
		expect(metadata.name).toBe(skill.name)
		expect(metadata.description).toBe(skill.description)
		expect(skill.digest).toBe(`sha256:${createHash('sha256').update(artifact).digest('hex')}`)
		const entry = entries.find((entry: { url: string }) => entry.url === skill.url)
		expect(entry.displayName).toBe(metadata.name)
		expect(entry.description).toBe(metadata.description)
	}
})

test('Schema Map uses the current proposal format and points to JSONL, not JSON text sequences', async () => {
	const { GET } = await import('../pages/schema-map.xml')
	const { GET: feedGET } = await import('../pages/feeds/structured-data.jsonl')
	const xml = await (await call(GET)).text()
	expect(xml).toContain('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"')
	expect(xml).toContain('xmlns:sf="http://schema.org/schemas/schemafeed/0.1"')
	expect(xml).toContain('<sf:contentType>structuredData/schema.org</sf:contentType>')
	expect(xml).toContain('<sf:contentType>structuredData/rss</sf:contentType>')
	expect(xml).toContain('<loc>https://frontman.sh/feeds/structured-data.jsonl</loc>')
	expect(xml).not.toContain('application/ld+json-seq')
	const feed = await call(feedGET)
	expect(feed.headers.get('Content-Type')).toBe('application/x-ndjson; charset=utf-8')
	const schema = S.schema({ '@context': S.literal('https://schema.org'), '@type': S.string })
	for (const line of (await feed.text()).trim().split('\n')) {
		expect(S.parser(S.jsonString, schema)(line)['@type']).toBeTruthy()
	}
})

test('robots adds only Schema Map discovery, leaving crawler policy bytes unchanged', async () => {
	const { GET } = await import('../pages/robots.txt')
	const body = await (await call(GET)).text()
	const source = read('src/pages/robots.txt.ts')
	expect(body).toContain('Schemamap: https://frontman.sh/schema-map.xml')
	const groups = source.slice(source.indexOf('User-agent:'), source.indexOf('Sitemap:'))
	expect(createHash('sha256').update(groups).digest('hex')).toBe('2ed3a1d6c913884b05ca2b2724e8f087402c4ee4361a75eeac216d6cf929b8be')
})

test('removed protocol routes have no source, rewrite, or incoming public-index links', () => {
	for (const path of ['agent-card.json.ts', 'mcp/server-card.json.ts']) {
		expect(existsSync(`src/pages/.well-known/${path}`)).toBe(false)
	}
	for (const path of ['public/_redirects', 'public/.well-known/index.html', 'public/llms.txt', 'public/llms-full.txt', 'public/api/llms.txt', 'public/developers/llms.txt', 'public/skills/frontman-site-navigation/SKILL.md']) {
		expect(read(path)).not.toMatch(/\.well-known\/(agent-card|mcp)/)
	}
	expect(existsSync('src/pages/404.astro')).toBe(true)
})
