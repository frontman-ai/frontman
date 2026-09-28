import {describe, expect, it} from 'vitest'
import {readFile} from 'node:fs/promises'
import {resolve} from 'node:path'

const marketingRoot = resolve(import.meta.dirname, '../..')
const readMarketingFile = (path) => readFile(resolve(marketingRoot, path), 'utf8')

describe('site audit regressions', () => {
  it('prevents Cloudflare from replacing support links with broken protection URLs', async () => {
    const headers = await readMarketingFile('public/_headers')

    expect(headers).toMatch(/\/contact\/\*\s+Cache-Control: no-transform/)
    expect(headers).toMatch(/\/editorial-policy\/\*\s+Cache-Control: no-transform/)
  })

  it('gives the models reference an indexable search description', async () => {
    const models = await readMarketingFile('src/content/docs/docs/reference/models.md')
    const description = models.match(/^description:\s*(.+)$/m)?.[1]

    expect(description?.length).toBeGreaterThanOrEqual(120)
    expect(description?.length).toBeLessThanOrEqual(160)
  })

  it('links discoverable hubs and priority pages from relevant site sections', async () => {
    const [blogIndex, footer, navigation, releasesRoute] = await Promise.all([
      readMarketingFile('src/pages/blog/index.astro'),
      readMarketingFile('src/config/footerNavigation.ts'),
      readMarketingFile('src/config/navigationBar.ts'),
      readMarketingFile('src/pages/open-source-ai-releases/[...id].astro'),
    ])

    expect(blogIndex).toContain('/blog/tags/')
    expect(footer).toContain("subCategoryLink: '/blog/tags/'")
    expect(footer).not.toContain("subCategoryLink: '/pricing/'")
    expect(navigation).toContain("link: '/vs/openclaw/'")
    expect(releasesRoute).toContain('relatedReleases')
  })

  it('does not claim Google software rich-result eligibility without review data', async () => {
    const [globalSchema, wordpressPage, structuredDataFeed, schemaMap] = await Promise.all([
      readMarketingFile('src/components/blocks/head/partials/StructuredData.astro'),
      readMarketingFile('src/pages/wordpress.astro'),
      readMarketingFile('src/pages/feeds/structured-data.jsonl.ts'),
      readMarketingFile('src/pages/schema-map.xml.ts'),
    ])

    expect(globalSchema).not.toContain('"@type": "SoftwareApplication"')
    expect(wordpressPage).not.toContain("'@type': 'SoftwareApplication'")
    expect(structuredDataFeed).not.toContain("'@type': 'SoftwareApplication'")
    expect(schemaMap).not.toContain('SoftwareApplication')
  })
})
