import { expect, it } from "vitest";
import {
	getVisibleText,
	queryInteractiveElements,
	resolveByRoleAndName,
} from "../src/tools/Client__Tool__ElementQuery.res.mjs";
import { resolveTarget } from "../src/tools/Client__Tool__InteractWithElement.res.mjs";

it("uses one interactive-element policy for listing and role targeting", () => {
	const region = document.createElement("div");
	region.setAttribute("role", "region");
	region.setAttribute("aria-label", "Panel");
	region.getBoundingClientRect = () => ({ width: 100, height: 40 });
	document.body.appendChild(region);

	expect(
		queryInteractiveElements(document, window, "region", "Panel", 10),
	).toEqual([]);
	expect(resolveByRoleAndName(document, window, "region", "Panel", 0)).toEqual([
		undefined,
		0,
	]);
});

it("reads text from non-HTML elements", () => {
	const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
	svg.textContent = "Diagram";

	expect(getVisibleText(svg)).toBe("Diagram");
});

it("matches roles case-insensitively", () => {
	const button = document.createElement("button");
	button.setAttribute("role", "BUTTON");
	button.setAttribute("aria-label", "Submit");
	button.getBoundingClientRect = () => ({ width: 100, height: 40 });
	document.body.appendChild(button);

	expect(
		queryInteractiveElements(document, window, "button", "Submit", 10),
	).toHaveLength(1);
});

it("rejects blank text interaction targets", () => {
	const result = resolveTarget(document, window, { text: "   " }, 0);

	expect(result.TAG).toBe("Error");
});
