import { createElement } from "react";
import { createRoot } from "react-dom/client";
import { make as Preview } from "../../../libs/client/src/webpreview/Client__WebPreview__Body.res.mjs";
import * as Runtime from "../../../libs/client/src/webpreview/Client__PreviewRuntime.res.mjs";
import * as Registry from "../../../libs/client/src/webpreview/Client__PreviewRuntimeRegistry.res.mjs";

export { Runtime, Registry };
const root = createRoot(
	document.body.appendChild(document.createElement("div")),
);
export function mount(url: string, isActive = true) {
	root.render(
		createElement(Preview, { taskId: "browser-test", url, isActive }),
	);
}
export async function context() {
	const runtime = Registry.get("browser-test");
	await Runtime.whenOpen(runtime);
	return Runtime.getPageContext(runtime);
}
