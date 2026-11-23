import {execFile} from 'node:child_process'
import {mkdtemp, rm} from 'node:fs/promises'
import {basename, join, resolve} from 'node:path'
import {promisify} from 'node:util'
import sharp from 'sharp'
import {describe, expect, it} from 'vitest'
import {blogImageHeight, blogImageWidth} from '../src/content/frontmanFacts.ts'

const run = promisify(execFile)
const root = resolve(import.meta.dirname, '..')
const satori035Covers = [
  {
    title: 'AI Editing for WordPress',
    logo: [560, 148, 637, 219],
    text: [355, 263, 843, 302],
    textPixels: 2038,
  },
  {
    title: 'Agent Client Protocol: Building an Agentic Harness',
    logo: [560, 152, 637, 223],
    text: [156, 265, 1040, 299],
    textPixels: 3091,
  },
  {
    title: 'Best AI Tools for UI/UX Designers in 2026: Figma Make, UX Pilot, Uizard, Stitch, Frontman',
    logo: [560, 134, 637, 205],
    text: [157, 245, 1043, 312],
    textPixels: 3318,
  },
]

const foreground = (data, info, startY, endY) => {
  let left = info.width
  let top = info.height
  let right = -1
  let bottom = -1
  let pixels = 0
  for (let y = startY; y < endY; y++) {
    for (let x = 0; x < info.width; x++) {
      const offset = (y * info.width + x) * info.channels
      if (Math.min(data[offset], data[offset + 1], data[offset + 2]) > 230) {
        left = Math.min(left, x)
        top = Math.min(top, y)
        right = Math.max(right, x)
        bottom = Math.max(bottom, y)
        pixels++
      }
    }
  }
  return {bounds: [left, top, right, bottom], pixels}
}

describe('make blog-cover with real Satori, Sharp, Fredoka, and logo assets', () => {
  it.each(satori035Covers)('preserves the 0.35 layout for "$title"', async (baseline) => {
    const directory = await mkdtemp(join(root, 'public/blog/.cover-test-'))
    try {
      await run('make', [
        '-C', root, 'blog-cover',
        `TITLE=${baseline.title}`,
        `FILE=${basename(directory)}/cover`,
      ], {timeout: 20000})
      const image = sharp(join(directory, 'cover.png'))
      const metadata = await image.metadata()
      expect(metadata.format).toBe('png')
      expect([metadata.width, metadata.height]).toEqual([blogImageWidth, blogImageHeight])
      const {data, info} = await image.removeAlpha().raw().toBuffer({resolveWithObject: true})
      const logo = foreground(data, info, 80, 230)
      const text = foreground(data, info, 230, 400)
      for (const [actual, expected] of [[logo.bounds, baseline.logo], [text.bounds, baseline.text]]) {
        for (let i = 0; i < expected.length; i++) {
          expect(Math.abs(actual[i] - expected[i])).toBeLessThanOrEqual(4)
        }
      }
      expect(logo.pixels).toBeGreaterThan(1500)
      expect(text.pixels).toBeGreaterThan(baseline.textPixels * 0.9)
      const barColors = new Map()
      for (let y = blogImageHeight - 4; y < blogImageHeight; y++) {
        for (let x = 0; x < blogImageWidth; x++) {
          const offset = (y * info.width + x) * info.channels
          const color = data.subarray(offset, offset + 3).toString('hex')
          barColors.set(color, (barColors.get(color) ?? 0) + 1)
        }
      }
      expect([...barColors.keys()].sort()).toEqual(['1abcfe', '94d0cd', 'a259ff', 'efcf81', 'f24e1e'])
      expect([...barColors.values()]).toEqual(Array(5).fill(blogImageWidth * 4 / 5))
      const footer = await sharp(join(directory, 'cover.png'))
        .extract({left: 1090, top: 410, width: 90, height: 32})
        .stats()
      expect(footer.channels.every(channel => channel.max > 130)).toBe(true)
    } finally {
      await rm(directory, {recursive: true, force: true})
    }
  }, 30000)
})
