import { defineConfig } from "vitest/config";

export default defineConfig({
  define: {
    __PACKAGE_VERSION__: '"0.0.0-test"',
  },
  test: {
    include: ["test/**/*.test.res.mjs"],
    environment: "node",
  },
});
