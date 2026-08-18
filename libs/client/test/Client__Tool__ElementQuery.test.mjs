import { expect, it } from "vitest";
import {
	collectInteractiveElements,
	resolveByRoleAndName,
} from "../src/tools/Client__Tool__ElementQuery.res.mjs";

it("uses one interactive-element policy for listing and role targeting", () => {
	const region = document.createElement("div");
	region.setAttribute("role", "region");
	region.setAttribute("aria-label", "Panel");
	region.getBoundingClientRect = () => ({ width: 100, height: 40 });
	document.body.appendChild(region);

	expect(
		collectInteractiveElements(document, window, "region", "Panel", 10),
	).toEqual([]);
	expect(resolveByRoleAndName(document, window, "region", "Panel", 0)).toEqual([
		undefined,
		0,
	]);
});
