import test from "node:test";
import assert from "node:assert/strict";
import {
  buildRootPackageJson,
  buildRootRescriptJson,
} from "../../scripts/unmonorepo/write-root-config.mjs";

test("builds the unified root rescript.json and package.json", () => {
  const specs = [
    { dirName: "Base", publicModule: "Base", featureName: "WebAPI.Base", publicModules: ["DOM"] },
    {
      dirName: "DOM",
      publicModule: "DOM",
      featureName: "WebAPI.DOM",
      publicModules: ["Document", "DomGlobal", "DomTypes", "Element"],
    },
  ];

  assert.deepEqual(buildRootRescriptJson(specs).sources, [
    { dir: "src/Base", subdirs: true, feature: "WebAPI.Base", public: ["DOM"] },
    { dir: "src/DOM", subdirs: true, feature: "WebAPI.DOM", public: ["Document", "Element"] },
    { dir: "tests", subdirs: true, type: "dev" },
  ]);

  const nextPackage = buildRootPackageJson({
    name: "experimental-rescript-webapi",
    version: "0.1.0",
    private: true,
    workspaces: ["packages/*"],
    scripts: {
      build: "rescript",
      "build:packages": "npm run build --workspaces --if-present",
      "create:npm-packages": "node scripts/create-npm-packages.js",
    },
  });

  assert.equal(nextPackage.name, "@rescript/webapi");
  assert.ok(!("private" in nextPackage));
  assert.ok(!("workspaces" in nextPackage));
  assert.ok(!("build:packages" in nextPackage.scripts));
  assert.ok(!("create:npm-packages" in nextPackage.scripts));
  assert.deepEqual(nextPackage.files, ["rescript.json", "src/**/*.res", "src/**/*.resi", "README.md"]);
});
