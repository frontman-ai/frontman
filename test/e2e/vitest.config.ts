import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    testTimeout: 180_000,
    hookTimeout: 120_000,

    retry: 1,

    pool: "forks",
    poolOptions: {
      forks: { singleFork: true },
    },
    fileParallelism: false,
    sequence: { concurrent: false },

    include: ["tests/**/*.test.ts"],

    globalSetup: ["./global-setup.ts"],
  },
});
