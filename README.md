# Frontman

A framework-integrated AI coding agent that embeds directly into web development frameworks, providing real-time assistance with compilation errors, code generation, and debugging.

## Overview

Unlike traditional IDE-based coding assistants, Frontman integrates directly into your running application, gaining access to:

- Real-time compilation errors and warnings
- Runtime logs and framework events
- Route changes and build status
- Component structure and state

## Getting Started

Install the plugin for your framework:

- **Next.js:** See [`libs/frontman-nextjs`](./libs/frontman-nextjs)
- **Astro:** See [`libs/frontman-astro`](./libs/frontman-astro)
- **Vite:** See [`libs/vite-plugin`](./libs/vite-plugin)

## Technology Stack

- **Language:** ReScript
- **Runtime:** Node.js
- **Backend:** Elixir/Phoenix
- **UI:** React

## Project Structure

```
frontman/
├── apps/
│   ├── chrome-extension/   # Browser extension
│   ├── dogfooding/         # Internal testing app
│   ├── frontman_server/    # Elixir/Phoenix backend
│   └── marketing/          # Marketing website
├── libs/
│   ├── bindings/           # ReScript bindings for Node/browser APIs
│   ├── client/             # React component library
│   ├── context-loader/     # Config file discovery and loading
│   ├── frontman-astro/     # Astro framework integration
│   ├── frontman-client/    # Browser MCP client
│   ├── frontman-core/      # Core server tools
│   ├── frontman-nextjs/    # Next.js integration
│   ├── frontman-protocol/  # Protocol definitions
│   ├── react-statestore/   # React state management
│   └── vite-plugin/        # Vite plugin
├── docs/                   # Protocol documentation
└── infra/                  # Infrastructure configs
```

## Documentation

For detailed information, see the [`docs/`](./docs) directory.
