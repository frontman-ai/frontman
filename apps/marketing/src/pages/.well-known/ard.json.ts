import type { APIRoute } from 'astro'
import * as S from 'sury'
import { skills } from './agent-skills/index.json'
import { createHash } from 'node:crypto'
import openapiSource from '../openapi.json.ts?raw'

const origin = new URL(import.meta.env.SITE).origin
const queries: Record<string, string[]> = {
	'frontman-site-navigation': ['Where are Frontman documentation and support?', 'Which public resources can I read without signing in?'],
	'frontman-installation': ['How do I install Frontman for WordPress?', 'How do I set up Frontman in a development project?'],
	'frontman-agent-usage': ['How does Frontman use browser context?', 'What access and review does website editing require?'],
}
const manifestSchema = S.schema({
	specVersion: S.literal('1.0'),
	entries: S.array(S.schema({
		identifier: S.string, displayName: S.string, type: S.string, url: S.string,
		description: S.string, representativeQueries: S.array(S.string).with(S.min, 2).with(S.max, 5),
		trustManifest: S.schema({
			identity: S.string, identityType: S.literal('https'),
			provenance: S.array(S.schema({ relation: S.literal('publishedFrom'), sourceId: S.string, sourceDigest: S.string })),
		}),
	})),
})

const manifest = {
	specVersion: '1.0',
	entries: [
		...skills.map(({ name, description, url }) => ({
			identifier: `urn:air:frontman.sh:skills:${name}`,
			displayName: name, type: 'text/markdown; profile="urn:air:agent-skills"',
			url, description, representativeQueries: queries[name],
		})),
		{
			identifier: 'urn:air:frontman.sh:api:public-reads',
			displayName: 'Frontman public read-only resources',
			type: 'application/json', url: `${origin}/openapi.json`,
			description: 'OpenAPI 3.1 description of documentation reads and framework package versions; not a website-editing API.',
			representativeQueries: ['How can I search Frontman documentation without credentials?', 'Where can I read the latest framework adapter versions?'],
		},
	].map(entry => {
		const skill = skills.find(skill => skill.url === entry.url)
		const source = skill ? `public/skills/${skill.name}/SKILL.md` : 'src/pages/openapi.json.ts'
		const digest = skill ? skill.digest : `sha256:${createHash('sha256').update(openapiSource).digest('hex')}`
		return { ...entry, trustManifest: {
			identity: `${origin}/`, identityType: 'https' as const,
			provenance: [{ relation: 'publishedFrom' as const, sourceId: `https://github.com/frontman-ai/frontman/blob/main/apps/marketing/${source}`, sourceDigest: digest }],
		} }
	}),
}
export const GET: APIRoute = () => new Response(S.parser(manifestSchema, S.jsonString)(manifest), {
	headers: { 'Content-Type': 'application/json; charset=utf-8' },
})
export const prerender = true
