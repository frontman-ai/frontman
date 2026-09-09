import { executeLocalTool } from "@frontman-ai/frontman-client/src/FrontmanClient__MCP__Server.res.mjs";
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

const callTool = async (framework, input) => {
	const response = await executeLocalTool(
		getDom(framework),
		input,
		"task",
		"call",
	);
	expect(response.TAG).toBe("Completed");
	return response._0;
};

const inspect = async (mode = "simplified", framework = "Astro") => {
	const response = await callTool(framework, { selector: "#page", mode });
	expect(response.isError).not.toBe(true);
	expect(response.structuredContent).not.toHaveProperty("success");
	expect(response.structuredContent).not.toHaveProperty("error");
	return response.structuredContent;
};

const expectToolError = (response, message) => {
	expect(response.isError).toBe(true);
	expect(response).not.toHaveProperty("structuredContent");
	expect(response.content[0].text).toContain(message);
};

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
		expect(await inspect(mode)).toMatchObject({
			url: "https://preview.test/first",
			astro_client_routing: "enabled",
		});

		const doc = showPage("/second", false);
		expect(await inspect(mode)).toMatchObject({
			url: "https://preview.test/second",
			astro_client_routing: "disabled",
		});

		doc.head.innerHTML = '<meta name="astro-view-transitions-enabled">';
		expect((await inspect(mode)).astro_client_routing).toBe("enabled");
	},
);

it.each(["Astro", "Nextjs", "Vite", "Wordpress"])(
	"uses MCP errors for %s failures and retains size-limit guidance",
	async (framework) => {
		get.mockReturnValue(undefined);
		expectToolError(
			await callTool(framework, { selector: "#page" }),
			"Preview frame not available",
		);

		const doc = showPage("/current", true);
		expectToolError(
			await callTool(framework, { selector: "#missing" }),
			"No element found",
		);
		expectToolError(await callTool(framework, {}), "Invalid input");
		const invalidSelector = await callTool(framework, { selector: "[" });
		expect(invalidSelector.isError).toBe(true);
		expect(invalidSelector).not.toHaveProperty("structuredContent");

		doc.querySelector("#page").innerHTML = '<span id="child">Child</span>';
		const tooManyNodes = await callTool(framework, {
			selector: "#page",
			mode: "full",
			maxNodes: 1,
		});
		expectToolError(tooManyNodes, "Subtree too large for full mode");
		expect(tooManyNodes.content[0].text).toContain("Target a child selector");

		doc.querySelector("#page").textContent = "x".repeat(15001);
		const tooManyBytes = await callTool(framework, {
			selector: "#page",
			mode: "full",
		});
		expectToolError(tooManyBytes, "HTML too large");
		expect(tooManyBytes.content[0].text).toContain("Target a child selector");
	},
);

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
			const result = await inspect(mode, framework);
			expect(result.url).toBe("https://preview.test/other");
			expect(result).not.toHaveProperty("astro_client_routing");
		}
	},
);

it("advertises required success data without a parallel error schema and reads one preview per call", async () => {
	for (const framework of ["Astro", "Nextjs", "Vite", "Wordpress"]) {
		const schema = getDom(framework).outputJsonSchema;
		expect(schema.properties).not.toHaveProperty("success");
		expect(schema.properties).not.toHaveProperty("error");
		expect(schema.required).toEqual(
			expect.arrayContaining(["url", "html", "nodeCount", "byteSize"]),
		);
	}
	const tool = getDom("Astro");
	expect(tool.description).toContain("Astro");
	expect(tool.outputJsonSchema.properties).toHaveProperty(
		"astro_client_routing",
	);
	showPage("/current", true);
	await inspect();
	expect(get).toHaveBeenCalledTimes(1);
});
