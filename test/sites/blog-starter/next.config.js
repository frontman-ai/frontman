const nextConfig = {
	transpilePackages: ["@frontman-ai/nextjs"],
	turbopack: {
		root: require("path").resolve(__dirname, "../../.."),
	},
};

module.exports = nextConfig;
