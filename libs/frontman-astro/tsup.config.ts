import { defineConfig } from 'tsup';

export default defineConfig([
  // CLI entry point
  {
    entry: { 'cli': './src/cli/cli.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: true,
    noExternal: [
      '@frontman/frontman-core',
      '@frontman/frontman-protocol',
      '@frontman/bindings',
      '@rescript/runtime',
      'sury',
    ],
    external: [
      'astro',
      'astro/toolbar',
      'astro/config',
      'astro:middleware',
      '@astrojs/node',
      // Node.js built-ins
      'fs',
      'path',
      'os',
      'child_process',
      'crypto',
      'util',
      'stream',
      'events',
      'buffer',
      'url',
      'http',
      'https',
      'net',
      'tls',
      'zlib',
      'readline',
      'tty',
      'assert',
      'process',
    ],
    platform: 'node',
    target: 'node18',
    treeshake: true,
  },
]);
