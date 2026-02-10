# @frontman/vite-plugin

A Vite plugin that integrates the Frontman agent into your Vite development server.

## Installation

```bash
npm install @frontman/vite-plugin
# or
yarn add @frontman/vite-plugin
# or
pnpm add @frontman/vite-plugin
```

## Usage

Add the plugin to your `vite.config.ts`:

```typescript
import { defineConfig } from 'vite';
import { frontmanPlugin } from '@frontman/vite-plugin';

export default defineConfig({
  plugins: [
    frontmanPlugin({
      isDev: true,
      isLightTheme: true,
      entrypointUrl: 'http://localhost:5173/frontman',
    }),
  ],
});
```

## Options

### `isDev`

- **Type:** `boolean`
- **Default:** `process.env.NODE_ENV !== "production"`

Whether to run in development mode. In development mode, additional debugging features may be enabled.

### `isLightTheme`

- **Type:** `boolean`
- **Default:** `true`

Whether to use light theme for the UI. Set to `false` for dark theme.

### `entrypointUrl`

- **Type:** `string`
- **Default:** `"http://localhost:3000/frontman"`

The entrypoint URL for the Frontman API. This should match the URL where your Vite server is running.

### `clientUrl`

- **Type:** `string`
- **Default:** `"http://localhost:5173/src/Main.js"`

The URL where the Frontman client script is served.

## API Routes

The plugin automatically sets up the following API routes:

- `GET /frontman` - Serves the Frontman UI
- `POST /frontman/chat` - Handles chat messages
- `GET /frontman/chat-sse` - Server-Sent Events endpoint for streaming responses

## License

ISC

