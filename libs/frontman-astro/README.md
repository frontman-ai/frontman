# @frontman/frontman-astro

Astro framework integration for Frontman, exposing tools and services via HTTP middleware and dev toolbar.

## Stack

- [ReScript](https://rescript-lang.org) with ES6 modules
- [Astro](https://astro.build) 5.0+
- HTTP middleware integration
- SSE (Server-Sent Events) for streaming responses

## Features

- HTTP middleware for handling tool requests
- Dev toolbar integration for interactive debugging
- Framework-specific tools (e.g., `GetPages`)
- Streaming responses via SSE

## Installation

```bash
npm install @frontman/frontman-astro
```

## Usage

Add the integration to your `astro.config.mjs`:

```javascript
import { defineConfig } from 'astro/config';
import { frontmanIntegration } from '@frontman/frontman-astro/integration';

export default defineConfig({
  integrations: [
    frontmanIntegration(),
  ],
});
```

## Exports

- `.` - Main module with `createMiddleware`, `makeConfig`, `ToolRegistry`
- `./integration` - Astro integration hook
- `./toolbar` - Dev toolbar app component

## Dependencies

- `@frontman/frontman-core` - Tool registry and SSE utilities
- `astro` ^5.0.0 (peer dependency)

## Commands

Run `make` or `make help` to see all available commands.
