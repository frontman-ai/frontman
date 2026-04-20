export const agentLinkHeader = [
  '</docs/>; rel="service-doc"; title="Frontman documentation"',
  '</how-it-works/>; rel="about"; title="How Frontman works"',
  '</pricing/>; rel="pricing"; title="Frontman pricing"',
  '</changelog/>; rel="version-history"; title="Frontman changelog"',
  '</compare/>; rel="related"; title="AI coding tools comparison"',
  '</contact/>; rel="contact"; title="Contact Frontman"',
  '</.well-known/agent-skills/index.json>; rel="agent-skills"; title="Frontman agent skills index"',
].join(', ')

export const homeMarkdown = `# Frontman: Visual AI Agent for Your Running App

Frontman lets you click any element in your live product, describe the change in plain English, and get real code edits.

## Why agents can use this site

- The site supports markdown responses for agents.
- It links to Frontman documentation, pricing, changelog, comparisons, and contact resources.
- It exposes lightweight browser tools for on-site navigation through WebMCP when supported.

## Key resources

- Documentation: [/docs/](/docs/)
- Installation: [/docs/installation/](/docs/installation/)
- How it works: [/how-it-works/](/how-it-works/)
- Pricing: [/pricing/](/pricing/)
- Changelog: [/changelog/](/changelog/)
- Comparisons: [/compare/](/compare/)
- Integrations: [/integrations/](/integrations/)
- Contact: [/contact/](/contact/)
- Agent skills index: [/.well-known/agent-skills/index.json](/.well-known/agent-skills/index.json)

## Product summary

Frontman is an AI agent that lives inside your framework's dev server as middleware. It sees the live DOM, component tree, CSS styles, routes, and server logs so it can make more accurate visual changes than file-only agents.
`

export const markdownTokenCount = homeMarkdown.split(/\s+/u).filter(Boolean).length
