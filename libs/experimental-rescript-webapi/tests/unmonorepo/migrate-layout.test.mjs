import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { migrateLayout } from "../../scripts/unmonorepo/migrate-layout.mjs";

function writePackage(root, dir, namespace, files) {
  const packageDir = path.join(root, "packages", dir);
  mkdirSync(path.join(packageDir, "src"), { recursive: true });
  writeFileSync(path.join(packageDir, "rescript.json"), JSON.stringify({ namespace }));
  writeFileSync(path.join(packageDir, "package.json"), JSON.stringify({ name: dir }));

  for (const [name, contents] of Object.entries(files)) {
    writeFileSync(path.join(packageDir, "src", name), contents);
  }
}

test("moves legacy sources into src/<Feature>, renames duplicate leaves, and removes workspace metadata", () => {
  const root = mkdtempSync(path.join(tmpdir(), "webapi-layout-"));

  writePackage(root, "DOM", "WebApiDOM", {
    "Document.res": "let current = WebApiDOM.Global.document",
    "Types.res": "type element",
    "Global.res": "let document = 1",
  });

  writePackage(root, "Base", "WebApiBase", {
    "DOM.res": "type dom = unit",
  });

  writePackage(root, "Fetch", "WebApiFetch", {
    "Global.res": "let fetch = 1",
    "Types.res": "type request",
    "Headers.res": "type t",
  });

  writePackage(root, "Canvas", "WebApiCanvas", {
    "Global.res": "let createImageBitmap = 1",
  });

  writePackage(root, "WebWorkers", "WebApiWebWorkers", {
    "WorkerGlobalScope.res": "type worker",
    "SharedWorkerGlobalScope.res": "type sharedWorker",
  });

  writePackage(root, "ServiceWorker", "WebApiServiceWorker", {
    "ServiceWorkerGlobalScope.res": "type serviceWorker",
  });

  writePackage(root, "URL", "WebApiURL", {
    "URL.res": "external make: unit => unit = \"URL\"",
    "URLSearchParams.res": "type t",
  });

  mkdirSync(path.join(root, "packages", "Prelude", "lib"), { recursive: true });

  migrateLayout(root);

  assert.equal(
    readFileSync(path.join(root, "src", "DOM", "Document.res"), "utf8"),
    "let current = WebApiDOM.Global.document",
  );
  assert.equal(readFileSync(path.join(root, "src", "DOM", "DomTypes.res"), "utf8"), "type element");
  assert.equal(
    readFileSync(path.join(root, "src", "DOM", "DomGlobal.res"), "utf8"),
    "let document = 1",
  );
  assert.equal(
    readFileSync(path.join(root, "src", "Fetch", "Fetch.res"), "utf8"),
    "let fetch = 1",
  );
  assert.equal(
    readFileSync(path.join(root, "src", "Canvas", "Canvas.res"), "utf8"),
    "let createImageBitmap = 1",
  );
  assert.equal(
    readFileSync(path.join(root, "src", "WebWorkers", "Worker.res"), "utf8"),
    "type worker",
  );
  assert.equal(
    readFileSync(path.join(root, "src", "WebWorkers", "SharedWorkerScope.res"), "utf8"),
    "type sharedWorker",
  );
  assert.equal(
    readFileSync(path.join(root, "src", "ServiceWorker", "ServiceWorkerScope.res"), "utf8"),
    "type serviceWorker",
  );
  assert.equal(
    readFileSync(path.join(root, "src", "Fetch", "FetchTypes.res"), "utf8"),
    "type request",
  );
  assert.equal(
    readFileSync(path.join(root, "src", "URL", "URL.res"), "utf8"),
    "external make: unit => unit = \"URL\"",
  );
  assert.equal(readFileSync(path.join(root, "src", "URL", "URLSearchParams.res"), "utf8"), "type t");
  assert.ok(!existsSync(path.join(root, "src", "DOM", "DOM.res")));
  assert.ok(!existsSync(path.join(root, "src", "Base", "Base.res")));
  assert.equal(readFileSync(path.join(root, "src", "Base", "DOM.res"), "utf8"), "type dom = unit");
  assert.ok(!existsSync(path.join(root, "packages", "DOM", "rescript.json")));
  assert.ok(!existsSync(path.join(root, "packages", "DOM", "package.json")));
  assert.ok(!existsSync(path.join(root, "packages", "DOM")));
  assert.ok(!existsSync(path.join(root, "packages", "Prelude")));
});
