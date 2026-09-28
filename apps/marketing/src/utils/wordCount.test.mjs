import {describe, expect, it} from 'vitest'
import {countArticleWords} from './wordCount.mjs'

describe('countArticleWords', () => {
	it('counts visible copy without raw HTML markup or attributes', () => {
		const body = '<video controls poster="demo-poster.webp"><source src="demo.mp4" type="video/mp4"></video> Visible copy'

		expect(countArticleWords(body)).toBe(2)
	})

	it('includes the rendered FAQ heading, questions, and answers', () => {
		const faq = [
			{
				question: 'Can I maintain it?',
				answer: 'Yes, carefully.'
			}
		]

		expect(countArticleWords('Visible copy', faq)).toBe(9)
	})
})
