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
					port: Number.parseInt(process.env.VITE_HMR_PORT || "8443"),
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
			external: ["react", "react-dom", "react/jsx-runtime", /^node:.*/],
			output: {
				inlineDynamicImports: true,
			},
		},
	},
});
