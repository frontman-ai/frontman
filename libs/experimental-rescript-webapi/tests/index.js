import { execSync, spawnSync } from "child_process";
import { fileURLToPath, pathToFileURL } from "url";
import * as path from "path";
import { exit } from "process";

const currentFileName = fileURLToPath(import.meta.url);
const currentDir = path.dirname(currentFileName);
const repoRoot = path.resolve(currentDir, "..");
const testsDir = path.join(repoRoot, "tests");
const compiledSuffix = ".res.mjs";

const runtimeTests = [
  "FetchAPI/Headers__test.res",
  "FetchAPI/Request__test.res",
  "FetchAPI/Response__test.res",
  "FetchAPI/URLSearchParams__test.res",
  "URLAPI/URL__test.res",
];

const compiledRuntimeTests = runtimeTests.map((testFile) =>
  testFile.replace(/\.res$/, compiledSuffix),
);

// Compile all tests
execSync("npm run build", { cwd: repoRoot, stdio: "inherit" });

const successGreen = "\x1b[32m";
const errorRed = "\x1b[31m";
const resetColor = "\x1b[0m";

for (const testFile of compiledRuntimeTests) {
  const absoluteTestFile = path.join(testsDir, testFile);
  const result = spawnSync(
    process.execPath,
    [
      "--input-type=module",
      "--eval",
      `await import(${JSON.stringify(pathToFileURL(absoluteTestFile).href)})`,
    ],
    {
      cwd: repoRoot,
      encoding: "utf8",
    },
  );

  if (result.status !== 0) {
    console.log(`${errorRed}❌ Runtime test failed: ${testFile}${resetColor}`);
    if (result.stdout) {
      console.log(result.stdout);
    }
    if (result.stderr) {
      console.error(result.stderr);
    }
    exit(result.status ?? 1);
  }

  console.log(`${successGreen}✓ ${testFile}${resetColor}`);
}

console.log(`${successGreen}✅ Runtime tests passed!${resetColor}`);
