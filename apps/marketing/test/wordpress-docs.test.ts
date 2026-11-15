import { readFileSync, readdirSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const { JSDOM } = createRequire(import.meta.url)('jsdom') as {
	JSDOM: new (html: string) => { window: { document: Document } }
}

const read = (path: string) => readFileSync(resolve('dist', path), 'utf8')
const documentFor = (path: string) =>
	new JSDOM(read(`${path}/index.html`)).window.document
const workflowSlugs = ['posts-and-pages', 'gutenberg', 'elementor', 'woocommerce-products', 'seo-metadata']
const agentSlugs = ['chatgpt', 'claude', 'dots', 'muse', 'instinct']
const slugs = ['choose-interface', 'connect-agent', 'permissions', 'troubleshooting', 'agents', 'recovery', 'multiple-sites', ...workflowSlugs, ...agentSlugs]

describe('WordPress agent documentation production output', () => {
	it('publishes indexable HTML and matching Markdown for each guide', () => {
		for (const slug of slugs) {
			const path = `docs/wordpress/${slug}`
			const document = documentFor(path)
			const title = document.querySelector('h1')?.textContent?.trim()
			expect(document.querySelectorAll('h1')).toHaveLength(1)
			expect(document.querySelector('link[rel="canonical"]')?.getAttribute('href'))
				.toBe(`https://frontman.sh/${path}/`)
			expect(document.querySelector('meta[name="description"]')?.getAttribute('content')?.length)
				.toBeGreaterThan(100)
			expect(document.querySelector('meta[name="robots"]')?.getAttribute('content') ?? '')
				.not.toContain('noindex')
			expect(document.querySelector('link[type="text/markdown"]')?.getAttribute('href'))
				.toContain(`${path}.md`)
			expect(read(`${path}.md`)).toContain(`# ${title}`)
		}
	})

	it('includes the guides in search, sitemaps, navigation and agent discovery', () => {
		const search = JSON.parse(read('search-index.json')) as { url: string }[]
		const sitemap = readdirSync(resolve('dist'))
			.filter(file => /^sitemap.*\.xml$/.test(file)).map(read).join('\n')
		const index = documentFor('docs')
		for (const slug of slugs) {
			const path = `/docs/wordpress/${slug}/`
			expect(index.querySelector(`a[href="${path}"]`), path).not.toBeNull()
			expect(search.some(entry => entry.url === `https://frontman.sh${path}`), path).toBe(true)
			expect(sitemap).toContain(`https://frontman.sh${path}`)
			expect(read('docs/llms.txt')).toContain(`https://frontman.sh${path}`)
		}
		expect(documentFor('docs/integrations/wordpress')
			.querySelector('main a[href="/docs/wordpress/connect-agent/"]')).not.toBeNull()
	})

	it('separates hosted access, safe discovery and credential revocation', () => {
		const connect = documentFor('docs/wordpress/connect-agent').querySelector('main')?.textContent ?? ''
		expect(connect).toContain('https://api.frontman.sh/mcp')
		expect(connect).toContain('eligible subscription trial')
		expect(connect).toContain('list_sites')
		expect(connect).toContain('site_id')
		expect(connect).toContain('Do not change anything')
		expect(connect).toContain('do not need a separate AI provider')
		const permissions = documentFor('docs/wordpress/permissions').querySelector('main')?.textContent ?? ''
		expect(permissions).toContain('does not revoke the Application Password')
		expect(permissions).toContain('does not undo completed changes')
		expect(permissions).toContain('no plugin-wide one-click undo')
		const troubleshooting = read('docs/wordpress/troubleshooting.md')
		expect(troubleshooting).toContain('An active subscription or eligible trial is required for hosted MCP')
		expect(troubleshooting).toContain('read the current state')
		expect(troubleshooting).toContain('hostname label, not a full site URL')
		expect(troubleshooting).toContain('read site information for the candidate IDs')
		expect(read('auth.md')).toContain('cancellation requested or recorded does not grant access')
		const confirmation = documentFor('docs/integrations/wordpress')
			.querySelector('.sl-markdown-content')?.textContent ?? ''
		expect(confirmation).toContain('WooCommerce endpoint tools using PUT or DELETE, and metadata writes, require confirm=true')
		expect(confirmation).toContain('WooCommerce POST create tools do not require that field')
		expect(confirmation).toContain('This includes product, order, and refund creation')
		expect(confirmation).toContain('separate from the plugin enforcing')
	})

	it('routes every workflow and named-agent article through a contextual hub', () => {
		const setup = documentFor('docs/wordpress/connect-agent').querySelector('.sl-markdown-content')
		for (const slug of [...workflowSlugs, 'multiple-sites', 'agents', 'recovery']) {
			expect(setup?.querySelector(`a[href="/docs/wordpress/${slug}/"]`), slug).not.toBeNull()
		}
		const agents = documentFor('docs/wordpress/agents').querySelector('.sl-markdown-content')
		for (const slug of agentSlugs) {
			expect(agents?.querySelector(`a[href="/docs/wordpress/${slug}/"]`), slug).not.toBeNull()
		}
	})

	it('groups MCP connections separately from shared editing workflows', () => {
		const document = documentFor('docs/wordpress/choose-interface')
		const groups = Array.from(document.querySelectorAll('nav.sidebar details'))
		const mcp = groups.find(group => group.querySelector(':scope > summary')?.textContent?.includes('MCP Connections'))
		const editing = groups.find(group => group.querySelector(':scope > summary')?.textContent?.includes('Editing Workflows'))
		expect(mcp?.querySelector('a[href="/docs/wordpress/multiple-sites/"]')).toBeTruthy()
		expect(mcp?.querySelector('a[href="/docs/wordpress/permissions/"]')).toBeTruthy()
		expect(editing?.querySelector('a[href="/docs/wordpress/multiple-sites/"]')).toBeNull()
		for (const slug of workflowSlugs) {
			expect(editing?.querySelector(`a[href="/docs/wordpress/${slug}/"]`), slug).toBeTruthy()
			const markdown = read(`docs/wordpress/${slug}.md`)
			expect(markdown, slug).toContain('/docs/wordpress/choose-interface/')
			expect(markdown, slug).not.toContain('Complete [Connect Your AI Agent to WordPress]')
		}
		const chooser = document.querySelector('.sl-markdown-content')
		expect(chooser?.querySelector('a[href="/docs/integrations/wordpress/#use-the-frontman-editor"]')).toBeTruthy()
		expect(chooser?.querySelector('a[href="/docs/wordpress/connect-agent/"]')).toBeTruthy()
		const products = read('docs/wordpress/woocommerce-products.md')
		expect(products).toContain('For hosted MCP, retain the same `site_id` for that readback')
		expect(products).not.toContain('again with the same `site_id` and `productId`')
	})

	it('retains real tool identities and separates persistence, recovery and capability checks', () => {
		const requirements: Record<string, string[]> = {
			'posts-and-pages': ['wp_read_post', 'wp_update_post', 'draft', 'expected_current_sha256'],
			gutenberg: ['wp_', 'block', 'nested'],
			elementor: ['wp_elementor_', 'rollback_id', 'post_id'],
			'woocommerce-products': ['wc_', 'confirm', 'description'],
			'seo-metadata': ['seo_capabilities', 'wp_read_seo', 'wp_update_seo', 'public HTML'],
			'multiple-sites': ['list_sites', 'site_id', 'hostname'],
			recovery: ['wp_elementor_restore_rollback', 'confirm=true', 'response is lost'],
		}
		for (const [slug, terms] of Object.entries(requirements)) {
			const markdown = read(`docs/wordpress/${slug}.md`)
			for (const term of terms) expect(markdown, `${slug}: ${term}`).toContain(term)
		}
	})

	it('keeps vendor-documented features separate from live Frontman compatibility', () => {
		const compatibility = read('docs/wordpress/agents.md')
		for (const term of ['Vendor-documented', 'Source-reviewed', 'Live-verified', 'Not tested']) {
			expect(compatibility).toContain(term)
		}
		for (const slug of agentSlugs) {
			const markdown = read(`docs/wordpress/${slug}.md`)
			expect(markdown, slug).toContain('live OAuth compatibility')
			expect(markdown, slug).toContain('untested in this review')
			expect(markdown, slug).toContain('November 15, 2026')
		}
	})

	it('connects reader journeys through article content, not just navigation or related cards', () => {
		const journeys = [
			['blog/best-wordpress-ai-plugins-2026', '/docs/wordpress/connect-agent/'],
			['blog/best-wordpress-ai-plugins-2026', '/docs/integrations/wordpress/#installation'],
			['blog/best-wordpress-ai-plugins-2026', '/blog/best-wordpress-visual-website-builders/'],
			['blog/ai-agent-wordpress-plugin-comparison', '/docs/wordpress/connect-agent/#1-connect-your-wordpress-site'],
			['blog/ai-agent-wordpress-plugin-comparison', '/docs/integrations/wordpress/#use-the-frontman-editor'],
			['blog/best-wordpress-mcp-servers-and-plugins-2026', '/docs/wordpress/permissions/#wordpress-permissions'],
			['blog/best-wordpress-mcp-servers-and-plugins-2026', '/docs/wordpress/woocommerce-products/'],
			['blog/best-wordpress-ai-plugins-2026', '/docs/wordpress/seo-metadata/'],
			['blog/autonomyai-wordpress-redesign-case-study', '/docs/wordpress/elementor/'],
			['blog/how-to-make-wordpress-website-mobile-friendly', '/docs/wordpress/gutenberg/'],
			['blog/wordpress-maintenance-checklist', '/docs/wordpress/permissions/#revoke-the-wordpress-credential'],
			['blog/astra-theme-customization', '/blog/best-wordpress-themes-small-business/'],
			['blog/how-to-make-elementor-website-faster', '/blog/play-video-on-scroll-elementor-with-frontman/'],
			['blog/play-video-on-scroll-elementor-with-frontman', '/docs/integrations/wordpress/#confirmation-and-rollback'],
			['blog/how-to-edit-wordpress-header-footer', '/docs/integrations/wordpress/#use-the-frontman-editor'],
			['blog/autonomyai-wordpress-redesign-case-study', '/docs/integrations/wordpress/#use-the-frontman-editor'],
			['blog/how-to-make-wordpress-website-mobile-friendly', '/docs/integrations/wordpress/#confirmation-and-rollback'],
			['blog/lighthouse-audits-without-leaving-the-browser', '/blog/how-to-make-elementor-website-faster/#diagnose-page-speed-and-choose-one-change'],
			['docs/integrations/wordpress', '/blog/how-to-edit-wordpress-header-footer/'],
			['docs/integrations/wordpress', '/blog/how-to-make-wordpress-website-mobile-friendly/'],
			['docs/integrations/wordpress', '/blog/how-to-make-elementor-website-faster/'],
			['docs/api-keys', '/docs/wordpress/connect-agent/'],
			['docs/installation', '/docs/wordpress/connect-agent/#3-check-access-without-edits'],
			['docs/installation', '/docs/wordpress/permissions/#revoke-the-wordpress-credential'],
			['docs/installation', '/blog/frontman-openclaw-skill/'],
			['docs/reference/troubleshooting', '/docs/wordpress/troubleshooting/'],
		]
		for (const [source, href] of journeys) {
			const body = documentFor(source).querySelector('.sl-markdown-content, .post-body')
			const anchor = body?.querySelector(`a[href="${href}"]`)
			expect(anchor, `${source} → ${href}`).not.toBeNull()
			expect(anchor?.textContent?.trim().length).toBeGreaterThan(10)
			const target = new URL(href, 'https://frontman.sh')
			const destination = documentFor(target.pathname.replace(/^\/|\/$/g, ''))
			if (target.hash) {
				expect(destination.getElementById(decodeURIComponent(target.hash.slice(1))), href).not.toBeNull()
			}
		}
	})
})
