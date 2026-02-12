import { defineConfig } from "vite";
import path from "path";

export default defineConfig({
	test: {
		environment: "jsdom",
		globals: true,
		include: ["libs/client/test/**/*.test.res.mjs", "libs/client/test/**/*.test.mjs"],

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
