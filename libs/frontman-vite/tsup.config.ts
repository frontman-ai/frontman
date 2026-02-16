import { defineConfig } from 'tsup';

const nodeBuiltins = [
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
  'node:fs',
  'node:path',
  'node:os',
  'node:child_process',
  'node:crypto',
  'node:util',
  'node:stream',
  'node:events',
  'node:buffer',
  'node:url',
  'node:http',
  'node:https',
  'node:module',
];

const internalDeps = [
  '@frontman/frontman-core',
  '@frontman/frontman-protocol',
  '@frontman/bindings',
  '@rescript/runtime',
  'sury',
  'dom-element-to-component-source',
];

export default defineConfig([
  // Main entry point
  {
    entry: { 'index': './src/FrontmanVite.res.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: true,
    dts: true,
    noExternal: internalDeps,
    external: ['vite', ...nodeBuiltins],
    platform: 'node',
    target: 'node18',
    treeshake: true,
  },
  // CLI entry point
  {
    entry: { 'cli': './src/cli/cli.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: false,
    noExternal: internalDeps,
    external: ['vite', ...nodeBuiltins],
    platform: 'node',
    target: 'node18',
    treeshake: true,
    banner: {
      js: '#!/usr/bin/env node',
    },
  },
]);
