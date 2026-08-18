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

function sourceLocation(componentName, file, line, overrides = {}) {
	return {
		componentName,
		tagName: "component",
		file,
		line,
		column: 1,
		componentProps: undefined,
		...overrides,
	};
}

function contextLocation(location) {
	return {
		componentName: location.componentName,
		tagName: location.tagName,
		file: location.file,
		line: location.line,
		column: location.column,
		componentProps: location.componentProps,
	};
}

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

it("preserves Vue ancestry in nearest-to-farthest order", async () => {
	const nearest = sourceLocation("Panel", "src/Panel.vue", 4);
	const farthest = sourceLocation("App", "src/App.vue", 1, {
		parent: nearest,
	});
	const selected = sourceLocation("Counter", "src/Counter.vue", 8, {
		tagName: "button",
		componentProps: { initial: 1 },
		parent: farthest,
	});
	getVueSourceLocation.mockReturnValue(selected);

	await expect(
		getElementSourceLocation(document.createElement("button"), window),
	).resolves.toEqual({
		definition: contextLocation(selected),
		invocations: [contextLocation(nearest), contextLocation(farthest)],
	});
});

it("preserves Astro ancestry in nearest-to-farthest order", async () => {
	const nearest = sourceLocation("Page", "src/pages/index.astro", 5);
	const farthest = sourceLocation("Layout", "src/layouts/Layout.astro", 1, {
		parent: nearest,
	});
	const selected = sourceLocation("Card", "src/components/Card.astro", 12, {
		tagName: "article",
		column: 3,
		parent: farthest,
	});
	getAstroSourceLocation.mockReturnValue(selected);

	await expect(
		getElementSourceLocation(document.createElement("article"), window),
	).resolves.toEqual({
		definition: contextLocation(selected),
		invocations: [contextLocation(nearest), contextLocation(farthest)],
	});
});
