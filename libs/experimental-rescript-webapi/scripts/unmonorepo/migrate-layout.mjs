import fs from "node:fs";
import path from "node:path";
import { featureSpecs, findDuplicateLeafModules, migratedLeafName } from "./feature-spec.mjs";

function moveFile(fromPath, toPath) {
  fs.mkdirSync(path.dirname(toPath), { recursive: true });
  fs.renameSync(fromPath, toPath);
}

export function migrateLayout(rootDir) {
  const duplicateLeaves = findDuplicateLeafModules(rootDir, featureSpecs);

  for (const spec of featureSpecs) {
    const legacySourceDir = path.join(rootDir, "packages", spec.dirName, "src");
    if (!fs.existsSync(legacySourceDir)) continue;

    const nextSourceDir = path.join(rootDir, "src", spec.dirName);
    fs.mkdirSync(nextSourceDir, { recursive: true });

    for (const entry of fs.readdirSync(legacySourceDir, { withFileTypes: true })) {
      if (!entry.isFile() || !entry.name.endsWith(".res")) continue;

      const leafName = path.basename(entry.name, ".res");
      const nextLeafName = migratedLeafName({ spec, leafName, duplicateLeaves });

      moveFile(
        path.join(legacySourceDir, entry.name),
        path.join(nextSourceDir, `${nextLeafName}.res`),
      );
    }

    for (const removable of ["package.json", "rescript.json", "lib"]) {
      fs.rmSync(path.join(rootDir, "packages", spec.dirName, removable), {
        recursive: true,
        force: true,
      });
    }

    fs.rmSync(path.join(rootDir, "packages", spec.dirName), {
      recursive: true,
      force: true,
    });
  }

  fs.rmSync(path.join(rootDir, "packages", "Prelude"), { recursive: true, force: true });
}

if (process.argv.includes("--write")) {
  migrateLayout(process.cwd());
}
