import path from "node:path"
import {defineConfig} from "vite"

export default defineConfig(({mode}) => {
	const parentFixture = mode === "test-parent"
	return {
		build: {
			outDir: parentFixture ? "test/dist" : "dist",
			lib: {
				entry: path.resolve(
					import.meta.dirname,
					parentFixture ? "test/FrontmanPreviewBridge__ParentFixture.res.mjs" : "src/Main.res.mjs",
				),
				formats: ["iife"],
				name: parentFixture ? "FrontmanPreviewParent" : "FrontmanPreviewBridgeBundle",
				fileName: () => parentFixture ? "parent.js" : "bridge.js",
			},
			license: parentFixture ? false : {fileName: "bridge-licenses.txt"},
			minify: "esbuild",
			sourcemap: false,
			emptyOutDir: true,
		},
	}
})
