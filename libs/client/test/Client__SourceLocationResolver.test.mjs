import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { resolve } from "../src/Client__SourceLocationResolver.res.mjs";

beforeEach(() => {
	window.__frontmanRuntime = {
		framework: "nextjs",
		basePath: "frontman",
		relayBaseUrl: "http://localhost:3000",
	};
});

afterEach(() => {
	vi.unstubAllGlobals();
	delete window.__frontmanRuntime;
});

it("resolves every source location in the annotated component chain", async () => {
	const mappedFiles = new Map([
		["about://React/Server/file:///app/.next/avatar.js", "src/avatar.tsx"],
		[
			"about://React/Server/file:///app/.next/hero-post.js",
			"src/hero-post.tsx",
		],
		["about://React/Server/file:///app/.next/page.js", "src/page.tsx"],
	]);
	const fetch = vi.fn(async (_url, init) => {
		const request = JSON.parse(init.body);
		return new Response(
			JSON.stringify({
				componentName: request.componentName,
				file: mappedFiles.get(request.file),
				line: request.line,
				column: request.column,
			}),
			{ status: 200 },
		);
	});
	vi.stubGlobal("fetch", fetch);

	const sourceLocation = {
		componentName: "Avatar",
		tagName: "DIV",
		file: "about://React/Server/file:///app/.next/avatar.js",
		line: 10,
		column: 7,
		componentProps: { name: "JJ Kasper" },
		parent: {
			componentName: "HeroPost",
			tagName: "unknown",
			file: "about://React/Server/file:///app/.next/hero-post.js",
			line: 42,
			column: 11,
			componentProps: undefined,
			parent: {
				componentName: "Index",
				tagName: "unknown",
				file: "about://React/Server/file:///app/.next/page.js",
				line: 18,
				column: 5,
				componentProps: undefined,
				parent: undefined,
			},
		},
	};

	const result = await resolve(sourceLocation);

	expect(result.TAG).toBe("Ok");
	expect(result._0).toMatchObject({
		componentName: "Avatar",
		tagName: "DIV",
		file: "src/avatar.tsx",
		componentProps: { name: "JJ Kasper" },
		parent: {
			componentName: "HeroPost",
			file: "src/hero-post.tsx",
			parent: {
				componentName: "Index",
				file: "src/page.tsx",
			},
		},
	});
	expect(fetch).toHaveBeenCalledTimes(3);
});

it("rejects the chain when any React Server location cannot be resolved", async () => {
	const fetch = vi.fn(async (_url, init) => {
		const request = JSON.parse(init.body);
		return request.componentName === "HeroPost"
			? new Response(
					JSON.stringify({
						error: "Could not resolve React source location",
						details: "Resolved source remained virtual",
					}),
					{ status: 422, statusText: "Unprocessable Content" },
				)
			: new Response(JSON.stringify(request), { status: 200 });
	});
	vi.stubGlobal("fetch", fetch);

	const result = await resolve({
		componentName: "Avatar",
		tagName: "DIV",
		file: "about://React/Server/file:///app/.next/avatar.js",
		line: 10,
		column: 7,
		componentProps: undefined,
		parent: {
			componentName: "HeroPost",
			tagName: "unknown",
			file: "about://React/Server/file:///app/.next/hero-post.js",
			line: 42,
			column: 11,
			componentProps: undefined,
			parent: undefined,
		},
	});

	expect(result).toEqual({
		TAG: "Error",
		_0: "HTTP 422: Could not resolve React source location: Resolved source remained virtual",
	});
});
