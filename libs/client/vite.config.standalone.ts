/**
 * Vite config for standalone production build.
 *
 * Unlike the library build (vite.config.ts) which externalizes React,
 * this config bundles everything into a single self-contained ES module
 * that can be loaded directly via <script type="module"> in any page.
 *
 * Output: dist/frontman.es.js (+ dist/frontman.css if CSS is extracted)
 *
 * Used by: CI deploy workflow → Cloudflare Pages (app.frontman.sh)
 */
import path from "node:path";
import { transformAsync } from "@babel/core";
import tailwindcss from "@tailwindcss/vite";
import * as vite from "vite";

const ReactCompilerConfig = {};

function reactCompilerPlugin(): vite.Plugin {
	return {
		name: "react-compiler",
		enforce: "pre",
		apply: "build",
		async transform(code, id) {
			if (!id.endsWith(".res.mjs")) return;
			const result = await transformAsync(code, {
				plugins: [["babel-plugin-react-compiler", ReactCompilerConfig]],
				filename: id,
				sourceType: "module",
				sourceMaps: true,
			});
			if (!result?.code) return;
			return { code: result.code, map: result.map };
		},
	};
}

export default vite.defineConfig({
	plugins: [reactCompilerPlugin(), tailwindcss()],
	resolve: {
		alias: {
			"@": path.resolve(__dirname, "./src"),
		},
	},
	build: {
		// Standalone build: bundle everything including React
		lib: {
			entry: path.resolve(__dirname, "./src/Main.res.mjs"),
			formats: ["es"],
			fileName: () => "frontman.es.js",
		},
		rollupOptions: {
			// Only exclude Node.js builtins — React and all other deps are bundled
			external: [/^node:.*/],
			output: {
				inlineDynamicImports: true,
				// Extract CSS to a separate file for caching
				assetFileNames: (assetInfo) => {
					if (assetInfo.names?.[0]?.endsWith(".css")) {
						return "frontman.css";
					}
					return "assets/[name]-[hash][extname]";
				},
			},
		},
		// Enable minification for production
		minify: "esbuild",
		// No source maps — the .map file exceeds Cloudflare Pages' 25 MiB limit
		sourcemap: false,
	},
});
