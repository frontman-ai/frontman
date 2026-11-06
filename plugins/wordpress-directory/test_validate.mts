import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, copyFile, readFile, writeFile, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const source = dirname(fileURLToPath(import.meta.url));
const modules = resolve(source, "../../node_modules");

async function fixture(withDependencies = true) {
  const root = await mkdtemp(join(tmpdir(), "frontman-test-"));
  const dir = join(root, "plugins/wordpress-directory");
  await mkdir(dir, { recursive: true });
  await mkdir(join(root, "apps/marketing/public"), { recursive: true });
  for (const file of ["validate.mts", "plugin.json", "mcp.json"]) await copyFile(join(source, file), join(dir, file));
  await copyFile(resolve(source, "../../apps/marketing/public/favicon.svg"), join(root, "apps/marketing/public/favicon.svg"));
  if (withDependencies) await symlink(modules, join(root, "node_modules"), "dir");
  return { root, dir };
}

function run(dir: string, ...args: string[]) {
  const env = { ...process.env };
  for (const key of ["REVIEW_CASES_VERIFIED", "OAUTH_VERIFIED", "POLICY_VERIFIED", "UPSTREAM_CONFLICT_RESOLVED"]) delete env[key];
  return spawnSync(process.execPath, [join(dir, "validate.mts"), ...args], { encoding: "utf8", env });
}

test("CLI validates the draft and rejects invalid manifests and missing evidence", async () => {
  const { root, dir } = await fixture();
  try {
    let result = run(dir);
    assert.equal(result.status, 0, result.stderr);
    const pluginPath = join(dir, "plugin.json");
    const plugin = JSON.parse(await readFile(pluginPath, "utf8"));
    plugin.unexpected = true;
    await writeFile(pluginPath, JSON.stringify(plugin));
    result = run(dir);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /plugin\.json: schema:/);
    delete plugin.unexpected;
    await writeFile(pluginPath, JSON.stringify(plugin));
    const mcpPath = join(dir, "mcp.json");
    const mcp = JSON.parse(await readFile(mcpPath, "utf8"));
    mcp.mcpServers.frontman.extensions["com.openai"].auth.unexpected = true;
    await writeFile(mcpPath, JSON.stringify(mcp));
    result = run(dir);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /OAuth settings/);
    delete mcp.mcpServers.frontman.extensions["com.openai"].auth.unexpected;
    await writeFile(mcpPath, JSON.stringify(mcp));
    result = run(dir, "--package");
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /demo_recording_url/);
    assert.match(result.stderr, /REVIEW_CASES_VERIFIED/);
    await assert.rejects(readFile(join(dir, "frontman-wordpress.zip")), { code: "ENOENT" });
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("CLI crashes when Ajv is missing", async () => {
  const { root, dir } = await fixture(false);
  try {
    const result = run(dir);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /ERR_MODULE_NOT_FOUND/);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("CLI crashes on malformed or missing manifests without creating an archive", async () => {
  const { root, dir } = await fixture();
  try {
    const manifest = join(dir, "plugin.json");
    const archive = join(dir, "frontman-wordpress.zip");
    await writeFile(manifest, "{");
    let result = run(dir, "--package");
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /SyntaxError/);
    await assert.rejects(readFile(archive), { code: "ENOENT" });

    await rm(manifest);
    result = run(dir, "--package");
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /ENOENT/);
    await assert.rejects(readFile(archive), { code: "ENOENT" });
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("OpenAI interface limits accept boundaries and reject overflows", async () => {
  const { root, dir } = await fixture();
  try {
    const path = join(dir, "plugin.json");
    const original = JSON.parse(await readFile(path, "utf8"));
    for (const [field, limit] of [["displayName", 30], ["shortDescription", 30], ["longDescription", 4000]] as const) {
      const plugin = structuredClone(original);
      plugin.extensions["com.openai"].interface[field] = "a".repeat(limit);
      await writeFile(path, JSON.stringify(plugin));
      let result = run(dir);
      assert.equal(result.status, 0, result.stderr);
      plugin.extensions["com.openai"].interface[field] += "a";
      await writeFile(path, JSON.stringify(plugin));
      result = run(dir);
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, new RegExp(`interface\\.${field}`));
    }
    for (const [field, count, length] of [["defaultPrompt", 3, 128], ["capabilities", 20, 120]] as const) {
      const plugin = structuredClone(original);
      const ui = plugin.extensions["com.openai"].interface;
      ui[field] = Array(count).fill("a".repeat(length));
      await writeFile(path, JSON.stringify(plugin));
      let result = run(dir);
      assert.equal(result.status, 0, result.stderr);
      ui[field][0] += "a";
      await writeFile(path, JSON.stringify(plugin));
      result = run(dir);
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, new RegExp(`interface\\.${field}`));
      ui[field][0] = "a";
      ui[field].push("a");
      await writeFile(path, JSON.stringify(plugin));
      result = run(dir);
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, new RegExp(`interface\\.${field}`));
    }
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
