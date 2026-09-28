import fs from "node:fs";
import path from "node:path";
import { featureSpecs } from "./feature-spec.mjs";

export function isPublicModuleName(spec, moduleName) {
  if (moduleName.endsWith("Types")) return false;
  if (spec.dirName === "DOM" && moduleName === "DomGlobal") return false;

  return true;
}

export function publicModulesForSourceDir(sourceDir, spec) {
  if (!fs.existsSync(sourceDir)) return [];

  const publicModules = new Set();

  for (const entry of fs.readdirSync(sourceDir, { withFileTypes: true })) {
    if (!entry.isFile()) continue;

    const extension = path.extname(entry.name);
    if (extension !== ".res" && extension !== ".resi") continue;

    const moduleName = path.basename(entry.name, extension);
    if (!isPublicModuleName(spec, moduleName)) continue;

    publicModules.add(moduleName);
  }

  return [...publicModules].sort();
}

export function buildRootRescriptJson(specs) {
  return {
    name: "@rescript/webapi",
    sources: [
      ...specs.map((spec) => ({
        dir: `src/${spec.dirName}`,
        subdirs: true,
        feature: spec.featureName,
        public: (spec.publicModules ?? []).filter((moduleName) => isPublicModuleName(spec, moduleName)),
      })),
      {
        dir: "tests",
        subdirs: true,
        type: "dev",
      },
    ],
    "package-specs": {
      module: "esmodule",
      "in-source": true,
    },
    suffix: ".js",
    dependencies: [],
  };
}

export function buildRootPackageJson(currentPackage) {
  const nextPackage = structuredClone(currentPackage);
  nextPackage.name = "@rescript/webapi";

  delete nextPackage.private;
  delete nextPackage.workspaces;
  delete nextPackage.scripts["build:packages"];
  delete nextPackage.scripts["create:npm-packages"];

  nextPackage.files = ["rescript.json", "src/**/*.res", "src/**/*.resi", "README.md"];

  return nextPackage;
}

export function writeRootConfig(rootDir) {
  const packagePath = path.join(rootDir, "package.json");
  const rescriptPath = path.join(rootDir, "rescript.json");
  const currentPackage = JSON.parse(fs.readFileSync(packagePath, "utf8"));
  const specsWithPublicModules = featureSpecs.map((spec) => ({
    ...spec,
    publicModules: publicModulesForSourceDir(path.join(rootDir, spec.sourceDir), spec),
  }));

  fs.writeFileSync(rescriptPath, `${JSON.stringify(buildRootRescriptJson(specsWithPublicModules), null, 2)}\n`);
  fs.writeFileSync(packagePath, `${JSON.stringify(buildRootPackageJson(currentPackage), null, 2)}\n`);
  fs.rmSync(path.join(rootDir, "scripts", "create-npm-packages.js"), { force: true });
}

if (process.argv.includes("--write")) {
  writeRootConfig(process.cwd());
}
