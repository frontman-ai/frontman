import { beforeEach, expect, it, vi } from "vitest";

vi.mock("../src/Client__DOMElementToComponentSource.res.mjs", () => ({
	getElementSourceContext: vi.fn(),
}));

vi.mock("../src/Client__Vue__SourceDetection.res.mjs", () => ({
	getElementSourceLocation: vi.fn(),
}));

vi.mock("../src/Client__AstroSourceDetection.res.mjs", () => ({
	getElementSourceLocation: vi.fn(),
}));

import { getElementSourceLocation as getAstroSourceLocation } from "../src/Client__AstroSourceDetection.res.mjs";
import { getElementSourceContext } from "../src/Client__DOMElementToComponentSource.res.mjs";
import { getElementSourceLocation } from "../src/Client__SourceDetection.res.mjs";
import { getElementSourceLocation as getVueSourceLocation } from "../src/Client__Vue__SourceDetection.res.mjs";

beforeEach(() => {
	vi.resetAllMocks();
	getElementSourceContext.mockResolvedValue(undefined);
	getVueSourceLocation.mockReturnValue(undefined);
	getAstroSourceLocation.mockReturnValue(undefined);
});

it("returns the React source context unchanged", async () => {
	const context = {
		definition: undefined,
		invocations: [
			{
				componentName: "Page",
				tagName: "DIV",
				file: "src/page.tsx",
				line: 4,
				column: 2,
			},
		],
	};
	getElementSourceContext.mockResolvedValue(context);

	await expect(
		getElementSourceLocation(document.createElement("div"), window),
	).resolves.toEqual(context);
	expect(getVueSourceLocation).not.toHaveBeenCalled();
	expect(getAstroSourceLocation).not.toHaveBeenCalled();
});

it("wraps a Vue location as definition with no invocations", async () => {
	getVueSourceLocation.mockReturnValue({
		componentName: "Counter",
		tagName: "button",
		file: "src/Counter.vue",
		line: 8,
		column: 1,
		parent: undefined,
		componentProps: { initial: 1 },
	});

	await expect(
		getElementSourceLocation(document.createElement("button"), window),
	).resolves.toEqual({
		definition: {
			componentName: "Counter",
			tagName: "button",
			file: "src/Counter.vue",
			line: 8,
			column: 1,
			componentProps: { initial: 1 },
		},
		invocations: [],
	});
});

it("wraps an Astro location as definition with no invocations", async () => {
	getAstroSourceLocation.mockReturnValue({
		componentName: "Card",
		tagName: "article",
		file: "src/components/Card.astro",
		line: 12,
		column: 3,
		parent: undefined,
		componentProps: undefined,
	});

	await expect(
		getElementSourceLocation(document.createElement("article"), window),
	).resolves.toEqual({
		definition: {
			componentName: "Card",
			tagName: "article",
			file: "src/components/Card.astro",
			line: 12,
			column: 3,
			componentProps: undefined,
		},
		invocations: [],
	});
});
