import { readFile, writeFile, rm } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = dirname(fileURLToPath(import.meta.url));
const [action, version] = process.argv.slice(2);
if (!["sync", "artifact"].includes(action) || !/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(version ?? "")) {
  throw new Error("Expected sync or artifact and a canonical X.Y.Z VERSION.");
}
if (action === "artifact") await rm(join(root, `frontman-wordpress-directory-v${version}.zip`), { force: true });
const changelog = await readFile(resolve(root, "../../CHANGELOG.md"), "utf8");
const headings = [...changelog.matchAll(/^## \[([^\]]+)\][^\r\n]*$/gm)];
const released = headings.find(heading => heading[1] !== "Unreleased");
if (!released || !new RegExp(`^## \\[${version.replaceAll(".", "\\.")}\\] - \\d{4}-\\d{2}-\\d{2}\\r?$`).test(released[0])) {
  throw new Error(`Top released changelog section must match VERSION ${version}.`);
}
const next = headings.find(heading => heading.index! > released.index!);
const notes = changelog.slice(released.index! + released[0].length, next?.index ?? changelog.length).trim();
if (!notes) throw new Error("Release notes are empty.");

const path = join(root, "plugin.json");
const plugin = JSON.parse(await readFile(path, "utf8"));
if (action === "sync") {
  plugin.version = version;
  plugin.extensions["com.openai"].publication ??= {};
  plugin.extensions["com.openai"].publication.release_notes = notes;
  await writeFile(path, JSON.stringify(plugin, null, 2) + "\n");
} else {
  if (plugin.version !== version || plugin.extensions["com.openai"].publication?.release_notes !== notes) {
    throw new Error("Manifest version or release notes do not match the changelog.");
  }
  const result = spawnSync(process.execPath, [join(root, "validate.mts"), "--package-draft", `--release-version=${version}`], { stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
  console.log("Candidate only: OpenAI portal validation and review are still required.");
}
