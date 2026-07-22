import {describe, expect, it} from 'vitest'
import {readdir, readFile} from 'node:fs/promises'
import {resolve} from 'node:path'
import sharp from 'sharp'

const blogDirectory = resolve(import.meta.dirname, 'blog')
const publicDirectory = resolve(import.meta.dirname, '../../public')
const articleSections = new Set([
  'Problem Diagnosis',
  'Product Announcement',
  'Tutorial',
  'Comparison or Buyer Guide',
  'Technical Explainer',
  'Operational Audit',
])
const authors = {
  'Danni Friedland': {
    role: 'Co-founder, Frontman',
    url: '/authors/danni-friedland/',
  },
  'Itay Adler': {
    role: 'Co-founder, Frontman',
    url: '/authors/itay-adler/',
  },
}

const scalar = (frontmatter, key) => {
  const match = frontmatter.match(new RegExp(`^${key}:\\s*(.+)$`, 'm'))
  return match?.[1].trim().replace(/^(['"])(.*)\1$/, '$2')
}

const loadPosts = async () => {
  const filenames = (await readdir(blogDirectory)).filter((filename) => filename.endsWith('.md'))

  return Promise.all(filenames.map(async (filename) => {
    const content = await readFile(resolve(blogDirectory, filename), 'utf8')
    const frontmatter = content.split('---', 3)[1]
    return {filename, frontmatter}
  }))
}

describe('blog metadata', () => {
  it('uses canonical authors and explicit article sections', async () => {
    const posts = await loadPosts()

    expect(posts).toHaveLength(40)
    for (const {filename, frontmatter} of posts) {
      const author = scalar(frontmatter, 'author')
      const canonicalAuthor = authors[author]

      expect(canonicalAuthor, `${filename}: author`).toBeDefined()
      expect(scalar(frontmatter, 'authorRole'), `${filename}: authorRole`).toBe(canonicalAuthor?.role)
      expect(scalar(frontmatter, 'authorUrl'), `${filename}: authorUrl`).toBe(canonicalAuthor?.url)
      expect(articleSections.has(scalar(frontmatter, 'articleSection')), `${filename}: articleSection`).toBe(true)
    }
  })

  it('declares accurate metadata for every cover image', async () => {
    const posts = await loadPosts()

    for (const {filename, frontmatter} of posts) {
      const image = scalar(frontmatter, 'image')
      const imageAlt = scalar(frontmatter, 'imageAlt')
      const imageWidth = Number(scalar(frontmatter, 'imageWidth'))
      const imageHeight = Number(scalar(frontmatter, 'imageHeight'))
      const metadata = await sharp(resolve(publicDirectory, image.replace(/^\//, ''))).metadata()

      expect(imageAlt?.length, `${filename}: imageAlt`).toBeGreaterThan(10)
      expect(imageWidth, `${filename}: imageWidth`).toBe(1200)
      expect(imageHeight, `${filename}: imageHeight`).toBe(450)
      expect(imageWidth, `${filename}: imageWidth`).toBe(metadata.width)
      expect(imageHeight, `${filename}: imageHeight`).toBe(metadata.height)
    }
  })
})
