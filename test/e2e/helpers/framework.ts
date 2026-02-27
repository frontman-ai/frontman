/**
 * Helpers for spawning framework dev servers and managing fixture projects.
 */

import { spawn, execSync, type ChildProcess } from "node:child_process";
import { resolve } from "node:path";
import { readFileSync, existsSync } from "node:fs";

const ROOT = resolve(import.meta.dirname, "../../..");

/**
 * Resolve a CLI binary by walking up the node_modules/.bin tree from `startDir`.
 * This avoids relying on `npx` which can hang in CI trying to download packages.
 */
function resolveBin(startDir: string, name: string): string {
  let dir = startDir;
  const checked: string[] = [];
  while (true) {
    const binPath = resolve(dir, "node_modules", ".bin", name);
    checked.push(binPath);
    if (existsSync(binPath)) {
      console.log(`  [e2e] Resolved ${name} → ${binPath}`);
      return binPath;
    }
    const parent = resolve(dir, "..");
    if (parent === dir) break;
    dir = parent;
  }
  throw new Error(
    `[e2e] Cannot find binary '${name}' starting from ${startDir}.\nChecked:\n  ${checked.join("\n  ")}`,
  );
}

export interface FrameworkServer {
  /** Dev server process */
  proc: ChildProcess;
  /** Port the dev server is listening on */
  port: number;
  /** Absolute path to the fixture directory */
  fixtureDir: string;
  /** The file that contains the heading text (for assertion) */
  headingFile: string;
}

/** Kill any process listening on the given port (works on macOS and Linux). */
function killPort(port: number): void {
  // Try lsof first (macOS + Linux with lsof installed)
  try {
    const pids = execSync(`lsof -ti:${port}`, { stdio: "pipe" })
      .toString()
      .trim();
    if (pids) {
      execSync(`kill -9 ${pids.split("\n").join(" ")}`, { stdio: "pipe" });
      console.log(`  [e2e] Killed existing process(es) on port ${port}`);
      return;
    }
  } catch {
    // lsof not available or no process — try fuser
  }
  // Fallback: fuser (common on Linux)
  try {
    execSync(`fuser -k ${port}/tcp`, { stdio: "pipe" });
    console.log(`  [e2e] Killed existing process(es) on port ${port} (fuser)`);
  } catch {
    // No process on that port — good
  }
}

/**
 * Wait until HTTP responds on the given URL.
 * Fails fast if the child process exits before becoming ready.
 */
async function waitForReady(
  proc: ChildProcess,
  url: string,
  label: string,
  timeoutMs = 90_000,
): Promise<void> {
  // Track early exit
  let exitError: string | undefined;
  proc.on("exit", (code, signal) => {
    if (signal) {
      exitError = `${label} process was killed by signal ${signal}`;
    } else if (code !== null && code !== 0) {
      exitError = `${label} process exited with code ${code}`;
    }
  });

  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (exitError) throw new Error(`[e2e] ${exitError}`);
    try {
      const res = await fetch(url).catch(() => null);
      // Any HTTP response means the server is up (even 500 from a render error)
      if (res) {
        console.log(`  [e2e] ${label} ready at ${url} (status ${res.status})`);
        return;
      }
    } catch {
      /* not ready */
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  // Timed out — kill the process so it doesn't leak
  proc.kill("SIGTERM");
  throw new Error(
    `[e2e] ${label} at ${url} did not become ready within ${timeoutMs}ms`,
  );
}

/** Pipe child process output to console for debugging. */
function logOutput(proc: ChildProcess, label: string): void {
  proc.stderr?.on("data", (d: Buffer) => {
    process.stderr.write(`  [${label}] ${d.toString()}`);
  });
  proc.stdout?.on("data", (d: Buffer) => {
    process.stdout.write(`  [${label}] ${d.toString()}`);
  });
}

// ── Next.js ──────────────────────────────────────────────────────────────────

export async function startNextjs(port: number): Promise<FrameworkServer> {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/nextjs");
  killPort(port);

  const nextBin = resolveBin(fixtureDir, "next");
  const proc = spawn(
    process.execPath,
    [nextBin, "dev", "--turbopack", "-p", String(port)],
    {
      cwd: fixtureDir,
      env: { ...process.env, PORT: String(port) } as NodeJS.ProcessEnv,
      stdio: "pipe",
    },
  );

  logOutput(proc, "nextjs");
  await waitForReady(proc, `http://127.0.0.1:${port}`, "Next.js");

  return {
    proc,
    port,
    fixtureDir,
    headingFile: resolve(fixtureDir, "pages/index.tsx"),
  };
}

// ── Astro ────────────────────────────────────────────────────────────────────

export async function startAstro(port: number): Promise<FrameworkServer> {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/astro");
  killPort(port);

  const astroBin = resolveBin(fixtureDir, "astro");
  const proc = spawn(
    process.execPath,
    [astroBin, "dev", "--host", "127.0.0.1", "--port", String(port)],
    {
      cwd: fixtureDir,
      env: { ...process.env } as NodeJS.ProcessEnv,
      stdio: "pipe",
    },
  );

  logOutput(proc, "astro");
  // Use 127.0.0.1 explicitly — Astro only binds to IPv4 and Node.js fetch
  // may resolve "localhost" to ::1 (IPv6) on Linux CI, causing connection failure.
  await waitForReady(proc, `http://127.0.0.1:${port}`, "Astro");

  return {
    proc,
    port,
    fixtureDir,
    headingFile: resolve(fixtureDir, "src/pages/index.astro"),
  };
}

// ── Vite ─────────────────────────────────────────────────────────────────────

export async function startVite(port: number): Promise<FrameworkServer> {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/vite");
  killPort(port);

  const viteBin = resolveBin(fixtureDir, "vite");
  const proc = spawn(
    process.execPath,
    [viteBin, "--host", "127.0.0.1", "--port", String(port), "--strictPort"],
    {
      cwd: fixtureDir,
      env: { ...process.env } as NodeJS.ProcessEnv,
      stdio: "pipe",
    },
  );

  logOutput(proc, "vite");
  // Use 127.0.0.1 explicitly — Vite only binds to IPv4 and Node.js fetch
  // may resolve "localhost" to ::1 (IPv6) on Linux CI, causing connection failure.
  await waitForReady(proc, `http://127.0.0.1:${port}`, "Vite");

  return {
    proc,
    port,
    fixtureDir,
    headingFile: resolve(fixtureDir, "src/App.tsx"),
  };
}

// ── Utilities ────────────────────────────────────────────────────────────────

/** Kill the dev server and restore any modified fixture files. */
export async function stopFramework(
  server: FrameworkServer | undefined,
): Promise<void> {
  if (!server) return;

  server.proc.kill("SIGTERM");

  // Restore modified tracked files (AI edits + installer-modified configs)
  try {
    execSync(`git checkout -- "${server.fixtureDir}"`, {
      cwd: ROOT,
      stdio: "pipe",
    });
  } catch {
    // Ignore errors if no files were modified
  }

  // Remove untracked files created by the installer (middleware.ts, instrumentation.ts)
  try {
    execSync(`git clean -fd -- "${server.fixtureDir}"`, {
      cwd: ROOT,
      stdio: "pipe",
    });
  } catch {
    // Ignore errors
  }
}

/** Read the heading file and check if it contains the expected text. */
export function headingFileContains(
  server: FrameworkServer,
  text: string,
): boolean {
  const content = readFileSync(server.headingFile, "utf-8");
  return content.includes(text);
}
