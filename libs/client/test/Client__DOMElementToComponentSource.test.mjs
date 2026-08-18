import { act, createElement } from "react";
import { createRoot } from "react-dom/client";
import { afterEach, expect, it } from "vitest";

import { getElementSourceContext } from "../src/Client__DOMElementToComponentSource.res.mjs";

globalThis.IS_REACT_ACT_ENVIRONMENT = true;

afterEach(() => {
	document.body.replaceChildren();
});

it("returns component props instead of selected host element props", async () => {
	function Avatar({ name, picture }) {
		return createElement(
			"div",
			{ className: "avatar-name" },
			name,
			createElement("img", { src: picture }),
		);
	}

	const container = document.createElement("div");
	document.body.append(container);
	const root = createRoot(container);
	await act(() =>
		root.render(
			createElement(Avatar, { name: "JJ Kasper", picture: "/avatar.jpg" }),
		),
	);

	const context = await getElementSourceContext(
		container.querySelector(".avatar-name"),
	);

	expect(context?.definition?.componentName).toBe("Avatar");
	expect(context?.definition?.componentProps).toEqual({
		name: "JJ Kasper",
		picture: "/avatar.jpg",
	});
	expect(context?.invocations).toHaveLength(1);
	expect(context?.invocations[0].componentName).toBe("Avatar");
	await act(() => root.unmount());
});

it("returns no context for a non-React element", async () => {
	await expect(
		getElementSourceContext(document.createElement("div")),
	).resolves.toBeUndefined();
});
