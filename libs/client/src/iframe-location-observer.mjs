export const observeWindowLocation = (targetWindow, onLocation) => {
	const targetDocument = targetWindow.document;
	const { history } = targetWindow;
	const originalPushState = history.pushState;
	const originalReplaceState = history.replaceState;
	let active = true;

	const reportLocation = () => {
		if (active) onLocation(targetWindow.location.href);
	};
	const pushState = function (...args) {
		const result = Reflect.apply(originalPushState, this, args);
		reportLocation();
		return result;
	};
	const replaceState = function (...args) {
		const result = Reflect.apply(originalReplaceState, this, args);
		reportLocation();
		return result;
	};

	history.pushState = pushState;
	history.replaceState = replaceState;
	targetWindow.addEventListener("popstate", reportLocation);
	targetWindow.addEventListener("hashchange", reportLocation);
	targetDocument.addEventListener("astro:page-load", reportLocation);

	return () => {
		active = false;
		targetWindow.removeEventListener("popstate", reportLocation);
		targetWindow.removeEventListener("hashchange", reportLocation);
		targetDocument.removeEventListener("astro:page-load", reportLocation);
		if (history.pushState === pushState) history.pushState = originalPushState;
		if (history.replaceState === replaceState)
			history.replaceState = originalReplaceState;
	};
};
