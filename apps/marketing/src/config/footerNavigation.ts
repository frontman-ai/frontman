// Footer Navigation
// ------------
// Description: The footer navigation data for the website.
export interface Logo {
	src: string
	alt: string
	text: string
}

export interface FooterAbout {
	title: string
	aboutText: string
	logo: Logo
}

export interface SubCategory {
	subCategory: string
	subCategoryLink: string
	external?: boolean
}

export interface FooterColumn {
	category: string
	subCategories: SubCategory[]
}

export interface SubFooterLink {
	label: string
	href: string
}

export interface SubFooter {
	copywriteText: string
	links: SubFooterLink[]
}

export interface FooterData {
	footerAbout: FooterAbout
	footerColumns: FooterColumn[]
	subFooter: SubFooter
}

export const footerNavigationData: FooterData = {
	footerAbout: {
		title: 'Frontman',
		aboutText:
			"Frontman lets you skip the 'refresh and check' cycle and brings non-coding teammates into the workflow.",
		logo: {
			src: '/logo.svg',
			alt: 'Frontman logo',
			text: 'Frontman'
		}
	},
	footerColumns: [
		{
			category: 'Product',
			subCategories: [
				{
					subCategory: 'About',
					subCategoryLink: '/about/'
				},
				{
					subCategory: 'How It Works',
					subCategoryLink: '/how-it-works/'
				},
				{
					subCategory: 'Features',
					subCategoryLink: '/features/'
				},
				{
					subCategory: 'Pricing',
					subCategoryLink: '/pricing/'
				},
				{
					subCategory: 'Design System',
					subCategoryLink: '/design-system/'
				},
				{
					subCategory: 'Changelog',
					subCategoryLink: '/changelog/'
				},
				{
					subCategory: 'FAQ',
					subCategoryLink: '/faq/'
				},
				{
					subCategory: 'Contact',
					subCategoryLink: '/contact/'
				}
			]
		},
		{
			category: 'Integrations',
			subCategories: [
				{
					subCategory: 'All Integrations',
					subCategoryLink: '/integrations/'
				},
				{
					subCategory: 'Next.js',
					subCategoryLink: '/integrations/nextjs/'
				},
				{
					subCategory: 'Astro',
					subCategoryLink: '/integrations/astro/'
				},
				{
					subCategory: 'Vite (React, Vue, Svelte)',
					subCategoryLink: '/integrations/vite/'
				}
			]
		},
		{
			category: 'Compare',
			subCategories: [
				{
					subCategory: 'All Comparisons',
					subCategoryLink: '/vs/'
				},
				{
					subCategory: 'Frontman vs Cursor',
					subCategoryLink: '/vs/cursor/'
				},
				{
					subCategory: 'Frontman vs Copilot',
					subCategoryLink: '/vs/copilot/'
				},
				{
					subCategory: 'Frontman vs Stagewise',
					subCategoryLink: '/vs/stagewise/'
				},
				{
					subCategory: 'Frontman vs v0',
					subCategoryLink: '/vs/v0/'
				}
			]
		},
		{
			category: 'Resources',
			subCategories: [
				{
					subCategory: 'Use Case: Designers',
					subCategoryLink: '/use-cases/designers/'
				},
				{
					subCategory: 'Use Case: Frontend Developers',
					subCategoryLink: '/use-cases/frontend-developers/'
				},
				{
					subCategory: 'AI Releases',
					subCategoryLink: '/open-source-ai-releases/'
				}
			]
		},
		{
			category: 'Developers',
			subCategories: [
				{
					subCategory: 'Documentation',
					subCategoryLink: '/docs/'
				},
				{
					subCategory: 'Reference',
					subCategoryLink: '/docs/reference/'
				},
				{
					subCategory: 'GitHub',
					subCategoryLink: 'https://github.com/frontman-ai/frontman',
					external: true
				},
				{
					subCategory: 'Contributing',
					subCategoryLink: 'https://github.com/frontman-ai/frontman/blob/main/CONTRIBUTING.md',
					external: true
				},
				{
					subCategory: 'Licenses (Apache 2.0 client / AGPL-3.0 server)',
					subCategoryLink: 'https://github.com/frontman-ai/frontman/blob/main/LICENSE',
					external: true
				}
			]
		},
		{
			category: 'Community',
			subCategories: [
				{
					subCategory: 'Discord',
					subCategoryLink: 'https://discord.gg/xk8uXJSvhC',
					external: true
				},
				{
					subCategory: 'Twitter/X',
					subCategoryLink: 'https://twitter.com/frontman_agent',
					external: true
				},
				{
					subCategory: 'Blog',
					subCategoryLink: '/blog/'
				}
			]
		}
	],
	subFooter: {
		copywriteText: `© ${new Date().getFullYear()} Frontman. All rights reserved.`,
		links: [
			{ label: 'Terms of Service', href: '/terms/' },
			{ label: 'Privacy Policy', href: '/privacy/' }
		]
	}
}
