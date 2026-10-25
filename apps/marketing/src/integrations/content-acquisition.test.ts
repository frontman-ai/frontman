import { readFileSync } from 'node:fs'
/// @ts-expect-error The installed JSDOM dependency does not ship type declarations.
import { JSDOM } from 'jsdom'
import { expect, test } from 'vitest'
import { createAnalyticsScript } from './analytics-consent.mjs'

const source = (path: string) => readFileSync(new URL(path, import.meta.url), 'utf8')
const pilots = [
  {
    slug: 'best-frontend-coding-agent',
    sections: ['frontend-buyer-quick-answer', 'frontend-buyer-article-end'],
    actions: [
      ['frontend_buyer_free_uses', 'quick_answer', 'framework_install', '/frameworks/#install', 'Try Frontman: five free uses, no card'],
      ['frontend_buyer_free_uses', 'article_end', 'framework_install', '/frameworks/#install', 'Try Frontman: five free uses, no card'],
    ],
    event: 'content_cta_clicked',
    published: '2026-05-23T05:00:00Z',
  },
  {
    slug: 'frontend-agent',
    sections: ['frontend-explainer-next-steps'],
    actions: [
      ['frontend_explainer_first_edit', 'article_end', 'first_ui_edit', '/blog/getting-started/', 'Make your first UI edit'],
      ['frontend_explainer_developer_setup', 'article_end', 'developer_setup', '/marketing-teams/#developer-setup', 'Get a developer setup brief'],
    ],
    event: 'content_cta_clicked',
    published: '2026-06-12T05:00:00Z',
  },
  {
    slug: 'best-wordpress-mcp-servers-and-plugins-2026',
    sections: ['wordpress-mcp-workflow-choice'],
    actions: [
      ['wordpress_mcp_visual_demo', 'quick_answer', 'wordpress_demo', '/blog/best-wordpress-ai-plugins-2026/#frontman-workflow-demo', 'Watch the Frontman visual editing workflow'],
    ],
    event: 'wordpress_article_cta_clicked',
    published: '2026-07-31T05:00:00Z',
  },
]

const fragments = (pilot: typeof pilots[number]) => {
  const article = source(`../content/blog/${pilot.slug}.md`)
  return pilot.sections.map(id => {
    const matches = [...article.matchAll(new RegExp(`<aside id="${id}"[^>]*>[\\s\\S]*?</aside>`, 'g'))]
    expect(matches).toHaveLength(1)
    return matches[0][0]
  }).join('\n')
}

test.each(pilots)('$slug preserves routes and declares the complete acquisition contract', pilot => {
  const article = source(`../content/blog/${pilot.slug}.md`)
  expect(article).toContain(`pubDate: ${pilot.published}`)
  expect(article).not.toMatch(/^slug:/m)
  const page = new JSDOM(fragments(pilot))
  try {
    const document = page.window.document
    const ids = [...document.querySelectorAll('[id]')].map(node => node.id)
    expect(new Set(ids).size).toBe(ids.length)
    const anchors = [...document.querySelectorAll('a')]
    expect(anchors).toHaveLength(pilot.actions.length)
    pilot.actions.forEach(([label, placement, destination, href, text], index) => {
      const anchor = anchors[index]
      expect(anchor.textContent).toBe(text)
      expect(anchor.getAttribute('href')).toBe(href)
      for (const [key, value] of Object.entries({
        event: pilot.event, category: 'engagement', label, placement, destination, 'task-family': 'update',
      })) expect(anchor.getAttribute(`data-ga-${key}`)).toBe(value)
    })
    if (pilot.slug === 'best-frontend-coding-agent') {
      for (const aside of document.querySelectorAll('aside')) {
        expect(aside.textContent).toContain('five free uses, no card')
        expect(aside.textContent).toContain('AI provider costs are separate')
        expect(aside.textContent).toContain('seven-day Pro trial requires a card')
        expect(aside.textContent).toContain('developer review and deployment')
      }
      expect(article).toContain('EUR 15/seat/month or EUR 150/seat/year')
      expect(article).toContain('7-day free Pro trial (card required)')
      expect(article).not.toContain('Start your Frontman trial (credit card required)')
    } else if (pilot.slug === 'frontend-agent') {
      expect(document.body.textContent).toContain('without project access needs developer setup')
    } else {
      expect(document.body.textContent).toContain('Frontman is not an MCP server')
      expect(document.body.textContent).toContain('live preview is not a universal approval gate')
    }
  } finally {
    page.window.close()
  }
})

test('internal actions reach existing files and explicit fragments', () => {
  expect(source('../pages/frameworks.astro')).toContain('InstallSteps')
  expect(source('../components/blocks/install/InstallSteps.astro')).toContain('id="install"')
  expect(source('../pages/marketing-teams.astro')).toContain('id="developer-setup"')
  expect(source('../content/blog/getting-started.md')).toContain('### Step 5: Select and Change a Button')
  const demo = source('../content/blog/best-wordpress-ai-plugins-2026.md')
  expect(demo).toContain('id="frontman-workflow-demo"')
  expect(demo).toContain('data-ga-destination="on_page_demo"')
})

test.each(pilots)('$slug delegated runtime emits exact parameters only with consent', pilot => {
  const page = new JSDOM(fragments(pilot), {
    url: `https://frontman.sh/blog/${pilot.slug}/`, runScripts: 'outside-only',
  })
  try {
    const { window } = page
    let accepted = false
    window.astroConsent = { get: () => ({ categories: { analytics: accepted } }) }
    window.eval(createAnalyticsScript('G-TEST'))
    window.document.dispatchEvent(new window.Event('DOMContentLoaded'))
    // Prevent navigation without interfering with the delegated listener.
    window.document.addEventListener('click', (event: Event) => event.preventDefault())
    const events = () => window.dataLayer.map((entry: IArguments) => Array.from(entry))
      .filter((entry: unknown[]) => entry[0] === 'event')
    const anchors = [...window.document.querySelectorAll('a')]
    anchors.forEach(anchor => anchor.click())
    expect(events()).toEqual([])
    accepted = true
    window.document.dispatchEvent(new window.Event('consentchange'))
    anchors.forEach(anchor => anchor.click())
    expect(events()).toEqual(pilot.actions.map(([label, placement, destination]) => [
      'event', pilot.event, {
        event_category: 'engagement', event_label: label,
        page_path: `/blog/${pilot.slug}/`, placement, destination, task_family: 'update',
      },
    ]))
    accepted = false
    window.document.dispatchEvent(new window.Event('consentchange'))
    anchors.forEach(anchor => anchor.click())
    expect(events()).toHaveLength(pilot.actions.length)
  } finally {
    page.window.close()
  }
})
