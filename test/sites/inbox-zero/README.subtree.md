# inbox-zero Test Site

> **Note:** This directory is a git subtree of [elie222/inbox-zero](https://github.com/elie222/inbox-zero) used for testing and demonstrating our coding agent capabilities on a real-world production codebase.

## Quick Start

All commands should be run from this directory (`test/sites/inbox-zero/`).

### Development Setup

```bash
# Install dependencies
make install

# Start database services (PostgreSQL + Redis)
make db-up

# Run migrations (first time only)
make db-migrate

# Start development server
make dev
```

The app will be available at [http://localhost:3000](http://localhost:3000).

### Common Commands

```bash
make help          # Show all available commands
make dev           # Start development server
make build         # Build for production
make test          # Run tests
make lint          # Run linter
make format        # Format code
make check         # Run format check and linter
make clean         # Clean build artifacts
make db-up         # Start PostgreSQL and Redis
make db-down       # Stop database services
```

## Subtree Management

This directory is managed as a git subtree, allowing us to include the full inbox-zero repository while maintaining the ability to pull upstream updates.

### Subtree Commands

```bash
# Show current subtree information
make subtree-status

# Check what's new in upstream
make subtree-diff

# Pull latest changes from upstream
make subtree-pull
```

### How Subtree Works

- **Remote**: `inbox-zero-upstream` → `https://github.com/elie222/inbox-zero.git`
- **Branch**: `main`
- **Prefix**: `test/sites/inbox-zero/`

When you run `make subtree-pull`, it fetches the latest changes from the upstream repository and merges them into this directory.

## Project Overview

inbox-zero is a production-grade email management application with:

- **Tech Stack**: Next.js, TypeScript, Turborepo, Prisma, Tailwind CSS
- **Package Manager**: pnpm
- **Monorepo**: Multiple apps and packages
- **Database**: PostgreSQL
- **Cache**: Redis
- **Code Quality**: Biome for linting/formatting

This is an excellent test case for our coding agent because it represents a real-world, complex monorepo with:
- Modern tooling and best practices
- Multiple applications and packages
- Database migrations and schemas
- API integrations (Google, Microsoft OAuth)
- AI/LLM features
- Comprehensive testing setup

## Environment Setup

Before running the app, you'll need to set up environment variables. See the original README below for detailed instructions on:

- Google OAuth credentials
- Microsoft OAuth credentials (optional)
- LLM API keys (Anthropic, OpenAI, or local Ollama)
- Database configuration
- Redis configuration

Copy the example env file:

```bash
cp apps/web/.env.example apps/web/.env
```

Then follow the detailed setup instructions in the original README below.

## Why This Project?

We chose inbox-zero as a test site because:

1. **Real-world complexity** - Not a toy example, but a production application
2. **Modern stack** - Uses current best practices and tooling
3. **Monorepo** - Tests our agent's ability to navigate complex structures
4. **AI features** - Includes LLM integrations, relevant for our agent
5. **Active development** - Regularly updated, good for testing subtree pulls
6. **Well-documented** - Clear setup and contribution guidelines

## Known Issues & Workarounds

### PostgreSQL 18+ Volume Mount Issue

**Issue**: The upstream `docker-compose.yml` uses `image: postgres` which pulls PostgreSQL 18+. This version has breaking changes with volume mounts that cause the container to fail.

**Workaround**: We've temporarily modified `docker-compose.yml` to use `image: postgres:16`. This change will be overwritten when you run `make subtree-pull`, so you'll need to reapply it after pulling upstream updates.

**Tracking**: This is a known PostgreSQL issue: https://github.com/docker-library/postgres/issues/37

---

# Original inbox-zero README

Below is the original README from the upstream repository:

---

