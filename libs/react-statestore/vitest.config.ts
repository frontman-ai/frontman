import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",

    testTimeout: 10000,

    include: ["test/**/*_test.res.mjs"],

    silent: false,

    setupFiles: ["./test/setup.ts"],

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
