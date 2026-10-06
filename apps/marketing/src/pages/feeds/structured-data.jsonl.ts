import type { APIRoute } from 'astro'
import { legalInfo } from '../../data/legalInfo'

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
			email: legalInfo.supportEmail,
			contactType: 'customer support',
		},
	},
	{
		'@context': 'https://schema.org',
		'@type': 'Service',
		name: 'Frontman Pro',
		serviceType: 'AI website editor',
		description: 'Ship updates to existing WordPress sites faster with native CMS tools beside live preview. WordPress writes persist immediately to the connected installation. Next.js, Astro, and Vite require development setup and developer review, testing, and deployment. Sign-in, service access, and separate AI-provider access and costs apply.',
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
