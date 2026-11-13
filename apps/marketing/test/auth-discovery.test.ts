import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { expect, test } from 'vitest'

test('built auth.md distinguishes public reads, account registration, and MCP OAuth discovery', () => {
	const body = readFileSync(resolve('dist/auth.md'), 'utf8')
	expect(body.match(/^# .+$/gm)).toEqual(['# Frontman auth.md — authentication and access'])
	expect(body).toContain('canonical: "https://frontman.sh/auth.md"')
	expect(body).toContain('for AI agents')
	expect(body).toContain('HTTP GET without credentials')
	expect(body).toContain('https://api.frontman.sh/users/register')
	expect(body).toContain('GitHub or Google in the browser')
	expect(body).toContain('GET https://api.frontman.sh/.well-known/oauth-protected-resource')
	const [prm, registration] = [...body.matchAll(/```json\n([\s\S]*?)\n```/g)].map(match => JSON.parse(match[1]))
	expect(prm).toEqual({
		resource: 'https://api.frontman.sh/mcp',
		authorization_servers: ['https://scintillating-entry-74.authkit.app'],
		scopes_supported: [],
		bearer_methods_supported: ['header'],
	})
	const [issuer] = prm.authorization_servers
	expect(body).toContain(`GET ${issuer}/.well-known/oauth-authorization-server`)
	expect(body).toContain(`Its issuer is ${issuer}`)
	expect(body).toContain(`registration_endpoint is ${issuer}/oauth2/register`)
	expect(registration).toEqual({
		client_name: 'Your MCP client name',
		redirect_uris: ['https://your-client.example/oauth/callback'],
		grant_types: ['authorization_code'],
		response_types: ['code'],
		token_endpoint_auth_method: 'none',
	})
	expect(body).toContain('code_challenge_method=S256')
	expect(body).toContain('code_verifier')
	expect(body).toContain('Authorization: Bearer <access_token>')
	expect(body).toContain('explicit approval')
	expect(body).toContain('registers a client application, not a Frontman user')
	expect(body).toContain('no agent_auth block')
	expect(body).toContain('Do not probe POST /agent/auth')
	expect(body).toContain('do not POST to registration_endpoint')
	expect(body).not.toMatch(/"agent_auth"\s*:|"register_uri"\s*:/)
})

test('built auth.md describes WordPress provisioning and separates the three credential boundaries', () => {
	const body = readFileSync(resolve('dist/auth.md'), 'utf8')
	expect(body).toContain('same Frontman account used for the AI assistant')
	expect(body).toContain('If a provider prompt appears, click Connect AI provider to open Settings')
	expect(body).toContain('Open Settings, then General')
	expect(body).toContain('do not need to connect an AI provider or enter a key')
	expect(body).toContain('Enable MCP and connect')
	expect(body).toContain('POST https://api.frontman.sh/api/wordpress/connections')
	expect(body).toContain("requires the embedded client's Frontman bearer token")
	expect(body).toContain('WordPress Application Password named Frontman MCP')
	expect(body).toContain('password encrypted')
	expect(body).toContain('HTTP Basic authentication')
	expect(body).toContain('GET {site}/wp-json/frontman/v1/tools')
	expect(body).toContain('POST {site}/wp-json/frontman/v1/tools/call')
	expect(body).toContain('call list_sites')
	expect(body).toContain('site_id')
	expect(body).toContain('https://api.frontman.sh/wordpress/connect')
	expect(body).toContain('does not revoke the Application Password')
	expect(body).toContain('no separate AI-provider key')
	expect(body).toContain('These credentials are not interchangeable')
})

test('built deployment headers serve auth.md as Markdown', () => {
	const headers = readFileSync(resolve('dist/_headers'), 'utf8')
	expect(headers).toContain('/auth.md\n  Content-Type: text/markdown; charset=utf-8')
})
