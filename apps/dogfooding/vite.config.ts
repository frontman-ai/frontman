import * as vite from "vite";
import { frontmanPlugin } from "@frontman-ai/vite";

// Plugin to ensure client library imports are handled correctly
const fixReactImports = (): vite.Plugin => {
	return {
		name: "fix-react-imports",
		enforce: "pre",
		transform(code, id) {
			// Only transform the client library files
			if (id.includes("@frontman-ai/client") || id.includes("node_modules/@frontman-ai/client")) {
				// React 19 should export jsxs and Fragment from jsx-runtime, but if there are issues,
				// we can log them for debugging
				return code;
			}
			return null;
		},
	};
};

export default vite.defineConfig({
	server: {
		port: 6123,
	},
	optimizeDeps: {
		include: ["react", "react-dom", "react/jsx-runtime"],
		exclude: ["@frontman-ai/client"],
	},
	resolve: {
		dedupe: ["react", "react-dom"],
	},
	plugins: [
		fixReactImports(),
		frontmanPlugin({
			isDev: process.env.NODE_ENV !== "production",
			isLightTheme: true,
			entrypointUrl: "http://localhost:3000/frontman",
			//@ts-ignore
			clientUrl: "http://localhost:6123/bootstrap.js",
		}),
	]
});
