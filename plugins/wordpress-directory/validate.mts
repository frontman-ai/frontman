import { readFile, access, mkdtemp, mkdir, copyFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { isDeepStrictEqual } from "node:util";
import Ajv2020 from "ajv/dist/2020.js";

const root = dirname(fileURLToPath(import.meta.url));
const icon = resolve(root, "../../apps/marketing/public/favicon.svg");
const errors: string[] = [];
const fail = (message: string) => errors.push(message);
const packaging = process.argv.includes("--package");
const draft = process.argv.includes("--package-draft");
if (packaging && draft) throw new Error("Choose --package or --package-draft, not both.");

function httpsUrl(value: unknown): boolean {
  if (typeof value !== "string" || !URL.canParse(value)) return false;
  const url = new URL(value);
  return url.protocol === "https:" && !!url.hostname && !url.username && !url.password && !url.hash;
}

async function load(name: string): Promise<any> {
  return JSON.parse(await readFile(join(root, name), "utf8"));
}

const plugin = await load("plugin.json");
const mcp = await load("mcp.json");

for (const [name, document] of [["plugin.json", plugin], ["mcp.json", mcp]] as const) {
  const url = `https://agent-plugins.org/schemas/1.0.0/${name === "plugin.json" ? "plugin" : "mcp"}.schema.json`;
  if (document.$schema !== url) {
    fail(`${name}: expected the canonical Agent Plugins 1.0.0 schema URL.`);
    continue;
  }
  const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw new Error(`${name}: schema request failed with HTTP ${response.status}`);
  const schema = await response.json();
  const checked = structuredClone(document);
  if (name === "mcp.json" && !packaging && !process.argv.includes("--strict-upstream")) {
    for (const server of Object.values(checked.mcpServers ?? {}) as any[]) {
      if (server && typeof server === "object") delete server.extensions;
    }
  }
  const validate = new Ajv2020({ allErrors: true, strict: false }).compile(schema);
  if (!validate(checked)) {
    for (const error of validate.errors ?? []) {
      const property = error.params.additionalProperty;
      fail(`${name}: schema: ${error.instancePath || "/"} ${error.message}${property ? `: ${property}` : ""}`);
    }
  }
}

const extension = plugin.extensions["com.openai"];
const { interface: ui, review } = extension;
if (packaging && !httpsUrl(review.demo_recording_url)) fail("Add the real reviewer-accessible HTTPS demo_recording_url to plugin.json.");
for (const [kind, count] of [["positive", 5], ["negative", 3]] as const) {
  const entries = review.test_cases[kind];
  if (!Array.isArray(entries) || entries.length !== count) {
    fail(`Provide exactly ${count} ${kind} review cases.`);
    continue;
  }
  const fields = kind === "positive" ? ["description", "prompt", "tools_triggered", "expected_behavior"] : ["description", "prompt"];
  entries.forEach((entry: any, index: number) => {
    if (!entry || fields.some(field => typeof entry[field] !== "string" || !entry[field].trim())) fail(`${kind} case ${index + 1}: fill in ${fields.join(", ")}.`);
  });
}
for (const field of ["websiteURL", "supportURL", "privacyPolicyURL", "termsOfServiceURL"]) {
  if (!httpsUrl(ui[field])) fail(`interface.${field}: provide an HTTPS URL.`);
}
for (const field of ["logo", "composerIcon"]) {
  if (ui[field] !== "./assets/icon.svg") fail(`interface.${field}: update the packaging step for the chosen asset.`);
}
for (const [field, max] of [["displayName", 30], ["shortDescription", 30], ["longDescription", 4000]] as const) {
  if (typeof ui[field] !== "string" || ui[field].length > max) fail(`interface.${field}: expected a string of at most ${max} characters.`);
}
for (const [field, count, length] of [["defaultPrompt", 3, 128], ["capabilities", 20, 120]] as const) {
  if (!Array.isArray(ui[field]) || ui[field].length > count ||
      ui[field].some((value: unknown) => typeof value !== "string" || value.length > length)) {
    fail(`interface.${field}: expected at most ${count} strings of at most ${length} characters each.`);
  }
}
await access(icon);

if (!isDeepStrictEqual(mcp.mcpServers, {
  frontman: {
    type: "streamable-http",
    url: "https://api.frontman.sh/mcp",
    extensions: { "com.openai": { auth: { type: "oauth", client: { mode: "cimd" } } } },
  },
})) fail("Review the endpoint and OAuth settings; update the checker if intentionally changed.");

if (packaging) {
  for (const [variable, instruction] of [
    ["REVIEW_CASES_VERIFIED", "Run all eight review cases in ChatGPT using the staging account"],
    ["OAUTH_VERIFIED", "Verify the production ChatGPT OAuth and login flow"],
    ["POLICY_VERIFIED", "Audit the full catalog, tool annotations and OpenAI policies"],
  ]) {
    if (process.env[variable] !== "yes") fail(`${instruction}; then set ${variable}=yes for this invocation.`);
  }
}

if (errors.length) {
  for (const error of errors) console.error(`ERROR: ${error}`);
  process.exit(1);
}

if (packaging || draft) {
  const staging = await mkdtemp(join(tmpdir(), "frontman-plugin-"));
  try {
    await mkdir(join(staging, "assets"));
    await copyFile(join(root, "plugin.json"), join(staging, "plugin.json"));
    await copyFile(join(root, "mcp.json"), join(staging, "mcp.json"));
    await copyFile(icon, join(staging, "assets/icon.svg"));
    const output = join(root, draft ? "frontman-wordpress-draft.zip" : "frontman-wordpress.zip");
    const archive = join(staging, "package.zip");
    const result = spawnSync("zip", ["-q", archive, "plugin.json", "mcp.json", "assets/icon.svg"], { cwd: staging, encoding: "utf8" });
    if (result.error || result.status !== 0) throw new Error(`zip failed: ${result.error ?? result.stderr}`);
    await copyFile(archive, output);
    console.log(`Created ${output}`);
  } finally {
    await rm(staging, { recursive: true, force: true });
  }
} else {
  console.log("Local checks passed. OpenAI portal validation and review are still required.");
}
