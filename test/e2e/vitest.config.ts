import { defineConfig } from "vitest/config";

export default defineConfig({
	test: {
		testTimeout: 180_000,
		hookTimeout: 120_000,

		retry: 1,

		pool: "forks",
		maxWorkers: 1,
		fileParallelism: false,
		sequence: { concurrent: false },

		projects: [
			{
				extends: true,
				test: {
					name: "browser",
					include: ["browser/**/*.test.ts"],
					testTimeout: 30_000,
				},
			},
			{
				extends: true,
				test: {
					name: "integration",
					include: ["tests/**/*.test.ts"],
					globalSetup: ["./global-setup.ts"],
				},
			},
		],
	},
});
