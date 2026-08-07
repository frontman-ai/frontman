
import { execSync } from "node:child_process";
import { relative, resolve } from "node:path";
import {
  existsSync,
  rmSync,
  writeFileSync,
} from "node:fs";

const ROOT = resolve(import.meta.dirname, "../../..");
const FRONTMAN_SERVER = "localhost:4002";

function resetFixture(fixtureDir: string): void {
  const fixturePath = relative(ROOT, fixtureDir);
  execSync(`git checkout -- "${fixturePath}"`, { cwd: ROOT, stdio: "pipe" });
  execSync(`git clean -fd -- "${fixturePath}"`, { cwd: ROOT, stdio: "pipe" });
}

export function installNextjs(): void {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/nextjs");
  resetFixture(fixtureDir);
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

export function installVite(): void {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/vite");
  resetFixture(fixtureDir);
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

export function installVueVite(): void {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/vue-vite");
  resetFixture(fixtureDir);
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

export function installAstro(): void {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/astro");
  resetFixture(fixtureDir);
  rmSync(resolve(fixtureDir, ".astro"), { recursive: true, force: true });

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
