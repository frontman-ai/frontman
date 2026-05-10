if (typeof process === "undefined") {
	window.process = { env: { NODE_ENV: "production" } };
}

(function () {
	var config = document.getElementById("frontman-runtime-config");

	window.__frontmanRuntime = {
		framework: config ? config.getAttribute("data-framework") || "wordpress" : "wordpress",
		basePath: config ? config.getAttribute("data-base-path") || "frontman" : "frontman",
		wpNonce: config ? config.getAttribute("data-wp-nonce") || "" : ""
	};
})();

(function () {
	var storageKey = "frontman-wordpress-warning-dismissed-v1";
	var overlay = document.getElementById("frontman-warning-overlay");
	var button = document.getElementById("frontman-warning-dismiss");

	if (!overlay || !button) {
		return;
	}

	try {
		if (window.localStorage && window.localStorage.getItem(storageKey) === "true") {
			return;
		}
	} catch (error) {}

	overlay.hidden = false;
	button.addEventListener("click", function () {
		try {
			if (window.localStorage) {
				window.localStorage.setItem(storageKey, "true");
			}
		} catch (error) {}

		overlay.hidden = true;
	});
})();
