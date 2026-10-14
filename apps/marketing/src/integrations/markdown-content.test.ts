import { expect, test } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { resolve } from 'node:path'
import { docsMarkdown } from '../content/docsMarkdown'
import { markdownPath } from '../content/markdownRoutes'
import { pricing, billingPlans, subscriptionTerms } from '../content/pricing'
import { GET as pricingGet } from '../pages/pricing.md'
import { GET as authGet } from '../pages/auth.md'

const read = (path: string) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')

test('pricing Markdown and HTML use the same maintained values and subscription terms', async () => {
	const markdown = await (await pricingGet({} as never)).text()
	const html = read('pages/pricing.astro')
	expect(markdown).toContain(`EUR ${pricing.monthly} per seat per month`)
	expect(markdown).toContain(`EUR ${pricing.yearly} per seat per year`)
	expect(markdown).toContain(subscriptionTerms)
	expect(subscriptionTerms).toMatch(/credit card required.*renew monthly or yearly.*Cancel before the next renewal.*VAT.*separate/)
	expect(billingPlans.yearly.amount).toBe((pricing.yearly / 12).toFixed(2))
	expect(html).toContain("import { billingPlans } from '../content/pricing'")
	for (const value of ['String(pricing.monthly)', 'String(pricing.yearly)', 'pricing.currency', '{pricing.monthly}', '{subscriptionTerms}']) expect(html).toContain(value)
})

test('access Markdown distinguishes public reads from hosted, provider, WordPress, and framework access', async () => {
	const response = await authGet({} as never)
	expect(response.headers.get('Content-Type')).toBe('text/markdown; charset=utf-8')
	const body = await response.text()
	for (const text of ['# Frontman authentication', 'No sign-in, API key, or cookie', 'not a public OAuth API', '## AI-provider access', 'administrator access', 'authenticated WebSocket sessions']) expect(body).toContain(text)
	expect(body).not.toMatch(/free tier|public editing API/i)
})

test('all maintained docs expand real snippets without import/component boilerplate or content loss', () => {
	const root = resolve('src/content/docs')
	const images = Object.fromEntries(readdirSync(resolve('src/assets/docs'), { recursive: true }).filter(file => String(file).endsWith('.png')).map(file => [String(file), `/_astro/${file}`]))
	for (const file of readdirSync(resolve(root, 'docs'), { recursive: true }).filter(file => /\.mdx?$/.test(String(file)))) {
		const raw = readFileSync(resolve(root, 'docs', String(file)), 'utf8')
		const title = raw.match(/^title:\s*(.+)$/m)![1]
		const body = raw.replace(/^---\n[\s\S]*?\n---\n/, '')
		const snippets = Object.fromEntries([...body.matchAll(/<CodeFromFile snippet="([^"]+)"\s*\/>/g)].map((match) => [match[1], readFileSync(resolve(root, 'snippets', match[1]), 'utf8')]))
		const markdown = docsMarkdown(title, body, snippets, images)
		for (const image of body.matchAll(/(!\[[^\]]*\])\((?:\.\.\/)+assets\/docs\/([^)]+)\)/g)) expect(markdown).toContain(`${image[1]}(${images[image[2]]})`)
		expect(markdown).not.toMatch(/\]\((?:\.\.\/)+assets\/docs\//)
		expect(markdown.startsWith(`# ${title}\n`)).toBe(true)
		expect(markdown).not.toMatch(/<CodeFromFile|^import CodeFromFile/m)
		for (const code of Object.values(snippets)) expect(markdown).toContain(code.trimEnd())
		for (const line of body.split('\n').filter(line => line.startsWith('## '))) expect(markdown).toContain(line)
		const path = `/docs/${String(file).replace(/\.mdx?$/, '').replace(/(^|\/)index$/, '')}`.replace(/\/$/, '')
		expect(markdownPath(`${path}/`)).toBe(`${path}.md`)
	}
	expect(() => docsMarkdown('Broken', '<CodeFromFile snippet="missing.ts.txt" />', {})).toThrow('Missing documentation snippet')
})

