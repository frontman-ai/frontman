import { expect, test } from "vitest";
import { readFileSync } from "node:fs";
import { parse } from "yaml";
import { gte } from "semver";

test("patched dependencies do not regain vulnerable locked copies", () => {
  const lock = parse(readFileSync("yarn.lock", "utf8")) as Record<string, { version: string }>;
  const floors: Record<string, string> = {
    next: "16.3.6", sharp: "0.35.5", svgo: "4.1.0", browserslist: "4.28.7",
    qs: "6.16.0", vitest: "4.1.11", "@vitest/mocker": "4.1.11",
    "@vitest/browser": "4.1.11", "@vitest/browser-playwright": "4.1.11",
    "@vitest/coverage-v8": "4.1.11",
  };
  for (const [name, floor] of Object.entries(floors)) {
    const copies = Object.entries(lock).filter(([key]) => key.startsWith(name + "@npm:"));
    expect(copies.length, name).toBeGreaterThan(0);
    for (const [key, copy] of copies) expect(gte(copy.version, floor), key).toBe(true);
  }
  for (const [key, copy] of Object.entries(lock)) {
    if (key.startsWith("js-yaml@npm:") && copy.version.startsWith("4.")) {
      expect(gte(copy.version, "4.3.2"), key).toBe(true);
    }
  }
});
