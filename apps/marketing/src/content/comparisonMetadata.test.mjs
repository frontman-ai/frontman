import {describe, expect, it} from 'vitest'
import {readdir, readFile} from 'node:fs/promises'
import {resolve} from 'node:path'

const comparisonDirectory = resolve(import.meta.dirname, '../pages/vs')

describe('comparison review metadata', () => {
  it('declares a review date and primary sources for every detailed comparison', async () => {
    const filenames = (await readdir(comparisonDirectory))
      .filter((filename) => filename.endsWith('.astro') && filename !== 'index.astro')

    expect(filenames).toHaveLength(10)
    for (const filename of filenames) {
      const content = await readFile(resolve(comparisonDirectory, filename), 'utf8')
      const review = content.match(/const review: ComparisonReview = \{([\s\S]*?)\n\}/)?.[1]
      const sourceUrls = review?.match(/url:\s*['"]https:\/\/[^'"]+['"]/g) ?? []

      expect(review, `${filename}: review`).toBeDefined()
      expect(review, `${filename}: checkedAt`).toMatch(/checkedAt:\s*['"]\d{4}-\d{2}-\d{2}['"]/)
      expect(sourceUrls.length, `${filename}: sources`).toBeGreaterThanOrEqual(2)
      expect(content, `${filename}: layout review prop`).toMatch(/<ComparisonLayout[\s\S]*?review=\{review\}/)
    }
  })
})
