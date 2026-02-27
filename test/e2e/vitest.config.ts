import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // E2E tests involve real LLM calls + dev servers — generous timeouts
    testTimeout: 180_000, // 3 minutes per test
    hookTimeout: 120_000, // 2 minutes for before/afterAll

    // Auto-retry each test once on failure.  LLM responses are
    // non-deterministic and CI runners can be slow, so a single
    // transient failure shouldn't block the whole pipeline.
    retry: 1,

    // Run test files sequentially — they share a single Phoenix server and
    // ChatGPT credentials, so parallel execution causes conflicts.
    pool: "forks",
    poolOptions: {
      forks: { singleFork: true },
    },
    sequence: { concurrent: false },

    // Only pick up files under tests/
    include: ["tests/**/*.test.ts"],

    // Global setup: start Phoenix server + client Vite dev server, seed DB
    globalSetup: ["./global-setup.ts"],
  },
});
