import { defineConfig } from "vite";

export default defineConfig({
	test: {
		environment: "jsdom",
		globals: true,
		include: ["test/**/*.test.res.mjs", "test/**/*.test.mjs"],

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
