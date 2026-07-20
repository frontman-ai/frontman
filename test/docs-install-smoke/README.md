# Documentation installer smoke check

Run the public quickstart installers against disposable projects and current npm releases:

```bash
make docs-install-smoke
```

The check requires Node.js, npm, and network access. It creates fixtures under the system temporary directory, installs the latest matching framework and Frontman packages, verifies expected config files, starts each development server, and requires `/frontman` to return the Frontman workspace HTML. Set `KEEP_SMOKE_FIXTURES=1` to retain failed or successful fixtures for inspection.

This is a representative smoke check, not the full framework compatibility matrix:

- latest Next.js 16 with a root `app/` directory
- latest Vite with its generated React plugin config shape
- latest Astro 6, the newest Astro major supported by the currently published package

## UI release checklist

Installer or onboarding documentation changes also require this browser check in a fresh profile:

1. Open `/frontman` and confirm the full-page split workspace loads.
2. Confirm the welcome dialog redirects an unauthenticated user to GitHub or Google sign-in.
3. Confirm the provider prompt opens **Providers**, accepts a supported account or API-key connection, and enables model selection.
4. Click **Select**, confirm the label changes to **Selecting...** and the preview cursor becomes a crosshair, then select an element.
5. Send a small edit request and confirm the source file and live preview both change.

## Validation record: 2026-07-20

| Fixture | Published Frontman package | Result | Files changed |
|---|---|---|---|
| Next.js 16.2.10 | `@frontman-ai/nextjs@1.0.2` | `/frontman` served | `package.json`, lockfile, `proxy.ts`, `instrumentation.ts` |
| Vite 8.1.5 | `@frontman-ai/vite@1.0.2` | `/frontman` served | `package.json`, lockfile, `vite.config.js` |
| Astro 6.4.8 | `@frontman-ai/astro@1.0.3` | `/frontman` served | `package.json`, lockfile, `astro.config.mjs` |

Astro 7.1.2 installation failed because `@frontman-ai/astro@1.0.3` declares Astro 5 and 6 peer support. Next.js 16.2.10 with a `src/` directory installed `proxy.ts` at the project root, where Next.js did not load it; `/frontman` returned 404. Moving the generated file to `src/proxy.ts` restored `/frontman`; the quickstart documents this workaround.
