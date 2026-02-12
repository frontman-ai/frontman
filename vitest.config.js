import { defineConfig } from "vite";
import path from "path";

export default defineConfig({
	test: {
		root: path.resolve(__dirname, "libs/client"),
		include: ["test/**/*.test.res.mjs", "test/**/*.test.mjs"],
		environment: "jsdom",
		setupFiles: ["setup-tests.ts"],
	},
});
