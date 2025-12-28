import path from "node:path";
import type { Indexer, StorybookConfig } from "@storybook/react-vite";
import tailwindcss from "@tailwindcss/vite";
import { mergeConfig } from "vite";

// Known story export names that follow CSF conventions (camelCase/PascalCase story names)
const isLikelyStoryExport = (name: string): boolean => {
	// Filter out: underscore-prefixed, $$default, module aliases like 'Message'
	if (name.startsWith("_") || name.startsWith("$$") || name.includes(" as ")) {
		return false;
	}
	// Story names should be camelCase starting with lowercase
	// or specific known patterns
	return /^[a-z][a-zA-Z0-9]*$/.test(name);
};

// Custom indexer for ReScript compiled story files (.res.mjs)
// ReScript compiles `let default = meta` to `export { $$default as default }`
// which needs special handling for CSF parsing
const rescriptIndexer: Indexer = {
	test: /\.story\.res\.mjs$/,
	createIndex: async (fileName, options) => {
		const fs = await import("node:fs/promises");
		let code = await fs.readFile(fileName, "utf-8");

		// Step 1: Inline variable references in the default object
		// ReScript generates: let default_tags = ["autodocs"]; let $$default = { tags: default_tags, ... }
		// CSF needs: export default { tags: ["autodocs"], ... }
		const varPattern = /let (default_\w+) = (\[[^\]]*\]|{[^}]*}|[^;]+);/g;
		const vars: Record<string, string> = {};
		let match: RegExpExecArray | null = varPattern.exec(code);
		while (match !== null) {
			vars[match[1]] = match[2];
			match = varPattern.exec(code);
		}

		// Replace variable references in $$default object
		for (const [varName, varValue] of Object.entries(vars)) {
			// Only inline array literals for tags
			if (varName === "default_tags" && varValue.startsWith("[")) {
				code = code.replace(
					new RegExp(`tags:\\s*${varName}`, "g"),
					`tags: ${varValue}`,
				);
			}
		}

		// Step 2: Transform the export format
		// ReScript generates: export { Message, _fn, $$default as default, primary, ... }
		// CSF needs: export default { ... }; export { primary, ... }
		code = code.replace(/export\s*\{([\s\S]*?)\}/, (match, exportContent) => {
			if (!exportContent.includes("$$default as default")) {
				return match;
			}

			// Parse exports and filter to only story-like exports
			const exports = exportContent
				.split(",")
				.map((s: string) => s.trim())
				.filter((s: string) => s.length > 0);

			// Separate default export from named exports
			const namedExports = exports
				.filter((s: string) => !s.includes("$$default as default"))
				.filter((s: string) => isLikelyStoryExport(s));

			if (namedExports.length > 0) {
				return `export default $$default;\nexport {\n  ${namedExports.join(",\n  ")}\n}`;
			} else {
				return `export default $$default;`;
			}
		});

		const { loadCsf } = await import("@storybook/csf-tools");
		const csf = loadCsf(code, {
			fileName,
			makeTitle: options.makeTitle,
		}).parse();
		return csf.indexInputs;
	},
};

const config: StorybookConfig = {
	stories: ["../src/**/*.story.res.mjs"],
	addons: [
		"@storybook/addon-links",
		"@storybook/addon-essentials",
		"@storybook/addon-interactions",
	],
	framework: {
		name: "@storybook/react-vite",
		options: {},
	},
	docs: {},
	experimental_indexers: async (existingIndexers) => [
		rescriptIndexer,
		...(existingIndexers || []),
	],
	viteFinal: async (config) => {
		return mergeConfig(config, {
			plugins: [tailwindcss()],
			resolve: {
				alias: {
					"@": path.resolve(__dirname, "../src"),
				},
			},
		});
	},
};

export default config;
