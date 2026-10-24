# Frontman Marketing Website

The marketing site for [frontman.sh](https://frontman.sh), built with Astro and Tailwind CSS.

## Stack

| Layer      | Technology                          |
| ---------- | ----------------------------------- |
| Framework  | Astro 7                             |
| Styling    | Tailwind CSS 4.3                    |
| TypeScript | Strict mode                         |
| Fonts      | Inter Variable, Outfit Variable     |
| Deployment | Cloudflare Pages                    |
| Analytics  | Google Analytics, Vercel Analytics   |
| Content    | Astro Content Collections, Markdown |

## Development

```bash
make install   # install dependencies
make test      # run marketing tests
make dev       # start dev server at localhost:4321
make build     # type-check and build for production
make deploy    # build and deploy (requires 1Password CLI)
```

Run `make help` to see all available commands.

## Site Structure

| Route          | Description                                     |
| -------------- | ----------------------------------------------- |
| `/`            | WordPress setup, capabilities, safety, and FAQ |
| `/frameworks/` | Framework setup, developer packages, and features |
| `/blog`        | Blog index and individual posts                 |
| `/blog/tags/*` | Posts filtered by tag                           |
| `/changelog`   | Rendered from the root `CHANGELOG.md`           |
| `/faq`         | Categorized FAQ with JSON-LD structured data    |

## Notes

- **Monorepo dependency**: Uses `@frontman-ai/astro` as a workspace package. Must be built within the monorepo.
- **Changelog**: The `/changelog` page reads `/CHANGELOG.md` from the monorepo root at build time.
- **Deploy secrets**: `make deploy` wraps commands with `op run` to inject Cloudflare credentials from 1Password.

## Agent tools

WebMCP is an optional browser enhancement on `/` and `/frameworks/`.
Both pages register tools independently of the hero. Without WebMCP, all normal content and links remain available.

- `search_frontman` searches public documentation only. It returns up to five excerpts of at most 400 characters with source URLs.
- `how_to_install` reads WordPress setup and safety on `/`. On `/frameworks/`, it returns instructions for the selected stack.
- `list_features` reads the current page content.
- `open_docs` and `jump_to_install` navigate without installing anything.
- `ask_question` requires user approval. A queued response does not confirm delivery. No replies are available.

Tests use rendered page-section fixtures under `src/integrations/fixtures/`.
When page structure changes, refresh these sections from a local build. Remove scripts, decorative media, and Astro scope attributes.
All support tests use mocked requests. Never send a real support request during verification.

## Official developer packages

The official integrations are [@frontman-ai/nextjs](https://www.npmjs.com/package/@frontman-ai/nextjs),
[@frontman-ai/astro](https://www.npmjs.com/package/@frontman-ai/astro), and
[@frontman-ai/vite](https://www.npmjs.com/package/@frontman-ai/vite).
Their source repository is [frontman-ai/frontman](https://github.com/frontman-ai/frontman).
The unscoped npm package `frontman` is unrelated.

## Acquisition measurement

Acquisition events use the existing consent gate:

- `click_wordpress_plugin`: WordPress.org outbound intent.
- `click_framework_setup`: navigation to the framework guide.
- `copy_agent_install_instructions`: instruction-request click, not proof of successful copying.
- `install_intent`: successful copying of an install command or manual setup step, not a completed installation.

The new intent event includes an allowlisted framework, site type, placement, destination, and pathname.
Explicit intent parameters contain no clipboard contents, query strings, or fragments.
Existing automatic Google URL collection is unchanged.
Confirmed installation, signup, and paid activation need product-side completion events and consent-aware attribution.
Do not mark outbound intent as a completed signup or purchase.

## Template Credit

The initial site structure was based on the [Foxi Astro theme](https://github.com/oxygenna/foxi-astro) by Oxygenna (MIT licensed).
