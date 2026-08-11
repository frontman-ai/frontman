import assert from "node:assert/strict"
import {execFileSync, spawnSync} from "node:child_process"
import {mkdirSync, mkdtempSync, readFileSync, writeFileSync} from "node:fs"
import {tmpdir} from "node:os"
import {dirname, join} from "node:path"
import test from "node:test"
import {fileURLToPath} from "node:url"

import {classifyFile, fixSource, repositoryFiles, scanSource, trackedFiles} from "../../scripts/no-comments.mjs"

for (const variable of execFileSync("git", ["rev-parse", "--local-env-vars"], {encoding: "utf8"}).trim().split("\n")) {
  delete process.env[variable]
}

const here = dirname(fileURLToPath(import.meta.url))
const fixtures = join(here, "fixtures")
const manifest = JSON.parse(readFileSync(join(fixtures, "manifest.json"), "utf8"))
const scanner = join(here, "../../scripts/no-comments.mjs")

function fixture(group, file) {
  return readFileSync(join(fixtures, group, `${file}.txt`), "utf8")
}

test("reject fixtures contain source comments", () => {
  for (const file of manifest.reject) {
    const source = fixture("reject", file)
    assert.notEqual(classifyFile(file, source), null, file)
    assert.ok(scanSource(file, source).length > 0, file)
  }
})

test("allow fixtures contain no source comments", () => {
  for (const file of manifest.allow) {
    const source = fixture("allow", file)
    assert.equal(scanSource(file, source).length, 0, file)
  }
})

test("source-looking fixture paths are classified normally", () => {
  assert.equal(classifyFile("test/no-comments/fixtures/reject/comments.ts", fixture("reject", "comments.ts")), "clike")
  assert.equal(classifyFile("test/no-comments/fixtures/reject/comments.ts.txt", fixture("reject", "comments.ts")), null)
  assert.equal(classifyFile("runtime.cjs", ""), "clike")
})

test("template literals scan executable interpolations only", () => {
  assert.equal(scanSource("example.ts", fixture("reject", "template-expression.ts")).length, 2)
  assert.equal(scanSource("example.ts", fixture("allow", "template-text.ts")).length, 0)
})

test("self-closing script and style tags do not open embedded regions", () => {
  const source = fixture("reject", "self-closing-template.astro")
  const spans = scanSource("example.astro", source)
  assert.equal(spans.length, 2)
  const fixed = fixSource(source, spans)
  assert.match(fixed, /Visit https:\/\/frontman\.sh\/frontman for the workspace\./)
  assert.match(fixed, /src="https:\/\/frontman\.sh\/client\.js" \/>/)
  assert.match(fixed, /<script type="template">http:\/\/localhost:5173\/frontman<\/script>/)
  assert.equal(scanSource("example.astro", fixed).length, 0)
})

test("ReScript type variables do not hide later comments", () => {
  const source = "type value<'item> = option<'item>\n/* hidden */\n"
  assert.equal(scanSource("value.res", source).length, 1)
})

test("ReScript regular expressions are not line comments", () => {
  const source = "let value = path->String.replaceRegExp(/^\\.\\//, \"\")\n"
  assert.equal(scanSource("value.res", source).length, 0)
})

test("ReScript raw JavaScript bodies are scanned as executable source", () => {
  const source = `let value = %raw(\`function run() {
  const text = "// data"
  // line comment
  return text /* block comment */
}\`)
`
  assert.equal(scanSource("value.res", source).length, 2)
})

test("triple-slash documentation comments are preserved only on their own line", () => {
  const directive = '/// <reference types="vite/client" />\n'
  for (const file of ["env.ts", "env.tsx", "env.d.ts"]) {
    assert.equal(scanSource(file, directive).length, 0, file)
    assert.equal(fixSource(directive, scanSource(file, directive)), directive, file)
  }
  assert.equal(scanSource("env.js", directive).length, 0)
  assert.equal(scanSource("env.mts", directive).length, 0)
  assert.equal(scanSource("env.ts", "/// ordinary prose\n").length, 0)
  assert.equal(scanSource("env.ts", 'const value = 1 /// <reference types="vite/client" />\n').length, 1)
  assert.equal(scanSource("env.ts", '/// <reference unknown="vite/client" />\n').length, 0)
})

