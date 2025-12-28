import path from "node:path";
import tailwindcss from "@tailwindcss/vite";
import * as vite from "vite";

export default vite.defineConfig({
	plugins: [tailwindcss()],
	resolve: {
		alias: {
			"@": path.resolve(__dirname, "./src"),
		},
	},
	build: {
		lib: {
			entry: path.resolve(__dirname, "./src/Main.res.mjs"),
			formats: ["es"],
			fileName: "index",
		},
		rollupOptions: {
			external: ["react", "react-dom", "react/jsx-runtime", /^node:.*/],
			output: {
				inlineDynamicImports: true,
			},
		},
	},
});
