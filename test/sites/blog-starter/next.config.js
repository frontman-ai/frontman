/** @type {import('next').NextConfig} */
const nextConfig = {
	serverExternalPackages: ["dom-element-to-component-source", "source-map"],
	transpilePackages: ["@frontman-ai/nextjs"],
	turbopack: {
		root: require("path").resolve(__dirname, "../../.."),
	},
};

module.exports = nextConfig;