test("PHP documentation comments and WordPress plugin metadata are preserved", () => {
  const file = "libs/frontman-wordpress/frontman.php"
  const metadata = "<?php\n/**\n * Plugin Name: Frontman\n * Version: 2.0.0\n */\n"
  assert.equal(scanSource(file, metadata).length, 0)
  assert.equal(fixSource(metadata, scanSource(file, metadata)), metadata)
  assert.equal(scanSource("plugin.php", metadata).length, 0)
  assert.equal(scanSource(file, "<?php\n/** Ordinary leading docblock. */\n").length, 0)
  assert.equal(scanSource(file, "<?php\n/**\n * Plugin Name: Frontman\n */\n").length, 0)
  assert.equal(scanSource(file, `${metadata}/** Later docblock. */\n`).length, 0)
})

test("Elixir template sigils scan template and expression comments only", () => {
  assert.equal(scanSource("example.ex", fixture("reject", "template-sigil.ex")).length, 3)
  assert.equal(scanSource("example.ex", fixture("allow", "template-text.ex")).length, 0)
})

test("Elixir strings recursively scan interpolation expressions", () => {
  assert.equal(scanSource("example.ex", fixture("allow", "interpolation-text.ex")).length, 0)
  assert.equal(scanSource("example.ex", fixture("reject", "interpolation-comment.ex")).length, 1)
})

test("documentation comments are preserved", () => {
  const jsdoc = "/** Function docs. */\n/// Property docs.\nconst value = 1\n"
  const python = `"""Module docs."""
def run():
    """Function docs."""
    return 1
`
  const source = `defmodule Example do
  @moduledoc "Module docs"
  @typedoc """
  Type docs
  """
  @doc ~S"Function docs"
  @doc false
  def hidden, do: :ok
end
`
  for (const [file, documented] of [["example.ts", jsdoc], ["example.py", python], ["example.ex", source]]) {
    assert.equal(scanSource(file, documented).length, 0, file)
    assert.equal(fixSource(documented, scanSource(file, documented)), documented, file)
  }
})

test("leading legal notices are preserved without allowing later comments", () => {
  const elixir = `# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule Example do
  # implementation comment
end
`
  const javascript = `// Adapted work, Copyright (c) 2026 Example.
// Licensed under MIT; see THIRD_PARTY_LICENSES.md.

const value = 1 // implementation comment
`
  for (const [file, source] of [["example.ex", elixir], ["example.js", javascript]]) {
    const spans = scanSource(file, source)
    assert.equal(spans.length, 1, file)
    const fixed = fixSource(source, spans)
    assert.match(fixed, /Copyright/)
    assert.doesNotMatch(fixed, /implementation comment/)
  }
})

