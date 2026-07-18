import assert from "node:assert/strict"
import {spawn} from "node:child_process"
import {createRequire} from "node:module"
import {dirname, resolve} from "node:path"
import test from "node:test"

const port = Number(process.env.COMPAT_PORT || 4327)
const origin = `http://127.0.0.1:${port}`
const require = createRequire(import.meta.url)
const astroPackagePath = require.resolve("astro/package.json")
const astroPackage = require(astroPackagePath)
const astroBin = resolve(dirname(astroPackagePath), astroPackage.bin.astro)

async function waitForServer(process, output) {
  for (let attempt = 0; attempt < 180; attempt++) {
    assert.equal(process.exitCode, null, `Astro exited before startup:\n${output.value}`)

    try {
      const response = await fetch(origin)
      if (response.ok) return
    } catch {}

    await new Promise(resolve => setTimeout(resolve, 500))
  }

  assert.fail(`Astro did not start:\n${output.value}`)
}

test("packed integration works in Astro dev server", {timeout: 120_000}, async t => {
  const output = {value: ""}
  const astro = spawn(
    process.execPath,
    [astroBin, "dev", "--host", "127.0.0.1", "--port", String(port)],
    {
      cwd: import.meta.dirname + "/..",
      env: {...process.env, ASTRO_DEV_BACKGROUND: "0"},
      stdio: ["ignore", "pipe", "pipe"],
    },
  )

  t.after(() => astro.kill("SIGTERM"))
  astro.stdout.on("data", chunk => (output.value += chunk))
  astro.stderr.on("data", chunk => (output.value += chunk))
  await waitForServer(astro, output)

  const pageResponse = await fetch(origin)
  const pageHtml = await pageResponse.text()
  assert.equal(pageResponse.status, 200)
  assert.match(pageHtml, /Hello\s+<!--.*?-->Astro|Hello Astro/s)
  assert.match(pageHtml, /data-(?:frontman|astro)-source-file=/)
  assert.match(pageHtml, /src\/components\/Greeting\.astro/)

  const markdownResponse = await fetch(`${origin}/docs/`)
  const markdownHtml = await markdownResponse.text()
  assert.equal(markdownResponse.status, 200)
  assert.match(markdownHtml, /<template data-frontman-content-file="src\/pages\/docs\.md"><\/template>/)

  const frontmanResponse = await fetch(`${origin}/frontman/`)
  assert.equal(frontmanResponse.status, 200)

  const toolResponse = await fetch(`${origin}/frontman/tools/call/`, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({name: "get_client_pages", arguments: {}}),
  })
  const body = await toolResponse.text()
  assert.equal(toolResponse.status, 200)
  assert.match(body, /index\.astro/)
  assert.match(body, /\[slug\]\.astro/)
  assert.match(body, /health\.json\.ts/)
})
