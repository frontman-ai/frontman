import path from "node:path"
import {defineConfig} from "vite"

export default defineConfig({
	build: {
		lib: {
			entry: path.resolve(import.meta.dirname, "src/Main.res.mjs"),
			formats: ["iife"],
			name: "FrontmanPreviewBridgeBundle",
			fileName: () => "bridge.js",
		},
		minify: "esbuild",
		sourcemap: false,
		emptyOutDir: true,
	},
})
