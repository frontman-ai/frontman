import { afterEach, expect, it, vi } from "vitest";
import { forFramework } from "../src/Client__ToolRegistry.res.mjs";
import { get } from "../src/tools/Client__Tool__PreviewContext.res.mjs";

vi.mock(
	"../src/tools/Client__Tool__PreviewContext.res.mjs",
	async (importOriginal) => ({
		...(await importOriginal()),
		get: vi.fn(),
	}),
);

const getDom = (framework) => {
	const tools = forFramework(framework).tools.filter(
		(tool) => tool.name === "get_dom",
	);
	expect(tools).toHaveLength(1);
	return tools[0];
};

const inspect = async (
	mode = "simplified",
	selector = "#page",
	framework = "Astro",
) =>
	(await getDom(framework).execute({ selector, mode }, "task", "call"))
		.structuredContent;

const showPage = (path, enabled) => {
	const frame = document.createElement("iframe");
	document.body.replaceChildren(frame);
	const doc = frame.contentDocument;
	doc.body.innerHTML = '<main id="page">Page content</main>';
	if (enabled) {
		doc.head.innerHTML =
			'<meta name="astro-view-transitions-enabled" content="true">';
	}
	get.mockReturnValue({
		doc,
		win: { location: { href: `https://preview.test${path}` } },
	});
	return doc;
};

afterEach(() => {
	document.body.replaceChildren();
	vi.resetAllMocks();
});

it.each(["simplified", "full"])(
	"reads fresh URL and routing after document replacement in %s mode",
	async (mode) => {
		showPage("/first", true);
		const first = await inspect(mode);
		expect(first.error).toBeUndefined();
		expect(first).toMatchObject({
			success: true,
			url: "https://preview.test/first",
			astro_client_routing: "enabled",
		});

		const doc = showPage("/second", false);
		expect(await inspect(mode)).toMatchObject({
			success: true,
			url: "https://preview.test/second",
			astro_client_routing: "disabled",
		});

		doc.head.innerHTML = '<meta name="astro-view-transitions-enabled">';
		expect((await inspect(mode)).astro_client_routing).toBe("enabled");
	},
);

it("includes routing context on query failures and distinguishes unavailable from disabled", async () => {
	showPage("/current", true);
	expect(await inspect("full", "#missing")).toMatchObject({
		success: false,
		url: "https://preview.test/current",
		astro_client_routing: "enabled",
	});

	get.mockReturnValue(undefined);
	const result = await inspect();
	expect(result).toMatchObject({
		success: false,
		astro_client_routing: "unavailable",
	});
	expect(result.url).toBeUndefined();
});

it.each(["Nextjs", "Vite", "Wordpress"])(
	"keeps %s results, schema, and description framework-neutral",
	async (framework) => {
		const tool = getDom(framework);
		expect(tool.description).not.toMatch(/astro/i);
		expect(tool.outputJsonSchema.properties).toHaveProperty("url");
		expect(tool.outputJsonSchema.properties).not.toHaveProperty(
			"astro_client_routing",
		);
		for (const mode of ["simplified", "full"]) {
			showPage("/other", true);
			const result = await inspect(mode, "#page", framework);
			expect(result.success).toBe(true);
			expect(result.url).toBe("https://preview.test/other");
			expect(result).not.toHaveProperty("astro_client_routing");
		}
		get.mockReturnValue(undefined);
		const unavailable = await inspect("full", "#page", framework);
		expect(unavailable.success).toBe(false);
		expect(unavailable).not.toHaveProperty("astro_client_routing");
	},
);

it("advertises routing only on the Astro wrapper and reads one preview per call", async () => {
	const tool = getDom("Astro");
	expect(tool.description).toContain("Astro");
	expect(tool.outputJsonSchema.properties).toHaveProperty(
		"astro_client_routing",
	);
	showPage("/current", true);
	await inspect();
	expect(get).toHaveBeenCalledTimes(1);
});
