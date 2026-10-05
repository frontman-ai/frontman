import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { playwright } from "@vitest/browser-playwright";
import { defineConfig } from "vitest/config";

const require = createRequire(import.meta.url);
const fixtureAsset = (pkg, file) =>
	`${join(dirname(require.resolve(`${pkg}/package.json`)), file)}?url`;

export default defineConfig({
	resolve: {
		alias: {
			"draft-fixture-react-umd?url": fixtureAsset(
				"react-draft-fixture",
				"umd/react.development.js",
			),
			"draft-fixture-react-dom-umd?url": fixtureAsset(
				"react-dom-draft-fixture",
				"umd/react-dom.development.js",
			),
			"draft-fixture-editor-umd?url": fixtureAsset("draft-js", "dist/Draft.js"),
			"draft-fixture-immutable-umd?url": fixtureAsset(
				"immutable",
				"dist/immutable.js",
			),
		},
	},
	optimizeDeps: {
		exclude: [
			"draft-fixture-react-umd?url",
			"draft-fixture-react-dom-umd?url",
			"draft-fixture-editor-umd?url",
			"draft-fixture-immutable-umd?url",
		],
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
});
