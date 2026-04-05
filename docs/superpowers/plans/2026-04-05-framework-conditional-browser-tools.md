# Framework-Conditional Browser Tool Registration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable framework adapters to register browser-specific tools conditionally, starting with an empty Astro browser tools package.

**Architecture:** New `@frontman-ai/astro-browser` package exports an empty `browserTools` array typed as `array<module(BrowserTool)>`. The client's `Client__ToolRegistry` gains a `forFramework` function that switches on `RuntimeConfig.frameworkId` and composes core + framework tools. `Client__FrontmanProvider` calls `forFramework` instead of `coreBrowserTools`.

**Tech Stack:** ReScript 12, sury, vitest, yarn workspaces

**Spec:** `docs/superpowers/specs/2026-04-05-framework-conditional-browser-tools-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| NEW | `libs/frontman-astro-browser/package.json` | Package metadata and dependencies |
| NEW | `libs/frontman-astro-browser/rescript.json` | ReScript compiler config |
| NEW | `libs/frontman-astro-browser/Makefile` | Standard build/test/lint targets |
| NEW | `libs/frontman-astro-browser/vitest.config.ts` | Test runner config |
| NEW | `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Registry.res` | Exports empty `browserTools` array |
| NEW | `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res` | Validates registry export |
| EDIT | `package.json` (root) | Add workspace entry |
| EDIT | `libs/client/package.json` | Add `@frontman-ai/astro-browser` dev dependency |
| EDIT | `libs/client/rescript.json` | Add `@frontman-ai/astro-browser` to bs-dependencies |
| EDIT | `libs/client/src/Client__ToolRegistry.res` | Add `forFramework` function |
| EDIT | `libs/client/test/Client__ToolRegistry.test.res` | Add `forFramework` tests |
| EDIT | `libs/client/src/Client__FrontmanProvider.res` | Use `forFramework` |

---

## Task 1: Scaffold `@frontman-ai/astro-browser` package

**Files:**
- Create: `libs/frontman-astro-browser/package.json`
- Create: `libs/frontman-astro-browser/rescript.json`
- Create: `libs/frontman-astro-browser/Makefile`
- Create: `libs/frontman-astro-browser/vitest.config.ts`
- Modify: `package.json` (root, line 14-35 workspaces array)

- [ ] **Step 1: Create `libs/frontman-astro-browser/package.json`**

```json
{
  "name": "@frontman-ai/astro-browser",
  "version": "0.1.0",
  "description": "Astro-specific browser tools for Frontman",
  "license": "Apache-2.0",
  "type": "module",
  "private": true,
  "dependencies": {
    "@rescript/runtime": "12.0.0-beta.14"
  },
  "devDependencies": {
    "@frontman-ai/frontman-protocol": "workspace:*",
    "@rescript/webapi": "*",
    "rescript": "catalog:",
    "rescript-vitest": "catalog:",
    "sury": "catalog:",
    "sury-ppx": "^11.0.0-alpha.2",
    "vite": "catalog:",
    "vitest": "catalog:"
  }
}
```

- [ ] **Step 2: Create `libs/frontman-astro-browser/rescript.json`**

```json
{
  "name": "@frontman-ai/astro-browser",
  "namespace": true,
  "sources": [
    {
      "dir": "src",
      "subdirs": false
    },
    {
      "dir": "test",
      "subdirs": false,
      "type": "dev"
    }
  ],
  "package-specs": [
    {
      "module": "esmodule",
      "in-source": true,
      "suffix": ".res.mjs"
    }
  ],
  "ppx-flags": ["sury-ppx/bin"],
  "dependencies": [
    "@frontman-ai/frontman-protocol",
    "sury"
  ],
  "dev-dependencies": ["rescript-vitest"]
}
```

- [ ] **Step 3: Create `libs/frontman-astro-browser/vitest.config.ts`**

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['test/**/*.test.res.mjs'],
    globals: true,
    passWithNoTests: true,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json-summary', 'cobertura'],
      include: ['src/**/*.res.mjs'],
      exclude: [
        '**/*.test.*',
      ],
    },
  },
});
```

- [ ] **Step 4: Create `libs/frontman-astro-browser/Makefile`**

