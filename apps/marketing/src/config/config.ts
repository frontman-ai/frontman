
export interface Logo {
	src: string
	alt: string
}

export type Mode = 'dark'

export interface Config {
	siteTitle: string
	siteDescription: string
	ogImage: string
	logo: Logo
	canonical: boolean
	noindex: boolean
	mode: Mode
}

export const configData: Config = {
	siteTitle: 'Frontman | WordPress AI Editor for Marketing Teams',
	siteDescription:
		'Make changes to your existing WordPress site without an agency handoff for every update. Describe the result, inspect the page, and refine it with Frontman.',
	ogImage: '/og.png',
	logo: {
		src: '/logo.svg',
		alt: 'Frontman logo'
	},
	canonical: true,
	noindex: false,
	mode: 'dark'
}
