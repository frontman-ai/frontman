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
  symlinkSync,
  rmSync,
  writeFileSync,
} from "node:fs";

const ROOT = resolve(import.meta.dirname, "../../..");
const FRONTMAN_SERVER = "localhost:4002";

/**
 * Run the Frontman Next.js installer on the fixture project.
 * Creates middleware.ts and instrumentation.ts from templates.
 *
 * A temporary node_modules symlink is needed because the installer's
 * detect code reads `<projectDir>/node_modules/next/package.json` directly
 * (doesn't walk up), but Yarn hoists all deps to the root node_modules.
 */
export function installNextjs(): void {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/nextjs");
  const cli = resolve(ROOT, "libs/frontman-nextjs/dist/cli.js");
  if (!existsSync(cli)) {
    throw new Error(
      `[e2e] Next.js CLI not built. Run 'make build' in libs/frontman-nextjs first.\n  Missing: ${cli}`,
    );
  }

  // Create temp symlink so installer's detect code finds node_modules/next/
  const fixtureNm = resolve(fixtureDir, "node_modules");
  const rootNm = resolve(ROOT, "node_modules");
  const needsSymlink = !existsSync(fixtureNm);

  if (needsSymlink) {
    symlinkSync(rootNm, fixtureNm);
    console.log("  [e2e] Created temp node_modules symlink for installer");
  }

  try {
    console.log("  [e2e] Running Frontman Next.js installer...");
    execSync(
      `${process.execPath} ${cli} install --skip-deps --server ${FRONTMAN_SERVER}`,
      { cwd: fixtureDir, stdio: "inherit" },
    );
  } finally {
    // Remove temp symlink — Node.js resolution walks up to root node_modules anyway
    if (needsSymlink) {
      rmSync(fixtureNm, { recursive: true });
      console.log("  [e2e] Removed temp node_modules symlink");
    }
  }
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
