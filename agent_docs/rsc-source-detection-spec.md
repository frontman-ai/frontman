# React Server Component Source Detection

## Objective

Resolve annotated elements rendered by Next.js React Server Components to original project-relative source files and coordinates in development mode.

## Scope

- Preserve raw `about://React/Server/` locations returned by React development metadata.
- Extract React Server stack frames locally without attempting browser requests for `about://` URLs.
- Resolve generated server chunks through Frontman's existing server-side source-map endpoint.
- Report unresolved virtual React locations as errors rather than successful source paths.
- Restrict generated chunks to `projectRoot` and resolved sources to `sourceRoot`.
- Cover pure server components and client components nested beneath server components.

Production builds without React development metadata are out of scope.

## Commands

- Client tests: `make test` from `libs/client`
- Core tests: `make test` from `libs/frontman-core`
- Client formatting check: `make lint` from `libs/client`
- Core formatting check: `make lint` from `libs/frontman-core`

## Structure And Style

- Browser detection stays in `libs/client`.
- Filesystem and source-map resolution stays in `libs/frontman-core`.
- Existing `dom-element-to-component-source` browser/server interfaces remain the integration boundary.
- ReScript control flow uses pattern matching.

## Testing Strategy

- Unit-test browser delegation and failure behavior with Vitest.
- Integration-test HTTP source resolution with a generated-file/source-map fixture.
- Exercise a real Next.js App Router server component when local browser infrastructure is available.

## Boundaries

- Always preserve ordinary React, Vue, and Astro source detection.
- Ask before adding dependencies or changing persisted annotation schemas.
- Never treat unresolved `about://React/` locations as project source files.

## Success Criteria

- RSC locations reach server resolver instead of being discarded in browser.
- Resolvable generated locations return project-relative `.tsx` files with line and column.
- Unresolvable React virtual locations return a non-success HTTP response.
- Resolver input cannot read source maps outside `projectRoot` or return files outside `sourceRoot`.
- Client and core test suites pass.
