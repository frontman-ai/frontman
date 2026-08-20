import { defineConfig } from "vitest/config";

export default defineConfig({
	test: {
		testTimeout: 120_000,
		hookTimeout: 150_000,
		pool: "forks",
		maxWorkers: 1,
		fileParallelism: false,
		sequence: { concurrent: false },
		include: [
			"tests/mcp-blackbox.test.ts",
			"tests/wordpress-playground-blackbox.test.ts",
		],
	},
});
