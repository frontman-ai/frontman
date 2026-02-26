# Contributing to Frontman

Thanks for your interest in contributing to Frontman! This guide will help you get set up and productive quickly.

## Prerequisites

- **Node.js** v24+
- **Yarn 4** (via [Corepack](https://nodejs.org/api/corepack.html): `corepack enable`)
- **Elixir** 1.19+ (only needed for the server in `apps/frontman_server/`)
- **mkcert** (for local SSL certificates)

## Getting Started

```bash
# Clone the repo
git clone https://github.com/frontman-ai/frontman.git
cd frontman

# Install dependencies
make install

# Build all packages
make build

# Start the dev environment
make dev
```

## Development Workflow

1. **Branch from `main`** — Create a feature branch for your change.
2. **Use `make` commands** — The task runner is Makefiles, not yarn/npm scripts. Run `make help` in any directory to see available targets.
3. **Run tests** — Run `make test` in the relevant `libs/` directory before submitting a PR.
4. **Add a changeset** — If your change is user-facing, run `yarn changeset` from the repo root and follow the prompts. A CI check will block PRs that are missing a changeset.

## Project Structure

```
frontman/
├── apps/
│   ├── chrome-extension/      # Browser extension
│   ├── dogfooding/            # Internal testing app
│   ├── frontman_server/       # Elixir/Phoenix backend
│   └── marketing/             # Marketing website
├── libs/
│   ├── bindings/              # ReScript bindings for Node/browser APIs
│   ├── client/                # React UI component library
│   ├── frontman-astro/        # Astro framework integration
│   ├── frontman-client/       # Browser-side MCP client
│   ├── frontman-core/         # Core server-side tools
│   ├── frontman-nextjs/       # Next.js integration
│   ├── frontman-protocol/     # Protocol definitions
│   ├── react-statestore/      # React state management library
│   └── frontman-vite/          # Vite plugin
├── docs/                      # Protocol documentation
└── infra/                     # Infrastructure configs
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | [ReScript](https://rescript-lang.org/) |
| Backend | [Elixir](https://elixir-lang.org/) / [Phoenix](https://phoenixframework.org/) |
| UI | [React](https://react.dev/) |
| Runtime | [Node.js](https://nodejs.org/) |

## Code Conventions

### ReScript

- Functional style with `Result` types for error handling.
- **Crash early and obviously.** Use `Option.getOrThrow` / `Result.getOrThrow` when a value should always exist. Never silently swallow exceptions.
- File naming follows the `Client__ComponentName.res` flat-folder convention.
- JSON parsing: always use [Sury](https://github.com/sury-lib/sury) schemas (`@schema` annotation) instead of manual `Dict.get` chains.
- State management: all API calls and side effects go through the `StateReducer` (see `libs/client/`).

### Tests

- Tests use [Vitest](https://vitest.dev/) with `rescript-vitest`.
- Test files are named `*.test.res.mjs`.
- Assertion style: `t->expect(value)->Expect.toEqual(expected)`.

### Stories (Storybook)

- Story files are co-located with components: `Client__MyComponent.story.res`.
- Run `cd libs/client && make storybook` to start Storybook.

## Pull Request Process

1. Fill out the PR template (description, related issues, testing checklist).
2. Ensure CI passes — linting, type checking, and tests are run automatically.
3. Include a changeset if the change is user-facing (`yarn changeset`).
4. A maintainer will review your PR. We aim to provide initial feedback within a few business days.

## Releasing

Frontman uses [changesets](https://github.com/changesets/changesets) for versioning and changelogs.

### 1. Add changesets during development

When making user-facing changes, run `yarn changeset` from the repo root. This creates a markdown fragment in `.changeset/` describing the change and which packages are affected.

### 2. Create a release PR

```bash
make release
```

This triggers a GitHub Actions workflow that:
- Runs `yarn changeset version` to bump package versions and update changelogs
- Creates a `release/vX.Y.Z` branch and opens a PR

Review the changelog in the PR, then merge when ready.

### 3. Tag and GitHub Release

When the release PR merges to `main`, a git tag and GitHub Release are created automatically.

### 4. Publish to npm

npm publishing is done manually after the release PR merges:

```bash
git checkout main && git pull

# Publish @frontman-ai/astro
make publish-astro
```

This builds the package from scratch (ReScript + tsup bundle) and runs `npm publish`. The version in `package.json` was already bumped by changesets in step 2.

> **Note:** Only `@frontman-ai/astro` has a publish target currently. To add more, create a `publish` target in the package's Makefile and a corresponding `publish-<name>` target in the root Makefile.

## License

Contributions to client libraries (`libs/`) are licensed under the [Apache License 2.0](./LICENSE). Contributions to the server (`apps/frontman_server/`) are licensed under the [AGPL-3.0](./apps/frontman_server/LICENSE).

No CLA is required — the Apache 2.0 license (Section 5) covers contribution grants.
