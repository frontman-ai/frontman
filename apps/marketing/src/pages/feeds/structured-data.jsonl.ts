import type { APIRoute } from 'astro'

const origin = new URL(import.meta.env.SITE).origin

const records = [
	{
		'@context': 'https://schema.org',
		'@type': 'Organization',
		name: 'Frontman',
		url: `${origin}/`,
		logo: `${origin}/logo.svg`,
		contactPoint: {
			'@type': 'ContactPoint',
			email: 'hello@frontman.sh',
			contactType: 'customer support',
		},
	},
	{
		'@context': 'https://schema.org',
		'@type': 'SoftwareApplication',
		name: 'Frontman',
		applicationCategory: 'DeveloperApplication',
		operatingSystem: 'Web, macOS, Windows, Linux',
	},
	{
		'@context': 'https://schema.org',
		'@type': 'Service',
		name: 'Frontman Pro',
		serviceType: 'AI frontend coding agent',
		provider: { '@type': 'Organization', name: 'Frontman', url: `${origin}/` },
		areaServed: 'Worldwide',
	},
]

export const GET: APIRoute = () => {
	return new Response(records.map((record) => JSON.stringify(record)).join('\n') + '\n', {
		headers: {
			'Content-Type': 'application/x-ndjson; charset=utf-8',
		},
	})
}

export const prerender = true
