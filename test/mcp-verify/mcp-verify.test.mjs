import assert from "node:assert/strict"
import {readFileSync} from "node:fs"
import test from "node:test"

const makefile = readFileSync(new URL("../../Makefile", import.meta.url), "utf8")

const targetBody = name => {
  const match = makefile.match(new RegExp(`^${name}:\\n((?:\\t.*\\n)+)`, "m"))
  assert.ok(match, `${name} target is missing`)
  return match[1]
}

test("root MCP verification runs its configured aggregate gates serially", () => {
  const body = targetBody("mcp-verify")
  const commands = [
    "$(MAKE) mcp-verify-preflight",
    "node --test test/mcp-verify/mcp-verify.test.mjs",
    "$(MAKE) -C libs/frontman-protocol mcp-verify",
    "$(MAKE) -C libs/frontman-client lint",
    "$(MAKE) -C libs/frontman-client test",
    "$(MAKE) -C libs/frontman-core lint",
    "$(MAKE) -C libs/frontman-core test",
    "$(MAKE) -C libs/frontman-nextjs lint",
    "$(MAKE) -C libs/frontman-nextjs test",
    "$(MAKE) -C libs/frontman-astro lint",
    "$(MAKE) -C libs/frontman-astro test",
    "$(MAKE) -C libs/frontman-vite lint",
    "$(MAKE) -C libs/frontman-vite test",
    "$(MAKE) -C libs/frontman-astro-browser lint",
    "$(MAKE) -C libs/frontman-astro-browser test",
    "$(MAKE) -C libs/client lint",
    "$(MAKE) -C libs/client test",
    "$(MAKE) -C libs/logs check",
    "$(MAKE) -C libs/react-statestore check",
    "$(MAKE) -C apps/swarm_ai lint",
    "$(MAKE) -C apps/swarm_ai test",
    "$(MAKE) -C apps/frontman_server lint",
    "$(MAKE) -C apps/frontman_server test",
    "$(MAKE) -C apps/frontman_notifier lint",
    "$(MAKE) -C apps/frontman_notifier test",
    "$(MAKE) -C apps/marketing test",
    "$(MAKE) -C apps/marketing build",
    "$(MAKE) test-wordpress-core-tools",
    "$(MAKE) test-wordpress-runtime",
    "$(MAKE) -C test/astro-compat test",
    "$(MAKE) mcp-blackbox",
    "$(MAKE) mcp-conformance",
    "$(MAKE) e2e",
    "$(MAKE) check-source-comments",
    "$(MAKE) mcp-check-generated",
    '@printf "$(GREEN)MCP aggregate verification passed.$(RESET)\\n"',
  ]
  const recipe = body.trimEnd().split("\n").map(line => line.slice(1))
  assert.deepEqual(recipe, commands)
})

test("root MCP verification rejects missing credentialed E2E configuration", () => {
  const body = targetBody("mcp-verify-preflight")
  assert.match(body, /test -f test\/e2e\/\.env/)
  assert.match(body, /Credentialed MCP verification is unavailable/)
  assert.match(body, /exit 1/)
})

test("root MCP verification checks generated schemas and browser assets", () => {
  const body = targetBody("mcp-check-generated")
  assert.match(body, /\$\(MAKE\) -C libs\/frontman-protocol check-schemas/)
  assert.match(body, /mix esbuild browser_test/)
  assert.match(body, /cp -R apps\/frontman_server\/priv\/static\/browser-test/)
  assert.match(body, /diff -ru .*browser-test.*priv\/static\/browser-test/)
})