test("single-line legal notices do not exempt later comments", () => {
  const source = `# SPDX-License-Identifier: AGPL-3.0-only
value = 1 # implementation comment
`
  const spans = scanSource("example.ex", source)
  assert.equal(spans.length, 1)
  const fixed = fixSource(source, spans)
  assert.match(fixed, /^# SPDX-License-Identifier:/m)
  assert.doesNotMatch(fixed, /implementation comment/)
})

test("file-based HEEx expressions scan Elixir comments", () => {
  const source = `<div>
  <%= # hidden comment
  @value %>
</div>
`
  assert.equal(scanSource("template.html.heex", source).length, 1)
})

test("PHP heredoc and nowdoc bodies remain literal data", () => {
  const source = `<?php
$html = <<<HTML
https://example.com
/* literal block */
HTML;
$text = <<<'TEXT'
// literal line
TEXT;
$value = 1; // implementation comment
`
  const spans = scanSource("example.php", source)
  assert.equal(spans.length, 1)
  const fixed = fixSource(source, spans)
  assert.match(fixed, /https:\/\/example\.com/)
  assert.match(fixed, /\/\* literal block \*\//)
  assert.match(fixed, /\/\/ literal line/)
  assert.doesNotMatch(fixed, /implementation comment/)
})

test("ReScript format target excludes the vendored WebAPI subtree", () => {
  const makefile = readFileSync(join(here, "../../Makefile"), "utf8")
  assert.match(makefile, /rescript-format:[\s\S]*?:\(exclude\)libs\/experimental-rescript-webapi\/\*\*/)
})

test("installer generated-source bindings are scanned narrowly", () => {
  const nextFile = "libs/frontman-nextjs/src/cli/FrontmanNextjs__Cli__Templates.res"
  const viteFile = "libs/frontman-vite/src/cli/FrontmanVite__Cli__Templates.res"
  assert.equal(scanSource(nextFile, fixture("reject", "generated-nextjs.res")).length, 1)
  assert.equal(scanSource(viteFile, fixture("reject", "generated-vite.res")).length, 1)
  assert.equal(scanSource(nextFile, fixture("allow", "generated-nextjs.res")).length, 0)
  assert.equal(scanSource(viteFile, fixture("allow", "generated-vite.res")).length, 0)
  const nextSource = fixture("reject", "generated-nextjs.res")
  const fixed = fixSource(nextSource, scanSource(nextFile, nextSource))
  assert.equal(scanSource(nextFile, fixed).length, 0)
})

test("shell heredocs scan their embedded source language", () => {
  const source = `#!/usr/bin/env bash
cat > bridge.py <<'PYBRIDGE'
#!/usr/bin/env python3
value = "# data"
value = 1 # comment
PYBRIDGE
run_psql <<'SQL'
SELECT '-- data';
-- comment
SQL
cat > generated.sh <<'SCRIPT'
#!/usr/bin/env bash
value="# data"
# comment
SCRIPT
cat > generated.ts <<'TYPESCRIPT'
const url = "https://frontman.sh"
// comment
TYPESCRIPT
node <<'NODE'
const value = "// data"
// comment
NODE
`
  assert.equal(scanSource("setup.sh", source).length, 5)
  assert.equal(scanSource("setup.sh", fixSource(source, scanSource("setup.sh", source))).length, 0)
})

test("GitHub Actions run blocks scan their shell source", () => {
  const source = `name: Test
jobs:
  test:
    steps:
      - run: |
          value="# data"
          # shell comment
          node <<'NODE'
          // JavaScript comment
          NODE
`
  assert.equal(scanSource("workflow.yml", source).length, 2)
})

test("Astro expression comments are scanned", () => {
  const source = `<section>
  {/* expression comment */}
  <p>Content</p>
</section>
`
  assert.equal(scanSource("component.astro", source).length, 1)
})

test("Dockerfile parser directives are preserved", () => {
  const source = `# syntax=docker/dockerfile:1.7
# check=error=true
FROM alpine
# ordinary comment
RUN true
`
  const spans = scanSource("Dockerfile", source)
  assert.equal(spans.length, 1)
  const fixed = fixSource(source, spans)
  assert.match(fixed, /^# syntax=/m)
  assert.match(fixed, /^# check=/m)
  assert.doesNotMatch(fixed, /ordinary comment/)
})

test("Python files and shebang scripts distinguish comments and data", () => {
  const source = `#!/usr/bin/env python3
r"""Module docs."""
value = "# data"
def run():
    """Function docs."""
def execute():
    return 1 # comment
`
  assert.equal(classifyFile("example.py", source), "python")
  assert.equal(classifyFile("bin/example", source), "python")
  assert.equal(scanSource("example.py", source).length, 1)
  const fixed = fixSource(source, scanSource("example.py", source))
  assert.equal(scanSource("example.py", fixed).length, 0)
  assert.match(fixed, /^r"""Module docs\."""$/m)
  assert.match(fixed, /^    """Function docs\."""$/m)
})

test("fix removes comments and trailing whitespace", () => {
  for (const file of manifest.reject) {
    const source = fixture("reject", file)
    const fixed = fixSource(source, scanSource(file, source))
    assert.equal(scanSource(file, fixed).length, 0, file)
    assert.doesNotMatch(fixed, /[ \t]+$/m, file)
  }
})

test("fix preserves clean files and string whitespace outside comments", () => {
  const clean = "const value = `significant  \ntext`"
  assert.equal(fixSource(clean, scanSource("clean.ts", clean)), clean)
  const source = `${clean}\n// remove\n`
  assert.equal(fixSource(source, scanSource("source.ts", source)), `${clean}\n`)
})

test("SVG CDATA is data while embedded source remains scanned", () => {
  const source = `<svg xmlns="http://www.w3.org/2000/svg">
  <text><![CDATA[<!-- literal artwork text -->]]></text>
  <script>const value = "// data"; // comment</script>
</svg>
`
  assert.equal(scanSource("art.svg", source).length, 1)
})

test("scanner source contains no comments", () => {
  const source = readFileSync(scanner, "utf8")
  assert.equal(scanSource("scripts/no-comments.mjs", source).length, 0)
})

test("tracked file enumeration and CLI check and fix use git ls-files", () => {
  const root = mkdtempSync(join(tmpdir(), "frontman-no-comments-"))
  for (const file of manifest.reject) writeFileSync(join(root, file), fixture("reject", file))
  execFileSync("git", ["init", "-q"], {cwd: root})
  execFileSync("git", ["add", "."], {cwd: root})
  writeFileSync(join(root, "untracked.ts"), "// ignored\n")
  assert.ok(!trackedFiles(root).includes("untracked.ts"))
  const checked = spawnSync(process.execPath, [scanner, "--check"], {cwd: root, encoding: "utf8"})
  assert.equal(checked.status, 1)
  assert.match(checked.stderr, /comments\.ts:1:\d+: line comment/)
  const fixed = spawnSync(process.execPath, [scanner, "--fix"], {cwd: root, encoding: "utf8"})
  assert.equal(fixed.status, 0)
  assert.match(fixed.stdout, /Fixed \d+ comment\(s\) in \d+ file\(s\)\./)
  const clean = spawnSync(process.execPath, [scanner, "--check"], {cwd: root, encoding: "utf8"})
  assert.equal(clean.status, 0, clean.stderr)
  assert.equal(readFileSync(join(root, "untracked.ts"), "utf8"), "// ignored\n")
})

test("repository discovery excludes generated artifacts, vendored code, and scanner fixtures", () => {
  const root = mkdtempSync(join(tmpdir(), "frontman-no-comments-generated-"))
  const prelude = join(root, "libs/experimental-rescript-webapi/src/Prelude")
  const vendor = join(root, "apps/frontman_server/assets/vendor")
  const authored = join(root, "src")
  const scannerFixtures = join(root, "test/no-comments/fixtures/reject")
  mkdirSync(prelude, {recursive: true})
  mkdirSync(vendor, {recursive: true})
  mkdirSync(authored, {recursive: true})
  mkdirSync(scannerFixtures, {recursive: true})
  writeFileSync(join(prelude, "DOMException.js"), "// generated\n")
  writeFileSync(join(prelude, "DOMStringList.js"), "/* generated */\n")
  writeFileSync(join(vendor, "library.js"), "// upstream\n")
  writeFileSync(join(authored, "authored.js"), "// authored\nexport { }\n")
  writeFileSync(join(scannerFixtures, "Caddyfile.txt"), "# fixture\n")
  execFileSync("git", ["init", "-q"], {cwd: root})
  execFileSync("git", ["add", "."], {cwd: root})
  assert.deepEqual(repositoryFiles(root), ["src/authored.js"])
  const checked = spawnSync(process.execPath, [scanner, "--check"], {cwd: root, encoding: "utf8"})
  assert.equal(checked.status, 1)
  assert.match(checked.stderr, /authored\.js:1:\d+: line comment/)
  assert.doesNotMatch(checked.stderr, /DOMException\.js|DOMStringList\.js/)
  const fixed = spawnSync(process.execPath, [scanner, "--fix"], {cwd: root, encoding: "utf8"})
  assert.equal(fixed.status, 0, fixed.stderr)
  assert.equal(readFileSync(join(prelude, "DOMException.js"), "utf8"), "// generated\n")
  assert.equal(readFileSync(join(prelude, "DOMStringList.js"), "utf8"), "/* generated */\n")
  assert.equal(readFileSync(join(vendor, "library.js"), "utf8"), "// upstream\n")
  assert.equal(readFileSync(join(authored, "authored.js"), "utf8"), "export { }\n")
})
