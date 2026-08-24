import fs from "node:fs";
import path from "node:path";
import { featureSpecs, legacyPublicNamesForLeafModule } from "./feature-spec.mjs";

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function rewriteBareModuleReference(source, publicLeaf, leaf) {
  const pattern = new RegExp(`(^|[^A-Za-z0-9_])${escapeRegExp(publicLeaf)}\\.`, "g");
  return source.replace(pattern, (match, prefix, offset, input) => {
    const moduleStart = offset + prefix.length;

    if (prefix === "." && input.slice(Math.max(0, moduleStart - 3), moduleStart) !== "...") {
      return match;
    }

    return `${prefix}${leaf}.`;
  });
}

function rewriteNestedFeatureReferences(source, { specs, leavesByFeature }) {
  let next = source;

  for (const spec of specs) {
    const leaves = leavesByFeature.get(spec.publicModule) ?? [];

    for (const leaf of leaves) {
      for (const publicLeaf of legacyPublicNamesForLeafModule(leaf, spec)) {
        next = next.replaceAll(`${spec.legacyNamespace}.${publicLeaf}.`, `${leaf}.`);
        next = next.replaceAll(`WebAPI.${spec.publicModule}.${publicLeaf}.`, `${leaf}.`);
        next = next.replaceAll(`WebApi.${spec.publicModule}.${publicLeaf}.`, `${leaf}.`);
        next = next.replaceAll(`${spec.publicModule}.${publicLeaf}.`, `${leaf}.`);
      }
    }
  }

  return next;
}

export function rewriteSourceText(
  source,
  { currentFeature, specs, localLeaves, leavesByFeature = new Map([[currentFeature, localLeaves]]) },
) {
  const currentSpec = specs.find((spec) => spec.publicModule === currentFeature);
  let next = rewriteNestedFeatureReferences(source, { specs, leavesByFeature });

  for (const leaf of localLeaves) {
    for (const publicLeaf of legacyPublicNamesForLeafModule(leaf, currentSpec)) {
      next = next.replaceAll(`${currentSpec.legacyNamespace}.${publicLeaf}.`, `${leaf}.`);
      next = next.replaceAll(`WebAPI.${currentSpec.publicModule}.${publicLeaf}.`, `${leaf}.`);
      next = next.replaceAll(`WebApi.${currentSpec.publicModule}.${publicLeaf}.`, `${leaf}.`);
      next = next.replaceAll(`${currentSpec.publicModule}.${publicLeaf}.`, `${leaf}.`);

      if (leaf !== publicLeaf) {
        next = rewriteBareModuleReference(next, publicLeaf, leaf);
      }
    }
  }

  return next;
}

export function rewriteTestText(source, specs = featureSpecs, leavesByFeature = new Map()) {
  return rewriteNestedFeatureReferences(source, { specs, leavesByFeature });
}

function rewriteTestFilesInDirectory(directoryPath, leavesByFeature) {
  for (const entry of fs.readdirSync(directoryPath, { withFileTypes: true })) {
    const entryPath = path.join(directoryPath, entry.name);

    if (entry.isDirectory()) {
      rewriteTestFilesInDirectory(entryPath, leavesByFeature);
      continue;
    }

    if (!entry.isFile() || !entry.name.endsWith(".res")) continue;
    fs.writeFileSync(entryPath, rewriteTestText(fs.readFileSync(entryPath, "utf8"), featureSpecs, leavesByFeature));
  }
}

export function rewriteRepoReferences(rootDir) {
  const leavesByFeature = new Map();

  for (const spec of featureSpecs) {
    const featureDir = path.join(rootDir, "src", spec.dirName);
    if (!fs.existsSync(featureDir)) continue;

    const localLeaves = fs
      .readdirSync(featureDir)
      .filter((name) => name.endsWith(".res"))
      .map((name) => path.basename(name, ".res"));
    leavesByFeature.set(spec.publicModule, localLeaves);
  }

  for (const spec of featureSpecs) {
    const featureDir = path.join(rootDir, "src", spec.dirName);
    if (!fs.existsSync(featureDir)) continue;

    const localLeaves = leavesByFeature.get(spec.publicModule);

    for (const fileName of fs.readdirSync(featureDir)) {
      if (!fileName.endsWith(".res")) continue;

      const filePath = path.join(featureDir, fileName);
      const source = fs.readFileSync(filePath, "utf8");
      fs.writeFileSync(
        filePath,
        rewriteSourceText(source, {
          currentFeature: spec.publicModule,
          specs: featureSpecs,
          localLeaves,
          leavesByFeature,
        }),
      );
    }
  }

  const testsDir = path.join(rootDir, "tests");
  if (fs.existsSync(testsDir)) {
    rewriteTestFilesInDirectory(testsDir, leavesByFeature);
  }
}

if (process.argv.includes("--write")) {
  rewriteRepoReferences(process.cwd());
}
