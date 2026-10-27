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
		{ name: 'WordPress', link: '/' },
		{
			name: 'Product',
			submenu: [
				{ name: 'WordPress features', link: '/features/' },
				{ name: 'How it works', link: '/how-it-works/' },
				{ name: 'Customer story', link: '/blog/autonomyai-wordpress-redesign-case-study/' }
			]
		},
		{
			name: 'Pricing',
			link: '/pricing/'
		},
		{
			name: 'Resources',
			submenu: [
				{ name: 'WordPress setup', link: '/docs/integrations/wordpress/' },
				{ name: 'Documentation', link: '/docs/' },
				{ name: 'Compare tools', link: '/vs/' },
				{ name: 'vs OpenClaw', link: '/vs/openclaw/' },
				{ name: 'Blog', link: '/blog/' },
				{ name: 'Changelog', link: '/changelog/' },
				{ name: 'FAQ', link: '/faq/' }
			]
		},
		{
			name: 'For frameworks',
			link: '/frameworks/',
			submenu: [
				{ name: 'Framework overview', link: '/frameworks/' },
				{ name: 'Marketing and design teams', link: '/marketing-teams/' },
				{ name: 'Designers', link: '/use-cases/designers/' },
				{ name: 'Frontend developers', link: '/use-cases/frontend-developers/' }
			]
		}
	],
	navActions: [{ name: 'Install plugin', link: 'https://wordpress.org/plugins/frontman-agentic-ai-editor/', style: 'white', size: 'lg' }]
}
