export const articleSections = [
	'Problem Diagnosis',
	'Product Announcement',
	'Case Study',
	'Tutorial',
	'Comparison or Buyer Guide',
	'Technical Explainer',
	'Operational Audit'
] as const

export const authors = {
	'Danni Friedland': {
		firstName: 'Danni',
		lastName: 'Friedland',
		slug: 'danni-friedland',
		role: 'Co-founder, Frontman',
		shortRole: 'Co-founder of Frontman',
		location: 'Berlin, Germany',
		bio: 'Co-founder of Frontman. Previously founded Walnut Inc, a category leader in sales tech. Focused on developer tools and the intersection of AI and frontend engineering.',
		title: 'Danni Friedland: Frontman Co-founder and Author',
		description:
			'Danni Friedland writes about browser-aware AI agents, frontend engineering, developer tools, and runtime context at Frontman.',
		url: '/authors/danni-friedland/',
		absoluteUrl: 'https://frontman.sh/authors/danni-friedland/',
		github: 'https://github.com/BlueHotDog',
		linkedin: 'https://www.linkedin.com/in/dannifriedland/',
		twitter: 'https://twitter.com/dannifriedland',
		knowsAbout: [
			'Browser-aware AI agents',
			'Frontend engineering',
			'Developer tools',
			'Model Context Protocol',
			'Web application analytics'
		]
	},
	'Itay Adler': {
		firstName: 'Itay',
		lastName: 'Adler',
		slug: 'itay-adler',
		role: 'Co-founder, Frontman',
		shortRole: 'Co-founder of Frontman',
		location: 'Israel',
		bio: 'Co-founder of Frontman. Background in full-stack engineering and product development. Focused on making AI tools that understand running applications, not just source files.',
		title: 'Itay Adler: Frontman Co-founder and Author',
		description:
			'Itay Adler writes about WordPress, product development, full-stack engineering, and AI tools that understand running applications.',
		url: '/authors/itay-adler/',
		absoluteUrl: 'https://frontman.sh/authors/itay-adler/',
		github: 'https://github.com/itayadler',
		linkedin: 'https://www.linkedin.com/in/itay-adler-93a4bb6/',
		twitter: 'https://twitter.com/itayad',
		knowsAbout: [
			'WordPress',
			'Full-stack engineering',
			'Product development',
			'AI-assisted development tools'
		]
	}
} as const

export const authorNames = Object.keys(authors) as [keyof typeof authors, ...Array<keyof typeof authors>]

export const getAuthor = (name: keyof typeof authors) => authors[name]
