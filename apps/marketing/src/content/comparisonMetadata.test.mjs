import {describe, expect, it} from 'vitest'
import {readdir, readFile} from 'node:fs/promises'
import {resolve} from 'node:path'
import {comparisonReviewCheckedAt} from './frontmanFacts.ts'

const comparisonDirectory = resolve(import.meta.dirname, '../pages/vs')

describe('comparison review metadata', () => {
  it('declares a review date and primary sources for every detailed comparison', async () => {
    const filenames = (await readdir(comparisonDirectory))
      .filter((filename) => filename.endsWith('.astro') && filename !== 'index.astro')

    expect(filenames).toHaveLength(10)
    for (const filename of filenames) {
      const content = await readFile(resolve(comparisonDirectory, filename), 'utf8')
      const review = content.match(/const review: ComparisonReview = \{([\s\S]*?)\n\}/)?.[1]
      const reviewSources = content.match(/createComparisonReview\(\[([\s\S]*?)\]\)/)?.[1]
      const sourceUrls = review?.match(/url:\s*['"]https:\/\/[^'"]+['"]/g) ?? []

      expect(review, `${filename}: review`).toBeDefined()
      expect(content, `${filename}: shared checkedAt`).not.toContain(`checkedAt: '${comparisonReviewCheckedAt}'`)
      expect(review, `${filename}: shared review helper`).toContain('createComparisonReview')
      expect(sourceUrls.length, `${filename}: competitor sources`).toBeGreaterThanOrEqual(1)
      expect(reviewSources, `${filename}: competitor source block`).toBeDefined()
      expect(content, `${filename}: layout review prop`).toMatch(/<ComparisonLayout[\s\S]*?review=\{review\}/)
    }
  })
})