test('documentation images retain alt text and require an actual asset URL mapping', () => {
	const body = '![Screenshot with [nested] alt text](../../../../assets/docs/screen.png)'
	expect(docsMarkdown('Images', body, {}, { 'screen.png': '/_astro/screen.hash.png' })).toContain('![Screenshot with [nested] alt text](/_astro/screen.hash.png)')
	expect(() => docsMarkdown('Images', body, {}, {})).toThrow('Missing documentation image: screen.png')
	expect(read('pages/[...doc].md.ts')).toContain("query: '?url&no-inline'")
})

test('only matching pages advertise Markdown, never a universal homepage alternate', () => {
	expect(markdownPath('/')).toBe('/index.md')
	expect(markdownPath('/pricing/')).toBe('/pricing.md')
	expect(markdownPath('/frameworks')).toBe('/frameworks.md')
	expect(markdownPath('/blog/example/')).toBeUndefined()
	expect(read('components/blocks/head/Header.astro')).toContain('markdownPath(Astro.url.pathname)')
	expect(read('components/starlight/Head.astro')).toContain('entry && markdownPath(Astro.url.pathname)')
	expect(readFileSync(new URL('../../public/_headers', import.meta.url), 'utf8')).not.toContain('</index.md>')
	expect(read('pages/frameworks.md.ts')).toContain("getEntry('docs', 'docs/installation')")
})

test('framework Markdown has one H1 and consistently demotes maintained section headings', () => {
	const endpoint = read('pages/frameworks.md.ts')
	const sections = ['docs/installation', 'docs/using/limitations'].map((id, index) => {
		const raw = read(`content/docs/${id}.md`)
		const title = raw.match(/^title:\s*(.+)$/m)![1]
		const body = raw.replace(/^---\n[\s\S]*?\n---\n/, '')
		const name = index === 0 ? 'installation' : 'limitations'
		expect(endpoint).toContain(`docsMarkdown(${name}.data.title, ${name}.body, {}).replace(/^#/gm, '##')`)
		const original = docsMarkdown(title, body, {})
		const embedded = original.replace(/^#/gm, '##')
		expect(embedded.match(/^#+ .+$/gm)).toEqual(original.match(/^#+ .+$/gm)!.map(heading => `#${heading}`))
		return embedded
	})
	expect(`# Frontman for Next.js, Astro, and Vite\n${sections.join('\n')}`.match(/^# .+$/gm)).toEqual(['# Frontman for Next.js, Astro, and Vite'])
})

test('shared discovery uses truthful relations and unambiguous static artifact media types', () => {
	const headers = readFileSync(new URL('../../public/_headers', import.meta.url), 'utf8')
	for (const path of ['components/blocks/head/Header.astro', 'components/starlight/Head.astro']) {
		const head = read(path)
		for (const relation of ['api-catalog', 'service-desc', 'ard']) expect(head).toContain(`rel="${relation}"`)
		for (const url of ['/openapi.json', '/.well-known/ard.json']) expect(head).toContain(`href="${url}"`)
		expect(head).not.toMatch(/agent-card|server-card/)
	}
	expect(headers).toContain('/.well-known/api-catalog\n  Content-Type: application/linkset+json; profile="https://www.rfc-editor.org/info/rfc9727"; charset=utf-8\n  Link: <https://frontman.sh/.well-known/api-catalog>; rel="api-catalog"')
	expect(headers).toContain('/feeds/structured-data.jsonl\n  Content-Type: application/x-ndjson; charset=utf-8')
	expect(headers).toContain('/skills/*/SKILL.md\n  Content-Type: text/markdown; profile="urn:air:agent-skills"; charset=utf-8')
	expect(headers).not.toContain('\n/*.md\n')
	expect(headers).not.toMatch(/agent-card|server-card|\/\.well-known\/mcp/)
})
