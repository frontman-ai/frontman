import {defineConfig} from "vitest/config"

export default defineConfig({
	test: {
		environment: "jsdom",
		include: ["test/**/*.test.res.mjs", "test/**/*.test.ts"],
	},
})
