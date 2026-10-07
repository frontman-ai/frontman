import { beforeEach, expect, test, vi } from "vitest";
import { execFileSync } from "node:child_process";
import { installAstro, installNextjs, installVite, installVueVite } from "../e2e/helpers/installer";

const root = vi.hoisted(() => "/tmp/checkout with 'quotes'; $(touch injected)");
vi.mock("node:child_process", () => ({ execFileSync: vi.fn() }));
vi.mock("node:fs", () => ({
  existsSync: () => true,
  rmSync: vi.fn(),
  writeFileSync: vi.fn(),
}));
vi.mock("node:path", async (importOriginal) => {
  const actual = await importOriginal<typeof import("node:path")>();
  return {
    ...actual,
    resolve: (...parts: string[]) =>
      parts[1] === "../../.." ? root : actual.resolve(...parts),
  };
});

beforeEach(() => vi.mocked(execFileSync).mockReset());

test.each([
  [installNextjs, "nextjs", "frontman-nextjs"],
  [installVite, "vite", "frontman-vite"],
  [installVueVite, "vue-vite", "frontman-vite"],
] as const)("installer %s passes paths as literal arguments", (install, fixture, integration) => {
  install();
  expect(execFileSync).toHaveBeenNthCalledWith(1, "git",
    ["checkout", "--", `test/e2e/fixtures/${fixture}`], { cwd: root, stdio: "pipe" });
  expect(execFileSync).toHaveBeenNthCalledWith(2, "git",
    ["clean", "-fd", "--", `test/e2e/fixtures/${fixture}`], { cwd: root, stdio: "pipe" });
  expect(execFileSync).toHaveBeenNthCalledWith(3, process.execPath,
    [`${root}/libs/${integration}/dist/cli.js`, "install", "--skip-deps", "--server", "localhost:4002"],
    { cwd: `${root}/test/e2e/fixtures/${fixture}`, stdio: "inherit" });
  expect(execFileSync).toHaveBeenCalledTimes(3);
});

test("Astro uses the same shell-free fixture reset", () => {
  installAstro();
  expect(execFileSync).toHaveBeenCalledTimes(2);
  expect(execFileSync).toHaveBeenLastCalledWith("git",
    ["clean", "-fd", "--", "test/e2e/fixtures/astro"], { cwd: root, stdio: "pipe" });
});

test("child process failures propagate", () => {
  vi.mocked(execFileSync).mockImplementationOnce(() => { throw new Error("reset failed"); });
  expect(installNextjs).toThrow("reset failed");
  expect(execFileSync).toHaveBeenCalledTimes(1);
});
