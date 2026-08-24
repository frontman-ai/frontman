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

it("resolves a complete context in one request and builds the persistence chain", async () => {
	const fetch = vi.fn(
		async () =>
			new Response(
				JSON.stringify({
					definition: {
						componentName: "Avatar",
						tagName: "DIV",
						file: "src/avatar.tsx",
						line: 10,
						column: 7,
						componentProps: { name: "JJ Kasper" },
					},
					invocations: [
						{
							componentName: "HeroPost",
							tagName: "DIV",
							file: "src/hero-post.tsx",
							line: 42,
							column: 11,
						},
						{
							componentName: "Index",
							tagName: "DIV",
							file: "src/page.tsx",
							line: 18,
							column: 5,
						},
					],
				}),
				{ status: 200 },
			),
	);
	vi.stubGlobal("fetch", fetch);

	const context = {
		definition: {
			componentName: "Avatar",
			tagName: "DIV",
			file: "src/avatar.tsx",
			line: 10,
			column: 7,
			componentProps: { name: "JJ Kasper" },
		},
		invocations: [
			{
				componentName: "HeroPost",
				tagName: "DIV",
				file: "about://React/Server/file:///app/.next/hero-post.js",
				line: 42,
				column: 11,
			},
			{
				componentName: "Index",
				tagName: "DIV",
				file: "about://React/Server/file:///app/.next/page.js",
				line: 18,
				column: 5,
			},
		],
	};

	const result = await resolve(context);

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
	expect(fetch).toHaveBeenCalledOnce();
	expect(JSON.parse(fetch.mock.calls[0][1].body)).toEqual(context);
});

it("uses the first invocation as head when definition is absent", async () => {
	const context = {
		definition: undefined,
		invocations: [
			{
				componentName: "HeroPost",
				tagName: "ARTICLE",
				file: "src/hero-post.tsx",
				line: 42,
				column: 11,
			},
			{
				componentName: "Index",
				tagName: "ARTICLE",
				file: "src/page.tsx",
				line: 18,
				column: 5,
			},
		],
	};
	vi.stubGlobal(
		"fetch",
		vi.fn(async () => new Response(JSON.stringify(context), { status: 200 })),
	);

	const result = await resolve(context);

	expect(result.TAG).toBe("Ok");
	expect(result._0).toMatchObject({
		componentName: "HeroPost",
		parent: { componentName: "Index" },
	});
});

it("rejects the context when any React Server location cannot be resolved", async () => {
	vi.stubGlobal(
		"fetch",
		vi.fn(
			async () =>
				new Response(
					JSON.stringify({
						error: "Could not resolve React source context",
						details: "Resolved source remained virtual",
					}),
					{ status: 422, statusText: "Unprocessable Content" },
				),
		),
	);

	const result = await resolve({
		definition: undefined,
		invocations: [
			{
				componentName: "HeroPost",
				tagName: "ARTICLE",
				file: "about://React/Server/file:///app/.next/hero-post.js",
				line: 42,
				column: 11,
			},
		],
	});

	expect(result).toEqual({
		TAG: "Error",
		_0: "HTTP 422: Could not resolve React source context: Resolved source remained virtual",
	});
});
