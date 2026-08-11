import {describe, expect, it} from 'vitest'
import {countArticleWords} from './wordCount.mjs'

describe('countArticleWords', () => {
	it('counts visible copy without raw HTML markup or attributes', () => {
		const body = '<video controls poster="demo-poster.webp"><source src="demo.mp4" type="video/mp4"></video> Visible copy'

		expect(countArticleWords(body)).toBe(2)
	})
})
