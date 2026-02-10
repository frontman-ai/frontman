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

export interface SubFooter {
	copywriteText: string
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
					subCategory: 'Changelog',
					subCategoryLink: '/changelog'
				},
				{
					subCategory: 'FAQ',
					subCategoryLink: '/faq'
				}
			]
		},
		{
			category: 'Developers',
			subCategories: [
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
					subCategory: 'License (Apache 2.0)',
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
					subCategoryLink: 'https://discord.gg/J77jBzMM',
					external: true
				},
				{
					subCategory: 'Twitter/X',
					subCategoryLink: 'https://twitter.com/frontman_agent',
					external: true
				},
				{
					subCategory: 'Blog',
					subCategoryLink: '/blog'
				}
			]
		}
	],
	subFooter: {
		copywriteText: `© ${new Date().getFullYear()} Frontman. All rights reserved.`
	}
}
