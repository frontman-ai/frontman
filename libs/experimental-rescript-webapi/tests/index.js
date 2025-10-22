import { execSync } from "child_process";
import { fileURLToPath } from "url";
import * as path from "path";
import { exit } from "process";

const currentFileName = fileURLToPath(import.meta.url);
const currentDir = path.dirname(currentFileName);
const repoRoot = path.resolve(currentDir, "..");
const testsDir = path.join(repoRoot, "tests");

// Compile all tests
execSync("npm run build", { cwd: repoRoot, stdio: "inherit" });

const successGreen = "\x1b[32m";
const warningYellow = "\x1b[33m";
const resetColor = "\x1b[0m";

// Assert nothing changed
const gitDff = execSync("git ls-files --modified .", {
  cwd: testsDir,
}).toString();
if (!gitDff) {
  console.log(`${successGreen}✅ No unstaged tests difference!${resetColor}`);
  exit(0);
} else {
  console.log(
    `${warningYellow}⚠️ There are unstaged differences in tests! Did you break a test?\n${gitDff}${resetColor}`,
  );
  execSync("git --no-pager diff .", { stdio: "inherit", cwd: testsDir });
  exit(1);
}
