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

- **Next.js:** See `libs/nextjs-plugin`
- **Other frameworks:** Coming soon

For development and testing, see the `examples/` directory for working integrations.

## Architecture

The system consists of two main components:

- **Agent Core** (`apps/agent`) - Stateless executable that processes requests and executes the agentic loop
- **Framework Plugin** - Framework integration that collects context and manages communication


## Technology Stack

- **Language:** ReScript
- **Runtime:** Node.js
- **UI:** React

## Project Structure

```
frontman/
├── apps/
│   └── agent/              # Agent core executable
├── libs/
│   └── nextjs-plugin/      # Next.js integration
├── examples/
│   └── nextjs/             # Example Next.js app for development/testing
└── docs/
    └── architecture.md     # Detailed architecture documentation
```

## Documentation

For detailed information, see the [`docs/`](./docs) directory:

- [Architecture](./docs/architecture.md) - System architecture and design decisions
