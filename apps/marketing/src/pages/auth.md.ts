import type { APIRoute } from 'astro'

export const GET: APIRoute = () => new Response(`# Frontman authentication and access

## Public read-only resources

No sign-in, API key, or cookie is required to read the marketing site, pricing, documentation and their Markdown representations, /llms.txt, /llms-full.txt, /docs/llms.txt, /search-index.json, or published agent skills and their index. Homepage and framework ?mode=agent views are also public reads. These resources do not grant website editing access.

## Hosted Frontman sign-in

Hosted accounts sign in with GitHub or Google in the browser. Service access is separate; see https://frontman.sh/pricing.md. Browser login is not a public OAuth API for third-party agents. Browser session, socket-token, user settings, and provider credential endpoints require authenticated product access; they are not public agent APIs.

## AI-provider access

Connect a supported provider account or save a supported provider API key in Frontman settings. Provider OAuth is separate from Frontman sign-in and does not delegate Frontman access to third-party agents. Provider usage, quota, billing, and terms remain separate. Current provider setup: https://frontman.sh/docs/api-keys/.

## WordPress permissions

WordPress requires WordPress 6.0+, PHP 7.4+, and administrator access. Install and activate the plugin, open Frontman from the admin menu, sign in to Frontman, and connect an AI provider. WordPress permissions and Frontman service access are separate requirements. Writes persist to the connected installation; published content can change immediately. Use staging and backups.

Setup: https://frontman.sh/docs/integrations/wordpress/.

## Framework sessions

Next.js, Astro, and Vite integrations need a running supported development project and permitted workspace access. The browser client connects to the hosted or self-hosted Frontman server through authenticated WebSocket sessions. Developers review source diffs, run tests, and deploy normally. Check production guards and deployed routes; do not assume Frontman is automatically absent from production.

- Installation: https://frontman.sh/docs/installation/
- Self-hosting: https://frontman.sh/docs/reference/self-hosting/
- Privacy: https://frontman.sh/privacy/
`, { headers: { 'Content-Type': 'text/markdown; charset=utf-8' } })
export const prerender = true
