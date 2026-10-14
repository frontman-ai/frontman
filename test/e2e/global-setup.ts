/**
 * Vitest global setup — runs once before all e2e tests.
 *
 * 1. Creates + migrates the e2e database
 * 2. Seeds the test user + ChatGPT OAuth token
 * 3. Starts the Phoenix server (MIX_ENV=e2e)
 * 4. Starts the client Vite dev server (for serving the Frontman UI JS)
 * 5. Waits for both to be ready
 */

import { spawn, execSync, type ChildProcess } from "node:child_process";
import { resolve } from "node:path";
import { existsSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { startStripeListener, stopProcess } from "./helpers/real-services.js";

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

const TRUTHY_ENV_VALUES = new Set(["1", "true", "yes", "on"]);
const FALSY_ENV_VALUES = new Set(["0", "false", "no", "off"]);

function parseEnvBoolean(name: string, defaultValue: boolean): boolean {
  const rawValue = process.env[name];

  if (!rawValue || rawValue.trim() === "") {
    return defaultValue;
  }

  const normalizedValue = rawValue.trim().toLowerCase();

  if (TRUTHY_ENV_VALUES.has(normalizedValue)) {
    return true;
  }

  if (FALSY_ENV_VALUES.has(normalizedValue)) {
    return false;
  }

  throw new Error(
    `[e2e] ${name} must be one of ${JSON.stringify([...TRUTHY_ENV_VALUES, ...FALSY_ENV_VALUES])}; got: ${JSON.stringify(rawValue)}`,
  );
}

const E2E_ENV: NodeJS.ProcessEnv = {
  ...process.env,
  MIX_ENV: "e2e",
  PHX_SERVER: parseEnvBoolean("PHX_SERVER", true) ? "true" : "false",
} satisfies NodeJS.ProcessEnv;

let phoenixProc: ChildProcess | undefined;
let clientProc: ChildProcess | undefined;
let stripeProc: ChildProcess | undefined;
const signupBilling = parseEnvBoolean("E2E_SIGNUP_BILLING", false);
let databaseCreated = false;

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
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`[e2e] ${label} did not become ready within ${timeoutMs}ms`);
}

export async function setup() {
  try {
    await start();
  } catch (error) {
    try { await teardown(); } catch (cleanupError) {
      throw new AggregateError([error, cleanupError], "[e2e] Setup and cleanup failed");
    }
    throw error;
  }
}

async function start() {
  console.log("[e2e] Global setup starting…");
  if (signupBilling) {
    stripeProc = await startStripeListener();
    E2E_ENV.E2E_STRIPE_WEBHOOK_SECRET = process.env.E2E_STRIPE_WEBHOOK_SECRET;
    E2E_ENV.DB_NAME = process.env.DB_NAME = process.env.GITHUB_RUN_ID
      ? `frontman_server_e2e_${process.env.GITHUB_RUN_ID}`
      : `frontman_server_e2e_signup_${randomUUID().replaceAll("-", "")}`;
    if (!/^frontman_server_e2e_(signup_[a-f0-9]{32}|[0-9]+)$/.test(E2E_ENV.DB_NAME)) throw new Error("[e2e] Invalid run database name");
  }

  console.log("  [e2e] Creating and migrating e2e database…");
  execSync("mix ecto.create --quiet", { cwd: SERVER_DIR, env: E2E_ENV, stdio: "pipe" });
  databaseCreated = true;
  execSync("mix ecto.migrate --quiet", { cwd: SERVER_DIR, env: E2E_ENV, stdio: "pipe" });

  console.log("  [e2e] Seeding test user…");
  execSync("mix run priv/repo/e2e_seeds.exs", {
    cwd: SERVER_DIR,
    env: E2E_ENV,
    stdio: "inherit",
  });

  console.log("  [e2e] Starting Phoenix server on port", PHOENIX_PORT, "…");
  phoenixProc = spawn("mix", ["phx.server"], {
    cwd: SERVER_DIR,
    env: E2E_ENV,
    stdio: "pipe",
    detached: true,
  });
  phoenixProc.stdout?.on("data", (d: Buffer) => {
    const msg = d.toString();
    if (msg.includes("Running") || msg.includes("Access") || msg.includes("error") || msg.includes("Error")) {
      process.stdout.write(`  [phoenix] ${msg}`);
    }
  });
  phoenixProc.stderr?.on("data", (d: Buffer) => {
    const msg = d.toString();
    if (msg.includes("error") || msg.includes("Error")) {
      process.stderr.write(`  [phoenix] ${msg}`);
    }
  });

  console.log("  [e2e] Starting client Vite dev server on port", CLIENT_PORT, "…");
  const viteBin = resolveBin(CLIENT_DIR, "vite");
  clientProc = spawn(process.execPath, [viteBin, "--port", String(CLIENT_PORT), "--strictPort"], {
    cwd: CLIENT_DIR,
    env: { ...process.env },
    stdio: "pipe",
    detached: true,
  });
  clientProc.stdout?.on("data", (d: Buffer) => {
    const msg = d.toString();
    if (msg.includes("ready") || msg.includes("Local:") || msg.includes("Error")) {
      process.stdout.write(`  [client] ${msg}`);
    }
  });

  await Promise.all([
    waitForServer(`https://localhost:${PHOENIX_PORT}/users/log-in`, "Phoenix"),
    waitForServer(`http://localhost:${CLIENT_PORT}/src/Main.res.mjs`, "Client Vite"),
  ]);

  console.log("[e2e] Global setup complete.\n");
}

export async function teardown() {
  console.log("\n[e2e] Global teardown…");

  const results = await Promise.allSettled([clientProc, phoenixProc, stripeProc].map(stopProcess));
  const failures = results.filter(result => result.status === "rejected").map(result => result.reason);
  try {
    if (signupBilling && databaseCreated) {
      if (!/^frontman_server_e2e_(signup_[a-f0-9]{32}|[0-9]+)$/.test(E2E_ENV.DB_NAME!)) throw new Error("[e2e] Refusing unsafe DB cleanup");
      execSync("mix ecto.drop --quiet", { cwd: SERVER_DIR, env: E2E_ENV, stdio: "pipe", timeout: 60_000 });
      databaseCreated = false;
    }
  } catch (error) { failures.push(error); }
  if (failures.length) throw new AggregateError(failures, "[e2e] Cleanup failed");
  console.log("[e2e] Teardown complete.");
}