```makefile
.DEFAULT_GOAL := help
.PHONY: help install test test-watch test-coverage build clean lint format check dev

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	yarn install

build: ## Build the project
	yarn rescript build

dev: ## Build the project in watch mode
	yarn rescript watch

test: build ## Run test suite
	yarn vitest run

test-watch: ## Run tests in watch mode
	yarn vitest watch

test-coverage: build ## Run tests with coverage
	yarn vitest run --coverage

lint: ## Check code formatting
	yarn rescript format --check

format: ## Format code
	yarn rescript format -all

check: lint test ## Run all checks (lint + test)

clean: ## Clean build artifacts and temporary files
	rm -rf src/*.res.mjs src/*.res.mjs.map test/*.res.mjs test/*.res.mjs.map
```

- [ ] **Step 5: Add workspace entry to root `package.json`**

In the root `package.json`, add `"libs/frontman-astro-browser"` to the `workspaces` array, after `"libs/frontman-astro"`:

```json
"workspaces": [
    "apps/frontman_server/assets",
    "apps/marketing",
    "libs/bindings",
    "libs/client",
    "libs/experimental-rescript-webapi",
    "libs/frontman-client",
    "libs/frontman-protocol",
    "libs/frontman-core",
    "libs/frontman-astro",
    "libs/frontman-astro-browser",
    "libs/frontman-nextjs",
    ...
]
```

- [ ] **Step 6: Install dependencies**

Run: `yarn install` from the repo root.

Expected: Clean install, `@frontman-ai/astro-browser` workspace resolved.

- [ ] **Step 7: Verify ReScript builds**

Run: `cd libs/frontman-astro-browser && yarn rescript build`

