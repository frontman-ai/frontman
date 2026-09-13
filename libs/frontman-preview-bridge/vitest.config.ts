import {defineConfig} from "vitest/config"

export default defineConfig({
	test: {
		projects: [
			{test: {
				name: "browser",
				environment: "jsdom",
				include: ["test/**/*.test.res.mjs", "test/bundle.test.ts"],
			}},
			{test: {
				name: "loader",
				environment: "node",
				include: ["test/preview-loader.test.ts"],
			}},
		],
	},
})
