import { join } from "node:path";
import { fileURLToPath } from "node:url";
import tailwindcss from "@tailwindcss/vite";
import { playwright } from "@vitest/browser-playwright";
import { build } from "vite";
import { defineConfig } from "vitest/config";

export default defineConfig(async () => {
	const root = fileURLToPath(new URL(".", import.meta.url));
	const outDir = join(root, "node_modules/.cache/draft-fixture");
	await build({
		configFile: false,
		root,
		define: {
			global: "globalThis",
			"process.env.NODE_ENV": JSON.stringify("development"),
		},
		build: {
			outDir,
			emptyOutDir: true,
			minify: false,
			lib: {
				entry: join(root, "test/browser/draftRuntime.js"),
				formats: ["iife"],
				name: "FrontmanDraftFixture",
				fileName: () => "draft-runtime.js",
			},
		},
	});

	return {
		plugins: [tailwindcss()],
		resolve: {
			alias: {
				"draft-fixture-runtime?url": `${join(outDir, "draft-runtime.js")}?url`,
			},
		},
		optimizeDeps: {
			exclude: ["draft-fixture-runtime?url"],
		},
		test: {
			include: ["test/browser/**/*.test.res.mjs"],
			browser: {
				enabled: true,
				headless: true,
				screenshotFailures: false,
				provider: playwright(),
				instances: [{ browser: "chromium" }],
			},
		},
	};
});
