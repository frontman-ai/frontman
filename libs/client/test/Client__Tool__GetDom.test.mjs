import { afterEach, expect, it, vi } from "vitest";
import { forFramework } from "../src/Client__ToolRegistry.res.mjs";
import * as PreviewContext from "../src/tools/Client__Tool__PreviewContext.res.mjs";

const get = vi.spyOn(PreviewContext, "get");

const execute = (framework, input) =>
	forFramework(framework)
		.tools.find((tool) => tool.name === "get_dom")
		.execute(input, "task", "call");

const showPage = (enabled) => {
	const frame = document.createElement("iframe");
	document.body.replaceChildren(frame);
	const doc = frame.contentDocument;
	doc.head.innerHTML = enabled
		? '<meta name="astro-view-transitions-enabled">'
		: "";
	doc.body.innerHTML = '<main id="page"><span>Content</span></main>';
	get.mockReturnValue({
		doc,
		win: { location: { href: `https://preview.test/${enabled}` } },
	});
	get.mockClear();
	return doc;
};

afterEach(() => {
	document.body.replaceChildren();
	vi.resetAllMocks();
});

it.each(["simplified", "full"])(
	"reads fresh preview data in %s mode",
	async (mode) => {
		for (const enabled of [true, false]) {
			showPage(enabled);
			const response = await execute("Astro", { selector: "#page", mode });
			expect(response.isError).not.toBe(true);
			expect(response.structuredContent).toMatchObject({
				url: `https://preview.test/${enabled}`,
				html: expect.stringContaining("Content"),
				astro_client_routing: enabled ? "enabled" : "disabled",
			});
			expect(get).toHaveBeenCalledTimes(1);
		}
	},
);

it.each(["Astro", "Nextjs"])(
	"returns MCP errors with narrowing guidance for %s",
	async (framework) => {
		showPage(true).querySelector("span").textContent = "x".repeat(15001);
		for (const [selector, maxNodes, message] of [
			["#missing", undefined, "No element found"],
			["#page", 1, "Subtree too large"],
			["#page", undefined, "HTML too large"],
		]) {
			const response = await execute(framework, {
				selector,
				mode: "full",
				maxNodes,
			});
			expect(response.isError).toBe(true);
			expect(response.structuredContent).toBeUndefined();
			expect(response.content[0].text).toContain(message);
			if (selector === "#page")
				expect(response.content[0].text).toContain("Target a child selector");
		}
		get.mockReturnValue(undefined);
		const response = await execute(framework, { selector: "#page" });
		expect(response.isError).toBe(true);
		expect(response.structuredContent).toBeUndefined();
		expect(response.content[0].text).toBe("Preview frame not available");
	},
);
