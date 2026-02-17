# Frontman Marketing Website

The marketing site for [frontman.sh](https://frontman.sh), built with Astro and Tailwind CSS.

## Stack

| Layer      | Technology                          |
| ---------- | ----------------------------------- |
| Framework  | Astro 5                             |
| Styling    | Tailwind CSS 3.4                    |
| TypeScript | Strict mode                         |
| Fonts      | Inter Variable, Outfit Variable     |
| Deployment | Vercel (primary), Cloudflare Pages  |
| Analytics  | Google Analytics, Vercel Analytics   |
| Content    | Astro Content Collections, Markdown |

## Development

```bash
make install   # install dependencies
make dev       # start dev server at localhost:4321
make build     # type-check and build for production
make deploy    # build and deploy (requires 1Password CLI)
```

Run `make help` to see all available commands.

## Site Structure

| Route          | Description                                     |
| -------------- | ----------------------------------------------- |
| `/`            | Homepage -- hero, features, framework support, comparison table, FAQ |
| `/blog`        | Blog index and individual posts                 |
| `/blog/tags/*` | Posts filtered by tag                           |
| `/changelog`   | Rendered from the root `CHANGELOG.md`           |
| `/faq`         | Categorized FAQ with JSON-LD structured data    |

## Notes

- **Monorepo dependency**: Uses `@frontman-ai/astro` as a workspace package. Must be built within the monorepo.
- **Dogfooding**: Frontman's own Astro integration is enabled in dev mode via the `@frontman-ai/astro` integration in `astro.config.mjs`, so the marketing site uses Frontman to build itself.
- **Changelog**: The `/changelog` page reads `/CHANGELOG.md` from the monorepo root at build time.
- **Deploy secrets**: `make deploy` wraps commands with `op run` to inject Cloudflare credentials from 1Password.

## Template Credit

The initial site structure was based on the [Foxi Astro theme](https://github.com/oxygenna/foxi-astro) by Oxygenna (MIT licensed).
