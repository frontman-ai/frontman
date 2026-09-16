export function installFrontmanPreviewLoader({ bridgeUrl } = {}) {
	if (window.parent === window || !window.name.startsWith("frontman:")) return;
	if (document.querySelector("script[data-frontman-bridge]")) return;

	const config = new URL(window.name.slice("frontman:".length));
	const channel = config.searchParams.get("channel");
	if (!channel || !["http:", "https:"].includes(config.protocol)) {
		throw new Error("Invalid Frontman preview frame configuration");
	}
	const script = document.createElement("script");
	script.src =
		bridgeUrl ?? new URL("bridge.js", document.currentScript.src).href;
	script.async = false;
	script.setAttribute("data-frontman-bridge", "true");
	script.setAttribute("data-frontman-parent-origin", config.origin);
	script.setAttribute("data-frontman-channel", channel);
	script.onerror = () =>
		console.error("Frontman preview bridge script failed to load", script.src);
	document.head.appendChild(script);
}

export function makeFrontmanPreviewLoaderBody(options) {
	const encodedOptions = JSON.stringify(options).replace(/</g, "\\u003c");
	return `(${installFrontmanPreviewLoader.toString()})(${encodedOptions});`;
}
