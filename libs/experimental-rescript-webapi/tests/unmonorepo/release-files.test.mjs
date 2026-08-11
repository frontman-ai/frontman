import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

test("docs and CI point at the unified package layout", () => {
  const readme = fs.readFileSync("README.md", "utf8");
  const docsIndex = fs.readFileSync("docs/content/docs/index.mdx", "utf8");
  const docsPhilosophy = fs.readFileSync("docs/content/docs/philosophy.mdx", "utf8");
  const docsContributing = fs.readFileSync("docs/content/docs/contributing/api-modelling.mdx", "utf8");
  const docsLlm = fs.readFileSync("docs/llm.js", "utf8");
  const docsUtils = fs.readFileSync("docs/utils.js", "utf8");
  const designSpec = fs.readFileSync(
    "docs/superpowers/specs/2026-04-22-unmonorepo-webapi-design.md",
    "utf8",
  );
  const workflow = fs.readFileSync(".github/workflows/ci.yml", "utf8");

  assert.match(readme, /npm i @rescript\/webapi@experimental/);
  assert.match(readme, /WebAPI\.Window\.current/);
  assert.doesNotMatch(readme, /WebAPI\.Global/);
  assert.match(docsIndex, /ReScript WebAPI/);
  assert.match(docsIndex, /WebAPI\.Window\.current/);
  assert.doesNotMatch(docsIndex, /WebAPI\.Global/);
  assert.match(docsIndex, /location->WebAPI\.Location\.reload/);
  assert.match(docsPhilosophy, /open WebAPI\.DOM/);
  assert.doesNotMatch(docsPhilosophy, /WebAPI\.DomGlobal/);
  assert.match(docsPhilosophy, /let myElement: WebAPI\.Element\.t = document->WebAPI\.Document\.createElement/);
  assert.match(docsPhilosophy, /let node: WebAPI\.Node\.t = element->WebAPI\.Element\.asNode/);
  assert.match(docsContributing, /open WebAPI/);
  assert.doesNotMatch(docsContributing, /open WebAPI\.DOM/);
  assert.match(designSpec, /original flat public API module shape/);
  assert.match(designSpec, /Use `WebAPI\.\*` spelling, not `WebApi\.\*`\./);
  assert.match(docsLlm, /rescript\.json/);
  assert.match(docsLlm, /source\.public/);
  assert.match(docsLlm, /isPublicFile\(filePath\)/);
  assert.match(docsUtils, /path\.resolve\(process\.cwd\(\), "src"\)/);
  assert.match(docsUtils, /rescript\.json/);
  assert.match(docsUtils, /source\.public/);
  assert.match(docsUtils, /publicModules\.has/);
  assert.doesNotMatch(docsUtils, /path\.resolve\(process\.cwd\(\), "packages"\)/);
  assert.match(workflow, /npm pack\b/);
  assert.match(workflow, /npm publish --access public --tag experimental/);
  assert.doesNotMatch(workflow, /--workspaces|publish --workspace|packages\/\*/);
});

test("root rescript.json keeps generated type modules internal", () => {
  const config = JSON.parse(fs.readFileSync("rescript.json", "utf8"));
  const sourceEntries = config.sources.filter((source) => source.dir?.startsWith("src/"));

  assert.ok(sourceEntries.length > 0);

  for (const source of sourceEntries) {
    assert.ok(Array.isArray(source.public), `${source.dir} should explicitly list public modules`);
    assert.deepEqual(
      source.public.filter((moduleName) => moduleName.endsWith("Types")),
      [],
      `${source.dir} should not expose *Types modules`,
    );
    assert.deepEqual(
      source.public.filter((moduleName) => moduleName.includes("Global")),
      [],
      `${source.dir} should not expose Global or GlobalScope modules`,
    );
  }

  const domSource = sourceEntries.find((source) => source.dir === "src/DOM");
  assert.ok(domSource, "src/DOM source entry should exist");
  assert.ok(!domSource.public.includes("DomGlobal"), "src/DOM should keep DomGlobal internal");

  const visualViewportSource = sourceEntries.find((source) => source.dir === "src/VisualViewport");
  assert.ok(visualViewportSource, "src/VisualViewport source entry should exist");
  assert.ok(
    visualViewportSource.public.includes("VisualViewport"),
    "src/VisualViewport should expose a public VisualViewport module",
  );
});
