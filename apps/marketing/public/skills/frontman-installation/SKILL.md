# Frontman Installation

Use this skill when helping a developer install Frontman in a web project.

## Supported Integrations

- Next.js: https://frontman.sh/docs/integrations/nextjs/
- Astro: https://frontman.sh/docs/integrations/astro/
- Vite: https://frontman.sh/docs/integrations/vite/
- WordPress beta: https://frontman.sh/docs/integrations/wordpress/

## Quickstart Flow

1. Open https://frontman.sh/docs/installation/.
2. Pick framework integration.
3. Add Frontman middleware/plugin to dev server config.
4. Start local dev server.
5. Open browser preview and sign in with Frontman.
6. Connect Claude, ChatGPT, or OpenRouter API key.
7. Select a rendered element and ask for a visual code change.

## Auth And Keys

Hosted Frontman accounts use GitHub or Google OAuth. AI provider access is bring-your-own-key. Read https://frontman.sh/docs/api-keys/ before connecting provider credentials.

## Safety

Frontman is designed for development workflows. It creates source edits that should be reviewed with normal git and pull-request process before production deployment.
