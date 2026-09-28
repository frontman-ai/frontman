import { beforeEach, expect, it, vi } from "vitest";

vi.mock("../src/Client__DOMElementToComponentSource.res.mjs", () => ({
	getElementSourceContext: vi.fn(),
}));

vi.mock("../src/Client__Vue__SourceDetection.res.mjs", () => ({
	getElementSourceLocation: vi.fn(),
}));

import { getElementSourceContext } from "../src/Client__DOMElementToComponentSource.res.mjs";
import { getElementSourceLocation } from "../src/Client__SourceDetection.res.mjs";
import { getElementSourceLocation as getVueSourceLocation } from "../src/Client__Vue__SourceDetection.res.mjs";

beforeEach(() => {
	vi.resetAllMocks();
	getElementSourceContext.mockResolvedValue(undefined);
	getVueSourceLocation.mockReturnValue(undefined);
	delete window.__frontman_annotations__;
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

it.each([
	[
		"direct annotation without DOM ancestry",
		"src/components/Card.astro",
		"12:3",
		true,
	],
	["nearest project annotation", "src/components/Card.astro", "12:3", false],
	[
		"nearest dependency annotation",
		"/project/node_modules/design-system/Card.astro",
		"8:2",
		false,
	],
])("uses Astro %s", async (_name, file, loc, direct) => {
	const component = document.createElement("section");
	const selected = document.createElement(direct ? "article" : "span");
	component.append(selected);
	const annotated = direct ? selected : component;
	const annotations = new Map([
		[annotated, { file, loc, displayName: "Card" }],
	]);
	if (direct) {
		annotations.set(component, {
			file: "src/pages/index.astro",
			loc: "5:1",
			displayName: "Page",
		});
	}
	window.__frontman_annotations__ = {
		get: (element) => annotations.get(element),
		getContentFile: () => undefined,
	};
	const [line, column] = loc.split(":").map(Number);

	await expect(getElementSourceLocation(selected, window)).resolves.toEqual({
		definition: {
			componentName: "Card",
			tagName: direct ? "article" : "section",
			file,
			line,
			column,
			componentProps: undefined,
		},
		invocations: [],
	});
});
