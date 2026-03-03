import { defineConfig } from "vitest/config";

export default defineConfig({
  define: {
    __PACKAGE_VERSION__: '"0.0.0-test"',
  },
  test: {
    include: ["test/**/*.test.res.mjs"],
    environment: "node",

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
