import { defineConfig } from "vitest/config";
import { resolve } from "node:path";

export default defineConfig({
  resolve: { alias: { "@": resolve(import.meta.dirname, "../sites/blog-starter/src") } },
  oxc: { jsx: { runtime: "automatic" } },
  test: {
    include: ["test/security/*.test.ts"],
    fileParallelism: false,
    testTimeout: 30_000,
  },
});
