import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Use jsdom for React component/hooks testing
    environment: "jsdom",

    // Standard timeout for tests
    testTimeout: 10000,

    // Pattern for compiled ReScript test files
    include: ["test/**/*.test.res.mjs"],

    // Allow console output from tests
    silent: false,

    // Setup file for React Testing Library
    setupFiles: ["./test/setup.ts"],

    // Coverage configuration
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary", "cobertura"],
      include: ["src/**/*.res.mjs"],
      exclude: [
        "**/*.test.*",
        "**/*.story.*",
        "src/**/*.res.d.ts",
        "src/Bindings__*.res.mjs",
      ],
    },
  },
});
