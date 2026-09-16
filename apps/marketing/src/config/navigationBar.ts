export interface Logo {
	src: string
	alt: string
	text: string
}

export interface NavSubItem {
	name: string
	link: string
}

export interface NavMenuColumn {
	label: string
	items: NavSubItem[]
}

export interface NavMegaMenu {
	columns: NavMenuColumn[]
}

export interface NavItem {
	name: string
	link?: string
	submenu?: NavSubItem[]
	megaMenu?: NavMegaMenu
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
			name: 'Product',
			megaMenu: {
				columns: [
					{
						label: 'Website builder',
						items: [
							{ name: 'WordPress', link: '/wordpress/' },
							{ name: 'Next.js', link: '/docs/integrations/nextjs/' },
							{ name: 'Astro', link: '/docs/integrations/astro/' },
							{ name: 'Vite', link: '/docs/integrations/vite/' }
						]
					},
					{
						label: 'Use cases',
						items: [
							{ name: 'Marketing teams', link: '/marketing-teams/' },
							{ name: 'Designers', link: '/use-cases/designers/' },
							{ name: 'Frontend developers', link: '/use-cases/frontend-developers/' }
						]
					}
				]
			}
		},
		{
			name: 'Compare',
			link: '/vs/',
			submenu: [
				{ name: 'All comparisons', link: '/vs/' },
				{ name: 'vs OpenClaw', link: '/vs/openclaw/' },
				{ name: 'vs Cursor', link: '/vs/cursor/' },
				{ name: 'vs Copilot', link: '/vs/copilot/' },
				{ name: 'vs Stagewise', link: '/vs/stagewise/' },
				{ name: 'vs v0', link: '/vs/v0/' }
			]
		},
		{
			name: 'Resources',
			submenu: [
				{ name: 'Documentation', link: '/docs/' },
				{ name: 'Blog', link: '/blog/' },
				{ name: 'Changelog', link: '/changelog/' },
				{ name: 'FAQ', link: '/faq/' }
			]
		}
	],
	navActions: [{ name: 'Try it now', link: '/#install', style: 'white', size: 'lg' }]
}
