# Frontman Marketing Website

The marketing site for [frontman.sh](https://frontman.sh), built with Astro and Tailwind CSS.

## Stack

| Layer      | Technology                          |
| ---------- | ----------------------------------- |
| Framework  | Astro 7                             |
| Styling    | Tailwind CSS 4.3                    |
| TypeScript | Strict mode                         |
| Fonts      | Inter Variable, Outfit Variable     |
| Deployment | Vercel (primary), Cloudflare Pages  |
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
| `/`            | Homepage -- hero, features, framework support, comparison table, FAQ |
| `/blog`        | Blog index and individual posts                 |
| `/blog/tags/*` | Posts filtered by tag                           |
| `/changelog`   | Rendered from the root `CHANGELOG.md`           |
| `/faq`         | Categorized FAQ with JSON-LD structured data    |

## Notes

- **Monorepo dependency**: Uses `@frontman-ai/astro` as a workspace package. Must be built within the monorepo.
- **Changelog**: The `/changelog` page reads `/CHANGELOG.md` from the monorepo root at build time.
- **Deploy secrets**: `make deploy` wraps commands with `op run` to inject Cloudflare credentials from 1Password.

## Homepage WebMCP

The homepage registers six tools through `document.modelContext`. WebMCP requires a compatible browser with the API enabled.
Deploying the website alone does not enable this experimental browser API.

For a local browser check:

1. Open `chrome://flags/#enable-webmcp-testing` in a compatible Chrome version.
2. Enable the flag and relaunch Chrome.
3. Open `https://frontman.sh/`.
4. Run `await document.modelContext.getTools()` in DevTools.
5. Use the read-only `how_to_install` tool to check execution without sending a support message.

For access without the testing flag, enroll `https://frontman.sh` in the
[WebMCP origin trial](https://developer.chrome.com/docs/ai/webmcp).
Add the issued token as an `Origin-Trial` response header or an `origin-trial` meta tag.
This repository does not contain a trial token. The trial's supported Chrome versions and expiration date still apply.

`webmcp-validators.mjs` defines the Sury schemas and compiles them with Ajv during the Vite build.
The browser receives standalone validators, not either schema compiler. This keeps `unsafe-eval` out of the production CSP.
The compiler preserves Sury's UTF-16 length limits and UUID format, which excludes the `urn:uuid:` prefix.
The `connect-src` directive in `public/_headers` allows the production support API at `https://api.frontman.sh`.
Custom deployments with another API origin also need that origin in `connect-src`.

`make test` exercises a production-mode bundle with string code generation disabled and mocked support requests.
It also checks the production CSP. This regression check does not replace a check in a WebMCP-enabled browser.

## Template Credit

The initial site structure was based on the [Foxi Astro theme](https://github.com/oxygenna/foxi-astro) by Oxygenna (MIT licensed).
