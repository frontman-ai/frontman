/**
 * Helpers for spawning framework dev servers and managing fixture projects.
 */

import { spawn, execSync, type ChildProcess } from "node:child_process";
import { relative, resolve } from "node:path";
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
  /** Throws if the dev server logged a known-fatal error. */
  assertHealthy?: () => void;
}

/** Kill any process listening on the given port (works on macOS and Linux). */
function killPort(port: number): void {
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
  }
  try {
    execSync(`fuser -k ${port}/tcp`, { stdio: "pipe" });
    console.log(`  [e2e] Killed existing process(es) on port ${port} (fuser)`);
  } catch {
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
      if (res) {
        console.log(`  [e2e] ${label} ready at ${url} (status ${res.status})`);
        return;
      }
    } catch {
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  proc.kill("SIGTERM");
  throw new Error(
    `[e2e] ${label} at ${url} did not become ready within ${timeoutMs}ms`,
  );
}

/** Pipe child process output to console for debugging. */
function logOutput(
  proc: ChildProcess,
  label: string,
  onOutput?: (text: string) => void,
): void {
  proc.stderr?.on("data", (d: Buffer) => {
    const text = d.toString();
    onOutput?.(text);
    process.stderr.write(`  [${label}] ${text}`);
  });
  proc.stdout?.on("data", (d: Buffer) => {
    const text = d.toString();
    onOutput?.(text);
    process.stdout.write(`  [${label}] ${text}`);
  });
}


export async function startNextjs(port: number): Promise<FrameworkServer> {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/nextjs");
  killPort(port);
  let outputBuffer = "";
  let fatalError: string | undefined;

  const assertHealthy = () => {
    if (fatalError) throw new Error(`[e2e] ${fatalError}`);
  };

  const watchOutput = (text: string) => {
    outputBuffer = `${outputBuffer}${text}`.slice(-8_000);
    if (outputBuffer.includes("Route segment config is not allowed in Proxy file")) {
      fatalError = "Next.js rejected generated proxy.ts route config";
    }
  };

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

  logOutput(proc, "nextjs", watchOutput);
  await waitForReady(proc, `http://127.0.0.1:${port}`, "Next.js");
  assertHealthy();

  return {
    proc,
    port,
    fixtureDir,
    headingFile: resolve(fixtureDir, "pages/index.tsx"),
    assertHealthy,
  };
}


export async function startAstro(port: number): Promise<FrameworkServer> {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/astro");
  killPort(port);

  const astroBin = resolveBin(fixtureDir, "astro");
  const astroEnv = { ...process.env, ASTRO_DEV_BACKGROUND: "0" };
  delete astroEnv.VITEST;
  const proc = spawn(
    process.execPath,
    [astroBin, "dev", "--host", "127.0.0.1", "--port", String(port)],
    {
      cwd: fixtureDir,
      env: astroEnv,
      stdio: "pipe",
    },
  );

  logOutput(proc, "astro");
  await waitForReady(proc, `http://127.0.0.1:${port}`, "Astro");

  return {
    proc,
    port,
    fixtureDir,
    headingFile: resolve(fixtureDir, "src/pages/index.astro"),
  };
}


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
  await waitForReady(proc, `http://127.0.0.1:${port}`, "Vite");

  return {
    proc,
    port,
    fixtureDir,
    headingFile: resolve(fixtureDir, "src/App.tsx"),
  };
}


export async function startVueVite(port: number): Promise<FrameworkServer> {
  const fixtureDir = resolve(ROOT, "test/e2e/fixtures/vue-vite");
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

  logOutput(proc, "vue-vite");
  await waitForReady(proc, `http://127.0.0.1:${port}`, "Vue + Vite");

  return {
    proc,
    port,
    fixtureDir,
    headingFile: resolve(fixtureDir, "src/App.vue"),
  };
}


/** Kill the dev server and restore any modified fixture files. */
export async function stopFramework(
  server: FrameworkServer | undefined,
): Promise<void> {
  if (!server) return;

  server.proc.kill("SIGTERM");
  const fixturePath = relative(ROOT, server.fixtureDir);

  try {
    execSync(`git checkout -- "${fixturePath}"`, {
      cwd: ROOT,
      stdio: "pipe",
    });
  } catch {
  }

  try {
    execSync(`git clean -fd -- "${fixturePath}"`, {
      cwd: ROOT,
      stdio: "pipe",
    });
  } catch {
  }
}

/** Read the heading file and check if it contains the expected text. */
export function headingFileContains(
  server: FrameworkServer,
  text: string,
): boolean {
  if (!existsSync(server.headingFile)) {
    console.log(`  [e2e] headingFileContains: file NOT FOUND at ${server.headingFile}`);
    return false;
  }
  const content = readFileSync(server.headingFile, "utf-8");
  const found = content.includes(text);
  if (!found) {
    console.log(`  [e2e] headingFileContains: "${text}" NOT found in ${server.headingFile}`);
    console.log(`  [e2e] File contents (first 500 chars):\n${content.substring(0, 500)}`);
  } else {
    console.log(`  [e2e] headingFileContains: "${text}" found ✓`);
  }
  return found;
}
