import { marked } from 'marked'
import changelogRaw from '../../../../CHANGELOG.md?raw'

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
  html = html.replace(
    /<a href="(https:\/\/github\.com\/[^"]+\/pull\/(\d+))">#(\d+)<\/a>/g,
    '<a href="$1" aria-label="Pull request $2">#$3</a>'
  )

  html = html.replace(
    /<a href="(https:\/\/github\.com\/[^"]+\/commit\/[^"]+)"><code>([a-f0-9]+)<\/code><\/a>/g,
    '<a href="$1" aria-label="Commit $2"><code>$2</code></a>'
  )

  html = html.replace(
    /<a href="mailto:([^"]+@[\d.]+)">([^<]+)<\/a>/g,
    '<code>$2</code>'
  )

  return html
}

function preventCloudflareEmailObfuscation(html: string): string {
  return html.replace(
    /((?:@[\w-]+\/)?[\w.-]+)@(\d+(?:\.\d+){1,3}(?:-[\w.-]+)?)/g,
    '$1&#64;$2'
  )
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
  html = html.replace(/<h3>(Added|Changed|Fixed|Removed|Deprecated|Security)<\/h3>/g, '<p><strong>$1</strong></p>')

  html = html.replace(/<h3>/g, '<h3-temp>')
  html = html.replace(/<\/h3>/g, '</h3-temp>')
  html = html.replace(/<h4>/g, '<h3>')
  html = html.replace(/<\/h4>/g, '</h3>')
  html = html.replace(/<h3-temp>/g, '<h4>')
  html = html.replace(/<\/h3-temp>/g, '</h4>')

  return html
}

export function parseChangelog(): ChangelogEntry[] {
  const raw = changelogRaw

  const entries: ChangelogEntry[] = []
  const sectionRegex = /^## \[(.+?)\]\s*-\s*(\d{4}-\d{2}-\d{2})/gm
  const matches = [...raw.matchAll(sectionRegex)]

  for (let i = 0; i < matches.length; i++) {
    const match = matches[i]
    const version = match[1]
    const date = match[2]

    const start = match.index! + match[0].length
    const end = i + 1 < matches.length ? matches[i + 1].index! : raw.length
    const body = raw.slice(start, end).trim()

    let html = marked.parse(body, { async: false }) as string
    html = normalizeHeadingLevels(html)
    html = enhanceLinkAccessibility(html)
    html = preventCloudflareEmailObfuscation(html)

    entries.push({
      title: `v${version}`,
      date,
      text: html,
    })
  }

  return entries
}
