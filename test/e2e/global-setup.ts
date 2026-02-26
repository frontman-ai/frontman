/**
 * Vitest global setup — runs once before all e2e tests.
 *
 * 1. Creates + migrates the e2e database
 * 2. Seeds the test user + ChatGPT OAuth token
 * 3. Starts the Phoenix server (E2E=true MIX_ENV=dev)
 * 4. Starts the client Vite dev server (for serving the Frontman UI JS)
 * 5. Waits for both to be ready
 */

import { spawn, execSync, type ChildProcess } from "node:child_process";
import { resolve } from "node:path";
import { existsSync } from "node:fs";

// Accept self-signed mkcert certificates for HTTPS health checks
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

const ROOT = resolve(import.meta.dirname, "../..");
const SERVER_DIR = resolve(ROOT, "apps/frontman_server");
const CLIENT_DIR = resolve(ROOT, "libs/client");

const PHOENIX_PORT = 4002;
const CLIENT_PORT = 5173;

/** Resolve a CLI binary by walking up node_modules/.bin from startDir. */
function resolveBin(startDir: string, name: string): string {
  let dir = startDir;
  while (true) {
    const binPath = resolve(dir, "node_modules", ".bin", name);
    if (existsSync(binPath)) return binPath;
    const parent = resolve(dir, "..");
    if (parent === dir) break;
    dir = parent;
  }
  throw new Error(`Cannot find binary '${name}' starting from ${startDir}`);
}

const E2E_ENV = {
  ...process.env,
  E2E: "true",
  MIX_ENV: "dev",
  PHX_SERVER: "true",
} satisfies NodeJS.ProcessEnv;

let phoenixProc: ChildProcess | undefined;
let clientProc: ChildProcess | undefined;

async function waitForServer(
  url: string,
  label: string,
  timeoutMs = 60_000,
): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(url).catch(() => null);
      if (res && (res.ok || res.status === 302 || res.status === 404)) {
        console.log(`  [e2e] ${label} ready at ${url}`);
        return;
      }
    } catch {
      // not ready yet
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`[e2e] ${label} did not become ready within ${timeoutMs}ms`);
}

export async function setup() {
  console.log("[e2e] Global setup starting…");

  // ── 1. Database setup ──────────────────────────────────────────────────────
  console.log("  [e2e] Creating and migrating e2e database…");
  execSync("mix ecto.create --quiet", { cwd: SERVER_DIR, env: E2E_ENV, stdio: "pipe" });
  execSync("mix ecto.migrate --quiet", { cwd: SERVER_DIR, env: E2E_ENV, stdio: "pipe" });

  // ── 2. Seed test user + ChatGPT token ──────────────────────────────────────
  console.log("  [e2e] Seeding test user…");
  execSync("mix run priv/repo/e2e_seeds.exs", {
    cwd: SERVER_DIR,
    env: E2E_ENV,
    stdio: "inherit",
  });

  // ── 3. Start Phoenix server ────────────────────────────────────────────────
  console.log("  [e2e] Starting Phoenix server on port", PHOENIX_PORT, "…");
  phoenixProc = spawn("mix", ["phx.server"], {
    cwd: SERVER_DIR,
    env: E2E_ENV,
    stdio: "pipe",
  });
  phoenixProc.stdout?.on("data", (d: Buffer) => {
    const msg = d.toString();
    if (msg.includes("Running") || msg.includes("Access") || msg.includes("error") || msg.includes("Error")) {
      process.stdout.write(`  [phoenix] ${msg}`);
    }
  });
  phoenixProc.stderr?.on("data", (d: Buffer) => {
    const msg = d.toString();
    // Surface errors but suppress normal Elixir compile chatter
    if (msg.includes("error") || msg.includes("Error")) {
      process.stderr.write(`  [phoenix] ${msg}`);
    }
  });

  // ── 4. Start client Vite dev server ────────────────────────────────────────
  console.log("  [e2e] Starting client Vite dev server on port", CLIENT_PORT, "…");
  const viteBin = resolveBin(CLIENT_DIR, "vite");
  clientProc = spawn(process.execPath, [viteBin, "--port", String(CLIENT_PORT), "--strictPort"], {
    cwd: CLIENT_DIR,
    env: { ...process.env },
    stdio: "pipe",
  });
  clientProc.stdout?.on("data", (d: Buffer) => {
    const msg = d.toString();
    if (msg.includes("ready") || msg.includes("Local:") || msg.includes("Error")) {
      process.stdout.write(`  [client] ${msg}`);
    }
  });

  // ── 5. Wait for readiness ──────────────────────────────────────────────────
  await Promise.all([
    waitForServer(`https://localhost:${PHOENIX_PORT}/users/log-in`, "Phoenix"),
    waitForServer(`http://localhost:${CLIENT_PORT}`, "Client Vite"),
  ]);

  console.log("[e2e] Global setup complete.\n");
}

export async function teardown() {
  console.log("\n[e2e] Global teardown…");

  if (clientProc) {
    clientProc.kill("SIGTERM");
    console.log("  [e2e] Client Vite dev server stopped.");
  }

  if (phoenixProc) {
    phoenixProc.kill("SIGTERM");
    console.log("  [e2e] Phoenix server stopped.");
  }

  console.log("[e2e] Teardown complete.");
}
