// Config
// ------------
// Description: The configuration file for the website.

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
	siteTitle: 'Frontman | AI Frontend Editing Directly in Your Browser',
	siteDescription:
		'Frontman lets you skip the "refresh and check" cycle and brings non-coding teammates into the workflow.',
	ogImage: '/og.png',
	logo: {
		src: '/logo.svg',
		alt: 'Frontman logo'
	},
	canonical: true,
	noindex: false,
	mode: 'dark'
}
