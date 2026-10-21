import {playwright} from "@vitest/browser-playwright"
import {defineConfig} from "vitest/config"

export default defineConfig({
	server: {host: "127.0.0.1"},
	test: {
		projects: [
			{test: {
				name: "unit",
				environment: "node",
				include: ["test/**/*.test.res.mjs", "test/**/*.test.ts"],
				exclude: ["test/FrontmanPreviewBridge__Browser.test.res.mjs"],
			}},
			{extends: true, test: {
				name: "browser",
				include: ["test/FrontmanPreviewBridge__Browser.test.res.mjs"],
				browser: {
					enabled: true,
					headless: true,
					screenshotFailures: false,
					provider: playwright(),
					instances: [{browser: "chromium"}],
				},
			}},
		],
	},
})
