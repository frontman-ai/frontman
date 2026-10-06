import { expect, test } from 'vitest'
import { onRequest } from '../../functions/_middleware'

test('agent mode serves route-specific JSON and leaves other requests unchanged', async () => {
	for (const [path, canonical, description] of [
		['/', 'https://frontman.sh/', 'WordPress'],
		['/frameworks', 'https://frontman.sh/frameworks/', 'Next.js'],
		['/frameworks/', 'https://frontman.sh/frameworks/', 'Next.js'],
	]) {
		const response = await onRequest({
			request: new Request(`https://frontman.sh${path}?mode=agent`),
			next: async () => { throw new Error('Agent request fell through to static HTML') },
		})
		expect(response.headers.get('Content-Type')).toContain('application/json')
		const body = await response.json()
		expect(body.canonicalUrl).toBe(canonical)
		expect(body.description).toContain(description)
	}
	for (const path of ['/', '/frameworks/', '/docs/?mode=agent', '/frameworks/?mode=other']) {
		const html = new Response('static HTML')
		expect(await onRequest({
			request: new Request(`https://frontman.sh${path}`),
			next: async () => html,
		})).toBe(html)
	}
})
