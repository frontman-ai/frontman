import fs from 'node:fs'
import path from 'node:path'
import { marked } from 'marked'

export interface ChangelogEntry {
  title: string
  date: string
  text: string
}

export function parseChangelog(): ChangelogEntry[] {
  const changelogPath = path.resolve(
    import.meta.dirname,
    '../../../../CHANGELOG.md'
  )
  const raw = fs.readFileSync(changelogPath, 'utf-8')

  const entries: ChangelogEntry[] = []
  // Match ## [version] - date headings
  const sectionRegex = /^## \[(.+?)\]\s*-\s*(\d{4}-\d{2}-\d{2})/gm
  const matches = [...raw.matchAll(sectionRegex)]

  for (let i = 0; i < matches.length; i++) {
    const match = matches[i]
    const version = match[1]
    const date = match[2]

    // Extract body between this heading and the next (or end of file)
    const start = match.index! + match[0].length
    const end = i + 1 < matches.length ? matches[i + 1].index! : raw.length
    const body = raw.slice(start, end).trim()

    const html = marked.parse(body, { async: false }) as string

    entries.push({
      title: `v${version}`,
      date,
      text: html,
    })
  }

  return entries
}
