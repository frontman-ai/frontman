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
	server: {
		// Listen on all interfaces for container access
		host: "0.0.0.0",
		port: 5173,
		// Allow worktree hostnames (wt-*.local) for DevPod development
		allowedHosts: [".local"],
		// Enable CORS for cross-origin requests from Next.js
		cors: true,
		// HMR configuration for remote development via Caddy proxy
		hmr: process.env.VITE_HMR_HOST
			? {
					host: process.env.VITE_HMR_HOST,
					port: Number.parseInt(process.env.VITE_HMR_PORT || "443", 10),
					protocol: (process.env.VITE_HMR_PROTOCOL as "ws" | "wss") || "wss",
				}
			: true,
	},
	build: {
		lib: {
			entry: path.resolve(__dirname, "./src/Main.res.mjs"),
			formats: ["es"],
			fileName: "index",
		},
		rollupOptions: {
			external: [
				"react",
				"react-dom",
				"react/jsx-runtime",
				"react/compiler-runtime",
				/^node:.*/,
			],
			output: {
				inlineDynamicImports: true,
			},
		},
	},
});
