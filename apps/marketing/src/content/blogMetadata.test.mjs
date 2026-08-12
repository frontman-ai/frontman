import {describe, expect, it} from 'vitest'
import {readdir, readFile} from 'node:fs/promises'
import {resolve} from 'node:path'
import sharp from 'sharp'
import {articleSections, authors} from './authors.ts'
import {blogImageHeight, blogImageWidth} from './frontmanFacts.ts'

const blogDirectory = resolve(import.meta.dirname, 'blog')
const publicDirectory = resolve(import.meta.dirname, '../../public')
const validArticleSections = new Set(articleSections)

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

		expect(posts.map(({filename}) => filename)).toContain(
			'wordpress-7-1-new-features-breaking-changes.md'
		)
		for (const {filename, frontmatter} of posts) {
      const author = scalar(frontmatter, 'author')
      const canonicalAuthor = authors[author]

      expect(canonicalAuthor, `${filename}: author`).toBeDefined()
      expect(scalar(frontmatter, 'authorRole'), `${filename}: authorRole`).toBeUndefined()
      expect(scalar(frontmatter, 'authorUrl'), `${filename}: authorUrl`).toBeUndefined()
      expect(validArticleSections.has(scalar(frontmatter, 'articleSection')), `${filename}: articleSection`).toBe(true)
    }
  })

  it('declares accurate metadata for every cover image', async () => {
    const posts = await loadPosts()

    for (const {filename, frontmatter} of posts) {
      const image = scalar(frontmatter, 'image')
      const imageAlt = scalar(frontmatter, 'imageAlt')
      const metadata = await sharp(resolve(publicDirectory, image.replace(/^\//, ''))).metadata()

      expect(imageAlt?.length, `${filename}: imageAlt`).toBeGreaterThan(10)
      expect(scalar(frontmatter, 'imageWidth'), `${filename}: imageWidth`).toBeUndefined()
      expect(scalar(frontmatter, 'imageHeight'), `${filename}: imageHeight`).toBeUndefined()
      expect(blogImageWidth, `${filename}: imageWidth`).toBe(metadata.width)
      expect(blogImageHeight, `${filename}: imageHeight`).toBe(metadata.height)
    }
  })
})
