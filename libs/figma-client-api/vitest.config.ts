import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/**/*.test.ts"],
    environment: "node",

    // Coverage configuration
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary", "cobertura"],
      include: ["src/**/*.ts"],
      exclude: [
        "**/*.test.*",
        "**/*.d.ts",
      ],
    },
  },
});


