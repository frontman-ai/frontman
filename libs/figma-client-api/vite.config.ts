import { defineConfig } from "vite";
import dts from "vite-plugin-dts";
import { resolve } from "path";

export default defineConfig({
  build: {
    lib: {
      entry: resolve(__dirname, "src/index.ts"),
      name: "FigmaClientApi",
      fileName: "index",
      formats: ["es"],
    },
    rollupOptions: {
      external: [],
    },
    sourcemap: true,
  },
  plugins: [
    dts({
      include: ["src/**/*.ts"],
      outDir: "dist",
    }),
  ],
});


