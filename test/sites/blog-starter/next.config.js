/** @type {import('next').NextConfig} */
const nextConfig = {
	turbopack: {
		root: require("path").resolve(__dirname, "../../.."),
	},
};

module.exports = nextConfig;
