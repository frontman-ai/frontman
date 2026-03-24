// Navigation Bar
// ------------
// Description: The navigation bar data for the website.
export interface Logo {
	src: string
	alt: string
	text: string
}

export interface NavSubItem {
	name: string
	link: string
}

export interface NavItem {
	name: string
	link: string
	submenu?: NavSubItem[]
}

export interface NavAction {
	name: string
	link: string
	style: string
	size: string
}

export interface NavData {
	logo: Logo
	navItems: NavItem[]
	navActions: NavAction[]
}

export const navigationBarData: NavData = {
	logo: {
		src: '/logo.svg',
		alt: 'Frontman logo',
		text: 'Frontman'
	},
	navItems: [
		{
			name: 'Compare',
			link: '/vs/',
			submenu: [
				{ name: 'vs Cursor', link: '/vs/cursor/' },
				{ name: 'vs Copilot', link: '/vs/copilot/' },
				{ name: 'vs Stagewise', link: '/vs/stagewise/' },
				{ name: 'vs v0', link: '/vs/v0/' }
			]
		},
		{
			name: 'Integrations',
			link: '/integrations/',
			submenu: [
				{ name: 'Next.js', link: '/integrations/nextjs/' },
				{ name: 'Astro', link: '/integrations/astro/' },
				{ name: 'Vite', link: '/integrations/vite/' }
			]
		},
		{ name: 'Changelog', link: '/changelog/' },
		{ name: 'Blog', link: '/blog/' },
		{ name: 'FAQ', link: '/faq/' }
	],
	navActions: [{ name: 'Try it now', link: '/#install', style: 'white', size: 'lg' }]
}
