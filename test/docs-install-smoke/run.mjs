import assert from "node:assert/strict"
import {mkdtemp, mkdir, readFile, rm, writeFile} from "node:fs/promises"
import {tmpdir} from "node:os"
import path from "node:path"
import {spawn} from "node:child_process"
import net from "node:net"

const fixtureRoot = await mkdtemp(path.join(tmpdir(), "frontman-docs-install-"))
const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds))
const activeChildren = new Set()
const childClosed = new WeakMap()

const spawnChild = (command, args, options) => {
  const child = spawn(command, args, {
    ...options,
    detached: process.platform !== "win32",
  })
  activeChildren.add(child)
  childClosed.set(
    child,
    new Promise(resolve =>
      child.once("close", (code, signal) => {
        activeChildren.delete(child)
        resolve({code, signal})
      }),
    ),
  )
  return child
}

const signalChildGroup = (child, signal) => {
  if (process.platform === "win32") {
    if (child.exitCode !== null || child.signalCode !== null) return
    child.kill(signal)
  } else {
    try {
      process.kill(-child.pid, signal)
    } catch (error) {
      if (error.code !== "ESRCH") throw error
    }
  }
}

const stopChild = async child => {
  const closed = childClosed.get(child)
  if (child.exitCode === null && child.signalCode === null) {
    signalChildGroup(child, "SIGTERM")
  }

  const didClose = await Promise.race([closed.then(() => true), sleep(5_000).then(() => false)])
  if (!didClose) {
    signalChildGroup(child, "SIGKILL")
    await closed
  }
}

const stopAllChildren = () => Promise.all([...activeChildren].map(stopChild))

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.once(signal, async () => {
    await stopAllChildren()
    process.exit(signal === "SIGINT" ? 130 : 143)
  })
}

const run = (command, args, cwd) =>
  new Promise((resolve, reject) => {
    const child = spawnChild(command, args, {
      cwd,
      stdio: "inherit",
    })
    let timedOut = false
    const timeout = setTimeout(async () => {
      timedOut = true
      await stopChild(child)
      reject(new Error(`${command} ${args.join(" ")} timed out after 5 minutes`))
    }, 300_000)
    child.on("error", error => {
      clearTimeout(timeout)
      reject(error)
    })
    child.on("exit", code => {
      clearTimeout(timeout)
      if (timedOut) return
      if (code === 0) {
        resolve()
      } else {
        reject(new Error(`${command} ${args.join(" ")} exited with code ${code}`))
      }
    })
  })

const writeJson = (filePath, value) =>
  writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`)

const getPort = () =>
  new Promise((resolve, reject) => {
    const server = net.createServer()
    server.on("error", reject)
    server.listen(0, "127.0.0.1", () => {
      const address = server.address()
      assert.notEqual(address, null)
      assert.equal(typeof address, "object")
      server.close(() => resolve(address.port))
    })
  })

const assertFrontmanRoute = async ({cwd, command, args, framework}) => {
  const port = await getPort()
  const child = spawnChild(command, args(port), {
    cwd,
    stdio: ["ignore", "pipe", "pipe"],
  })
  let output = ""
  child.stdout.on("data", chunk => (output += chunk))
  child.stderr.on("data", chunk => (output += chunk))

  try {
    const deadline = Date.now() + 30_000
    while (Date.now() < deadline) {
      if (child.exitCode !== null || child.signalCode !== null) {
        throw new Error(
          `${framework} dev server exited with ${child.signalCode ?? `code ${child.exitCode}`}\n${output}`,
        )
      }
      try {
        const response = await fetch(`http://127.0.0.1:${port}/frontman`)
        if (response.ok) {
          const html = await response.text()
          assert.match(html, /<title>Frontman<\/title>/)
          assert.match(html, new RegExp(`"framework":"${framework}"`))
          return
        }
      } catch {
        // Server is still starting.
      }
      await sleep(500)
    }
    throw new Error(`/${framework} fixture did not serve /frontman\n${output}`)
  } finally {
    await stopChild(child)
  }
}

