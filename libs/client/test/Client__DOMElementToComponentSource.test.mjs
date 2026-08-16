import { beforeEach, expect, it, vi } from "vitest";

vi.mock("dom-element-to-component-source", () => ({
	getElementSourceContext: vi.fn(),
}));

import { getElementSourceContext as getSourceContext } from "dom-element-to-component-source";
import { getElementSourceContext } from "../src/Client__DOMElementToComponentSource.res.mjs";

beforeEach(() => {
	getSourceContext.mockReset();
});

it("returns the package definition and nearest-to-farthest invocations", async () => {
	const element = document.createElement("div");
	const context = {
		definition: {
			componentName: "Avatar",
			tagName: "DIV",
			file: "src/app/_components/avatar.tsx",
			line: 10,
			column: 7,
			componentProps: { name: "JJ Kasper" },
		},
		invocations: [
			{
				componentName: "HeroPost",
				tagName: "DIV",
				file: "about://React/Server/file:///app/.next/server/hero-post.js",
				line: 42,
				column: 11,
			},
			{
				componentName: "Index",
				tagName: "DIV",
				file: "about://React/Server/file:///app/.next/server/page.js",
				line: 18,
				column: 5,
			},
		],
	};
	getSourceContext.mockResolvedValue({ success: true, data: context });

	await expect(getElementSourceContext(element)).resolves.toEqual(context);
	expect(getSourceContext).toHaveBeenCalledOnce();
	expect(getSourceContext).toHaveBeenCalledWith(element);
});

it("returns an invocation-only context", async () => {
	const element = document.createElement("article");
	const context = {
		definition: undefined,
		invocations: [
			{
				componentName: "Post",
				tagName: "ARTICLE",
				file: "about://React/Server/file:///app/.next/server/chunk.js",
				line: 42,
				column: 7,
			},
		],
	};
	getSourceContext.mockResolvedValue({ success: true, data: context });

	await expect(getElementSourceContext(element)).resolves.toEqual(context);
});

it("returns no context when package detection fails", async () => {
	const element = document.createElement("div");
	getSourceContext.mockResolvedValue({
		success: false,
		error: "No React Fiber node found on element",
	});

	await expect(getElementSourceContext(element)).resolves.toBeUndefined();
});
