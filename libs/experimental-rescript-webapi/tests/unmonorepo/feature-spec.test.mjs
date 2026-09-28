import test from "node:test";
import assert from "node:assert/strict";
import {
  featureSpecs,
  migratedLeafName,
  publicModuleToInternalPrefix,
  publicNameForLeafModule,
} from "../../scripts/unmonorepo/feature-spec.mjs";

test("defines all legacy feature mappings used by the unmonorepo migration", () => {
  assert.deepEqual(
    featureSpecs
      .filter(({ dirName }) => dirName === "Base" || dirName === "DOM")
      .map(({ dirName, legacyNamespace, publicModule, featureName, internalPrefix }) => ({
        dirName,
        legacyNamespace,
        publicModule,
        featureName,
        internalPrefix,
      })),
    [
      {
        dirName: "Base",
        legacyNamespace: "WebApiBase",
        publicModule: "Base",
        featureName: "WebAPI.Base",
        internalPrefix: "Base",
      },
      {
        dirName: "DOM",
        legacyNamespace: "WebApiDOM",
        publicModule: "DOM",
        featureName: "WebAPI.DOM",
        internalPrefix: "Dom",
      },
    ],
  );

  assert.equal(featureSpecs.length, 44);
});

test("normalizes internal prefixes and public duplicate names", () => {
  assert.equal(publicModuleToInternalPrefix("DOM"), "Dom");
  assert.equal(publicModuleToInternalPrefix("URL"), "Url");
  assert.equal(publicNameForLeafModule("DomTypes", "Dom"), "Types");
  assert.equal(publicNameForLeafModule("Document", "Dom"), "Document");
  assert.equal(publicNameForLeafModule("DOM", "Base"), "DOM");
  assert.equal(publicNameForLeafModule("PushEvent", "Push"), "PushEvent");
  assert.equal(publicNameForLeafModule("Storage", "WebStorage"), "Storage");
});

test("preserves direct public leaf modules while renaming duplicated internals", () => {
  const duplicateLeaves = new Set(["Types", "Global", "File", "Event"]);

  assert.equal(
    migratedLeafName({
      spec: { dirName: "Base", publicModule: "Base", internalPrefix: "Base" },
      leafName: "DOM",
      duplicateLeaves,
    }),
    "DOM",
  );
  assert.equal(
    migratedLeafName({
      spec: { dirName: "File", publicModule: "File", internalPrefix: "File" },
      leafName: "File",
      duplicateLeaves,
    }),
    "File",
  );
  assert.equal(
    migratedLeafName({
      spec: { dirName: "File", publicModule: "File", internalPrefix: "File" },
      leafName: "Types",
      duplicateLeaves,
    }),
    "FileTypes",
  );
  assert.equal(
    migratedLeafName({
      spec: { dirName: "Fetch", publicModule: "Fetch", internalPrefix: "Fetch" },
      leafName: "Global",
      duplicateLeaves,
    }),
    "Fetch",
  );
  assert.equal(
    migratedLeafName({
      spec: { dirName: "Canvas", publicModule: "Canvas", internalPrefix: "Canvas" },
      leafName: "Global",
      duplicateLeaves,
    }),
    "Canvas",
  );
  assert.equal(
    migratedLeafName({
      spec: { dirName: "WebWorkers", publicModule: "WebWorkers", internalPrefix: "WebWorkers" },
      leafName: "WorkerGlobalScope",
      duplicateLeaves,
    }),
    "Worker",
  );
  assert.equal(
    migratedLeafName({
      spec: { dirName: "WebWorkers", publicModule: "WebWorkers", internalPrefix: "WebWorkers" },
      leafName: "SharedWorkerGlobalScope",
      duplicateLeaves,
    }),
    "SharedWorkerScope",
  );
  assert.equal(
    migratedLeafName({
      spec: { dirName: "ServiceWorker", publicModule: "ServiceWorker", internalPrefix: "ServiceWorker" },
      leafName: "ServiceWorkerGlobalScope",
      duplicateLeaves,
    }),
    "ServiceWorkerScope",
  );
});