const smokeNext = async () => {
  const cwd = path.join(fixtureRoot, "nextjs")
  await mkdir(path.join(cwd, "app"), {recursive: true})
  await writeJson(path.join(cwd, "package.json"), {
    private: true,
    scripts: {dev: "next dev"},
    dependencies: {next: "^16.0.0", react: "^19.0.0", "react-dom": "^19.0.0"},
  })
  await writeFile(
    path.join(cwd, "app", "layout.jsx"),
    "export default function Layout({children}) { return <html><body>{children}</body></html> }\n",
  )
  await writeFile(path.join(cwd, "app", "page.jsx"), "export default function Page() { return <button>Edit me</button> }\n")

  await run("npm", ["install"], cwd)
  await run("npx", ["--yes", "@frontman-ai/nextjs", "install"], cwd)
  assert.match(await readFile(path.join(cwd, "proxy.ts"), "utf8"), /createMiddleware/)
  assert.match(await readFile(path.join(cwd, "instrumentation.ts"), "utf8"), /@frontman-ai\/nextjs/)
  await assertFrontmanRoute({
    cwd,
    command: "npm",
    args: port => ["run", "dev", "--", "--hostname", "127.0.0.1", "--port", String(port)],
    framework: "nextjs",
  })
}

const smokeVite = async () => {
  const cwd = path.join(fixtureRoot, "vite")
  await mkdir(cwd, {recursive: true})
  await writeJson(path.join(cwd, "package.json"), {
    private: true,
    type: "module",
    scripts: {dev: "vite"},
    devDependencies: {"@vitejs/plugin-react": "latest", vite: ">=5.0.0"},
  })
  await writeFile(path.join(cwd, "index.html"), "<!doctype html><button>Edit me</button>\n")
  await writeFile(
    path.join(cwd, "vite.config.js"),
    "import {defineConfig} from 'vite'\nimport react from '@vitejs/plugin-react'\nexport default defineConfig({plugins: [react()]})\n",
  )

  await run("npm", ["install"], cwd)
  await run("npx", ["--yes", "@frontman-ai/vite", "install"], cwd)
  assert.match(await readFile(path.join(cwd, "vite.config.js"), "utf8"), /frontmanPlugin/)
  await assertFrontmanRoute({
    cwd,
    command: "npm",
    args: port => ["run", "dev", "--", "--host", "127.0.0.1", "--port", String(port)],
    framework: "vite",
  })
}

const smokeAstro = async () => {
  const cwd = path.join(fixtureRoot, "astro")
  await mkdir(path.join(cwd, "src", "pages"), {recursive: true})
  await writeJson(path.join(cwd, "package.json"), {
    private: true,
    type: "module",
    scripts: {dev: "astro dev"},
    dependencies: {astro: "^6.0.0"},
  })
  await writeFile(path.join(cwd, "astro.config.mjs"), "import {defineConfig} from 'astro/config'\nexport default defineConfig({})\n")
  await writeFile(path.join(cwd, "src", "pages", "index.astro"), "<button>Edit me</button>\n")

  await run("npm", ["install"], cwd)
  await run("npx", ["--yes", "astro", "add", "@frontman-ai/astro", "--yes"], cwd)
  assert.match(await readFile(path.join(cwd, "astro.config.mjs"), "utf8"), /frontmanAi/)
  await assertFrontmanRoute({
    cwd,
    command: "npm",
    args: port => ["run", "dev", "--", "--host", "127.0.0.1", "--port", String(port)],
    framework: "astro",
  })
}

try {
  await smokeNext()
  await smokeVite()
  await smokeAstro()
  console.log("Published installer smoke check passed for Next.js, Vite, and Astro.")
} finally {
  await stopAllChildren()
  if (process.env.KEEP_SMOKE_FIXTURES === "1") {
    console.log(`Fixtures retained at ${fixtureRoot}`)
  } else {
    await rm(fixtureRoot, {recursive: true, force: true})
  }
}
