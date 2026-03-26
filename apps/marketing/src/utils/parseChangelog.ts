import fs from 'node:fs'
import path from 'node:path'
import { marked } from 'marked'

export interface ChangelogEntry {
  title: string
  date: string
  text: string
}

/**
 * Enhance link accessibility by adding aria-labels to non-descriptive links
 * and fix incorrectly auto-linked email addresses
 */
function enhanceLinkAccessibility(html: string): string {
  // Add aria-label for PR links like #426
  html = html.replace(
    /<a href="(https:\/\/github\.com\/[^"]+\/pull\/(\d+))">#(\d+)<\/a>/g,
    '<a href="$1" aria-label="Pull request $2">#$3</a>'
  )

  // Add aria-label for commit hash links
  html = html.replace(
    /<a href="(https:\/\/github\.com\/[^"]+\/commit\/[^"]+)"><code>([a-f0-9]+)<\/code><\/a>/g,
    '<a href="$1" aria-label="Commit $2"><code>$2</code></a>'
  )

  // Fix incorrectly auto-linked package version references like bindings@0.3.0
  // marked converts these to mailto: links which is incorrect
  html = html.replace(
    /<a href="mailto:([^"]+@[\d.]+)">([^<]+)<\/a>/g,
    '<code>$2</code>'
  )

  return html
}

/**
 * Adjust heading levels for proper hierarchy.
 * Since feed item header is h2, markdown h3 becomes h3, h4 becomes h4, etc.
 * The changeset markdown has ### for "Minor Changes" and #### for package names.
 * We swap h3 <-> h4 so package names become h3 (first) and categories become h4.
 * 
 * Also converts nested headings (inside list items) like "### Added" and "### Changed"
 * to strong tags to avoid heading hierarchy issues.
 */
function normalizeHeadingLevels(html: string): string {
  // First, convert nested headings inside list items to strong tags
  // These are "### Added", "### Changed" etc. inside changeset descriptions
  html = html.replace(/<h3>(Added|Changed|Fixed|Removed|Deprecated|Security)<\/h3>/g, '<p><strong>$1</strong></p>')

  // Swap h3 <-> h4 using placeholder to avoid double-swap
  html = html.replace(/<h3>/g, '<h3-temp>')
  html = html.replace(/<\/h3>/g, '</h3-temp>')
  html = html.replace(/<h4>/g, '<h3>')
  html = html.replace(/<\/h4>/g, '</h3>')
  html = html.replace(/<h3-temp>/g, '<h4>')
  html = html.replace(/<\/h3-temp>/g, '</h4>')

  return html
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

    let html = marked.parse(body, { async: false }) as string
    html = normalizeHeadingLevels(html)
    html = enhanceLinkAccessibility(html)

    entries.push({
      title: `v${version}`,
      date,
      text: html,
    })
  }

  return entries
}
