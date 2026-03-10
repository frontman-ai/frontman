/**
 * Helpers to run the Frontman installer CLIs on bare fixture projects.
 *
 * The E2E fixtures start as minimal framework projects without Frontman.
 * Before each test, we run the installer to set up Frontman integration,
 * verifying that the installer produces working configs.
 *
 * - Next.js / Vite: Use the real CLI (`frontman-nextjs install`, `frontman-vite install`)
 * - Astro: Programmatic config (Astro has no dedicated Frontman CLI — users run `astro add`)
 */

import { execSync } from "node:child_process";
import { resolve } from "node:path";
import {
  existsSync,
  writeFileSync,
} from "node:fs";

const ROOT = resolve(import.meta.dirname, "../../..");
const FRONTMAN_SERVER = "localhost:4002";

/**
 * Run the Frontman Next.js installer on the fixture project.
 * Creates middleware.ts and instrumentation.ts from templates.
 *
 * The installer uses Node.js module resolution (createRequire) to find
 * next/package.json, so it handles monorepo hoisting automatically —
 * no symlink workaround needed.
 */
export function installNextjs(): void {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/nextjs");
  const cli = resolve(ROOT, "libs/frontman-nextjs/dist/cli.js");
  if (!existsSync(cli)) {
    throw new Error(
      `[e2e] Next.js CLI not built. Run 'make build' in libs/frontman-nextjs first.\n  Missing: ${cli}`,
    );
  }

  console.log("  [e2e] Running Frontman Next.js installer...");
  execSync(
    `${process.execPath} ${cli} install --skip-deps --server ${FRONTMAN_SERVER}`,
    { cwd: fixtureDir, stdio: "inherit" },
  );
}

/**
 * Run the Frontman Vite installer on the fixture project.
 * Injects frontmanPlugin into the existing vite.config.ts.
 *
 * No node_modules symlink needed — the Vite installer only checks
 * package.json for a `vite` dependency (doesn't read node_modules).
 */
export function installVite(): void {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/vite");
  const cli = resolve(ROOT, "libs/frontman-vite/dist/cli.js");
  if (!existsSync(cli)) {
    throw new Error(
      `[e2e] Vite CLI not built. Run 'make build' in libs/frontman-vite first.\n  Missing: ${cli}`,
    );
  }

  console.log("  [e2e] Running Frontman Vite installer...");
  execSync(
    `${process.execPath} ${cli} install --skip-deps --server ${FRONTMAN_SERVER}`,
    { cwd: fixtureDir, stdio: "inherit" },
  );
}

/**
 * Run the Frontman Vite installer on the Vue fixture project.
 * Same as installVite() but targets the vue-vite fixture directory.
 *
 * The Vite CLI installer is framework-agnostic — it detects `vite` in
 * package.json and injects `frontmanPlugin()` into vite.config.ts.
 */
export function installVueVite(): void {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/vue-vite");
  const cli = resolve(ROOT, "libs/frontman-vite/dist/cli.js");
  if (!existsSync(cli)) {
    throw new Error(
      `[e2e] Vite CLI not built. Run 'make build' in libs/frontman-vite first.\n  Missing: ${cli}`,
    );
  }

  console.log("  [e2e] Running Frontman Vite installer (Vue fixture)...");
  execSync(
    `${process.execPath} ${cli} install --skip-deps --server ${FRONTMAN_SERVER}`,
    { cwd: fixtureDir, stdio: "inherit" },
  );
}

/**
 * Configure Frontman Astro integration in the fixture project.
 *
 * Astro has no dedicated Frontman CLI — users run `npx astro add @frontman-ai/astro`.
 * We programmatically write the integration config (equivalent to what `astro add` does).
 */
export function installAstro(): void {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/astro");

  console.log("  [e2e] Configuring Frontman Astro integration...");
  const config = `import { defineConfig } from 'astro/config';
import frontman from '@frontman-ai/astro';

export default defineConfig({
  integrations: [
    frontman({
      host: '${FRONTMAN_SERVER}',
      projectRoot: import.meta.dirname,
    }),
  ],
});
`;
  writeFileSync(resolve(fixtureDir, "astro.config.mjs"), config);
  console.log("  [e2e] \u2713 astro.config.mjs configured with Frontman integration");
}
