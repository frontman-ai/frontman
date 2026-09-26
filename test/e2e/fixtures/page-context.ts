import { createElement } from "react";
import { createRoot } from "react-dom/client";
import { make as Preview } from "../../../libs/client/src/webpreview/Client__WebPreview__Body.res.mjs";
import * as Runtime from "../../../libs/client/src/webpreview/Client__PreviewRuntime.res.mjs";
import { store } from "../../../libs/client/src/state/Client__State__Store.res.mjs";
import { Selectors } from "../../../libs/client/src/state/Client__State__StateReducer.res.mjs";
import { getState } from "../../../libs/react-statestore/src/StateStore.res.mjs";

export { Runtime };
export const runtime = () => Selectors.previewFrame(getState(store)).runtime;
const root = createRoot(
	document.body.appendChild(document.createElement("div")),
);
export function mount(url: string, isActive = true) {
	root.render(
		createElement(Preview, {
			taskId: Selectors.currentTaskClientId(getState(store)),
			url,
			isActive,
		}),
	);
}
export async function context() {
	return Runtime.getPageContext(runtime());
}
