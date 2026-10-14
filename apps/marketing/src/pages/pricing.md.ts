import type { APIRoute } from 'astro'
import { markdownResponse } from '../content/markdownResponse'
import { pricing, subscriptionTerms } from '../content/pricing'

export const GET: APIRoute = () => markdownResponse(`# Frontman Pro pricing

## Hosted plan

- Monthly: ${pricing.currency} ${pricing.monthly} per seat per month.
- Yearly: ${pricing.currency} ${pricing.yearly} per seat per year.
- One seat covers one user across unlimited projects in one organization.
- The same plan supports WordPress and framework integrations.

## Trial, renewal, cancellation, and costs

${subscriptionTerms}

Paid hosted subscriptions are for business and professional use, not consumers.

## Self-hosting

Run Frontman on your own infrastructure. You manage setup, hosting, and updates, and pay infrastructure and AI-provider costs. Hosted support, uptime, and onboarding are not included.

## Setup and safety

WordPress needs administrator access, Frontman sign-in, and an AI-provider connection. Live writes can affect published content immediately; use staging and backups. Framework integrations edit development source for your team to review, test, and deploy.

- WordPress setup: https://frontman.sh/docs/integrations/wordpress/
- Frameworks: https://frontman.sh/frameworks/
- Access requirements: https://frontman.sh/auth.md
- Terms: https://frontman.sh/terms/
- Privacy: https://frontman.sh/privacy/
- DPA: https://frontman.sh/dpa/
`, '/pricing/')
export const prerender = true
