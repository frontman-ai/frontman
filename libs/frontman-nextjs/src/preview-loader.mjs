import { installFrontmanPreviewLoader } from "@frontman-ai/frontman-preview-bridge/src/preview-loader.mjs";

if (typeof window !== "undefined" && window.name.startsWith("frontman:")) {
	const config = new URL(window.name.slice("frontman:".length));
	const basePath = config.searchParams.get("basePath") ?? "frontman";
	const path = basePath
		.split("/")
		.filter(Boolean)
		.map(encodeURIComponent)
		.join("/");
	installFrontmanPreviewLoader({ bridgeUrl: `/${path}/preview-bridge.js` });
}
