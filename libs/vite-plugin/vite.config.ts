import { defineConfig } from "vite";
import { resolve } from "path";
import dts from "vite-plugin-dts";

export default defineConfig({
	build: {
		ssr: true,
		lib: {
			entry: resolve(__dirname, "index.ts"),
			formats: ["es"],
			fileName: () => "index.js",
		},
		rollupOptions: {
			external: [
				"vite",
				"fs",
				"path",
				"os",
				"child_process",
				"crypto",
				"util",
				"stream",
				"events",
				"buffer",
				"url",
				"http",
				"https",
				"net",
				"tls",
				"zlib",
				"readline",
				"tty",
				"assert",
				"process",
				"module",
				"node:fs",
				"node:path",
				"node:os",
				"node:child_process",
				"node:crypto",
				"node:util",
				"node:stream",
				"node:events",
				"node:buffer",
				"node:url",
				"node:http",
				"node:https",
				"node:module",
			],
			output: {
				preserveModules: false,
				inlineDynamicImports: true,
			},
		},
		outDir: "dist",
		sourcemap: true,
		minify: false,
		target: "node18",
	},
	plugins: [
		dts({
			rollupTypes: true,
		}),
	],
	ssr: {
		noExternal: true,
	},
});
