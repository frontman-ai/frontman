import { afterEach, expect, it, vi } from "vitest";
import { execute } from "../src/tools/Client__Tool__GetDom.res.mjs";
import { get } from "../src/tools/Client__Tool__PreviewContext.res.mjs";

vi.mock(
	"../src/tools/Client__Tool__PreviewContext.res.mjs",
	async (importOriginal) => ({
		...(await importOriginal()),
		get: vi.fn(),
	}),
);

const inspect = async (mode = "simplified", selector = "#page") =>
	(await execute({ selector, mode }, "task", "call")).structuredContent;

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
	delete window.__frontmanRuntime;
});

it.each(["simplified", "full"])(
	"reads fresh URL and routing after document replacement in %s mode",
	async (mode) => {
		window.__frontmanRuntime = { framework: "astro" };
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
	window.__frontmanRuntime = { framework: "astro" };
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

it.each(["nextjs", "vite", "wordpress"])(
	"omits Astro routing for %s",
	async (framework) => {
		window.__frontmanRuntime = { framework };
		showPage("/other", true);
		const result = await inspect();
		expect(result.url).toBe("https://preview.test/other");
		expect(result).not.toHaveProperty("astro_client_routing");
	},
);