Expected: Build succeeds (no source files yet, that's fine — no errors).

- [ ] **Step 8: Commit**

```bash
git add libs/frontman-astro-browser/ package.json yarn.lock
git commit -m "feat: scaffold @frontman-ai/astro-browser package"
```

---

## Task 2: Implement `FrontmanAstroBrowser__Registry` with TDD

**Files:**
- Create: `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res`
- Create: `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Registry.res`

- [ ] **Step 1: Write the failing test**

Create `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res`:

```rescript
open Vitest

module Registry = FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry

describe("FrontmanAstroBrowser__Registry", _t => {
  test("browserTools is an empty array", t => {
    t->expect(Registry.browserTools->Array.length)->Expect.toBe(0)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd libs/frontman-astro-browser && yarn rescript build 2>&1`

Expected: Compilation error — `FrontmanAstroBrowser__Registry` module not found.

- [ ] **Step 3: Write the implementation**

Create `libs/frontman-astro-browser/src/FrontmanAstroBrowser__Registry.res`:

```rescript
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

type tool = module(Tool.BrowserTool)

let browserTools: array<tool> = []
```

- [ ] **Step 4: Build and run test to verify it passes**

Run: `cd libs/frontman-astro-browser && yarn rescript build && yarn vitest run`

Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add libs/frontman-astro-browser/src/ libs/frontman-astro-browser/test/
git commit -m "feat: add FrontmanAstroBrowser__Registry with empty browserTools"
```

---

## Task 3: Wire `@frontman-ai/astro-browser` into client dependencies

**Files:**
- Modify: `libs/client/package.json:47-51` (devDependencies)
- Modify: `libs/client/rescript.json:29-39` (bs-dependencies)

- [ ] **Step 1: Add `@frontman-ai/astro-browser` to `libs/client/package.json` devDependencies**

Add this line in the `devDependencies` object (alphabetical, after `@frontman-ai/frontman-protocol`):

```json
"@frontman-ai/astro-browser": "workspace:*",
```

- [ ] **Step 2: Add `@frontman-ai/astro-browser` to `libs/client/rescript.json` dependencies**

In the `dependencies` array, add `"@frontman-ai/astro-browser"`:

```json
"dependencies": [
    "@frontman/bindings",
    "@frontman/logs",
    "@rescript/react",
    "@rescript/webapi",
    "@frontman-ai/astro-browser",
    "@frontman-ai/frontman-client",
    "@frontman-ai/nextjs",
    "@frontman-ai/frontman-protocol",
    "@frontman-ai/react-statestore",
    "sury"
]
```

- [ ] **Step 3: Install and verify build**

Run: `yarn install && cd libs/client && yarn rescript build`

Expected: Clean build. The client can now import from `FrontmanAiAstroBrowser`.

- [ ] **Step 4: Commit**

```bash
git add libs/client/package.json libs/client/rescript.json yarn.lock
git commit -m "feat: add @frontman-ai/astro-browser as client dependency"
```

---

## Task 4: Add `forFramework` to `Client__ToolRegistry` with TDD

**Files:**
- Modify: `libs/client/test/Client__ToolRegistry.test.res`
- Modify: `libs/client/src/Client__ToolRegistry.res`

- [ ] **Step 1: Write failing tests for `forFramework`**

Append to the existing `describe("ToolRegistry", ...)` block in `libs/client/test/Client__ToolRegistry.test.res`, after the `merge` test (line 53):

```rescript
  describe("forFramework", _t => {
    test("Astro returns core browser tools count", t => {
      let registry = ToolRegistry.forFramework(Client__RuntimeConfig.Astro)
      t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
    })

    test("Nextjs returns core browser tools count", t => {
      let registry = ToolRegistry.forFramework(Client__RuntimeConfig.Nextjs)
      t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
    })

    test("Vite returns core browser tools count", t => {
      let registry = ToolRegistry.forFramework(Client__RuntimeConfig.Vite)
      t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
    })

    test("Wordpress returns core browser tools count", t => {
      let registry = ToolRegistry.forFramework(Client__RuntimeConfig.Wordpress)
      t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
    })
  })
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd libs/client && yarn rescript build 2>&1`

Expected: Compilation error — `ToolRegistry.forFramework` not found.

- [ ] **Step 3: Implement `forFramework`**

In `libs/client/src/Client__ToolRegistry.res`, add after the `count` function (line 58):

```rescript
// Build a registry with core browser tools + framework-specific tools
let forFramework = (framework: Client__RuntimeConfig.frameworkId): t => {
  let base = coreBrowserTools()
  switch framework {
  | Astro =>
    base->addTools(FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry.browserTools)
  | Nextjs | Vite | Wordpress => base
  }
}
```

- [ ] **Step 4: Build and run tests**

Run: `cd libs/client && yarn rescript build && yarn vitest run`

Expected: All tests pass — both existing (5 tests) and new (4 tests), total 9.

- [ ] **Step 5: Commit**

```bash
git add libs/client/src/Client__ToolRegistry.res libs/client/test/Client__ToolRegistry.test.res
git commit -m "feat: add forFramework to Client__ToolRegistry"
```

---

## Task 5: Use `forFramework` in `Client__FrontmanProvider`

**Files:**
- Modify: `libs/client/src/Client__FrontmanProvider.res:211`

- [ ] **Step 1: Replace `coreBrowserTools()` with `forFramework`**

In `libs/client/src/Client__FrontmanProvider.res`, change line 211 from:

```rescript
      let toolRegistry = Client__ToolRegistry.coreBrowserTools()
```

to:

```rescript
      let toolRegistry = Client__ToolRegistry.forFramework(runtimeConfig.framework)
```

Note: `runtimeConfig` is already read on line 205, so `runtimeConfig.framework` is available.

- [ ] **Step 2: Verify build**

Run: `cd libs/client && yarn rescript build`

Expected: Clean build, no errors.

- [ ] **Step 3: Run all client tests**

Run: `cd libs/client && yarn vitest run`

Expected: All 9 tests pass. The provider change doesn't affect unit tests (provider is not unit-tested, it's integration-tested via the running app).

- [ ] **Step 4: Commit**

```bash
git add libs/client/src/Client__FrontmanProvider.res
git commit -m "feat: use forFramework in FrontmanProvider initialization"
```

---

## Task 6: Final verification and changeset

**Files:**
- Create: `.changeset/*.md` (generated by `yarn changeset`)

- [ ] **Step 1: Run astro-browser tests**

Run: `cd libs/frontman-astro-browser && make test`

Expected: 1 test passes.

- [ ] **Step 2: Run client tests**

Run: `cd libs/client && make test`

Expected: All 9 tests pass.

- [ ] **Step 3: Lint both packages**

Run: `cd libs/frontman-astro-browser && make lint && cd ../client && make lint`

Expected: No formatting issues. If there are, run `make format` in each package and re-check.

- [ ] **Step 4: Create changeset**

Run: `yarn changeset` from the repo root. When prompted:

- Select `@frontman-ai/astro-browser` and `@frontman-ai/client` as changed packages
- Bump type: `minor` for both (new feature)
- Summary: `Add framework-conditional browser tool registration infrastructure`

- [ ] **Step 5: Commit changeset**

```bash
git add .changeset/
git commit -m "chore: add changeset for framework-conditional browser tools"
```
