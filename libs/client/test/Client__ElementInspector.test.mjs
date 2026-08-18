import { beforeEach, expect, it, vi } from "vitest";

vi.mock("@medv/finder", () => ({
	finder: vi.fn(() => "#inspection-root"),
}));

import { finder } from "@medv/finder";
import { inspect, utf8ByteSize } from "../src/Client__ElementInspector.res.mjs";

beforeEach(() => {
	document.body.innerHTML = "";
	finder.mockReset();
	finder.mockReturnValue("#inspection-root");
});

it("describes bounded context with navigable child selectors", () => {
	document.body.innerHTML = `
		<main><div id="inspection-root">Root "text"<span>First</span><span>Second</span></div></main>
	`;
	const root = document.querySelector("#inspection-root");
	const result = inspect(root, document, 1, 20);

	expect(result.html).toContain('parent tag="main"');
	expect(result.html).toContain('selected tag="div" id="inspection-root"');
	expect(result.html).toContain('text="Root \\"text\\""');
	expect(result.html).toContain('selector="#inspection-root > :nth-child(1)"');
	expect(
		document.querySelector("#inspection-root > :nth-child(1)").textContent,
	).toBe("First");
	expect(finder).toHaveBeenCalledTimes(1);
	expect(inspect(root, document, 0, 20).html).not.toContain("child tag");
	expect(inspect(root, document, 2, 1)).toMatchObject({
		nodeCount: 1,
		truncated: true,
	});
});

it("caps simplified context at 30 KB of UTF-8", () => {
	const repeated = "é".repeat(100);
	document.body.innerHTML = `<div id="inspection-root">${`<div class="${repeated}">${repeated}</div>`.repeat(199)}</div>`;
	const result = inspect(
		document.querySelector("#inspection-root"),
		document,
		1,
		200,
	);

	expect(new TextEncoder().encode(result.html).byteLength).toBeLessThanOrEqual(
		30_000,
	);
	expect(result).toMatchObject({ truncated: true, byteTruncated: true });
	expect(utf8ByteSize("é")).toBe(2);
});

it("omits control values and URL secrets", () => {
	document.body.innerHTML = `
		<form id="inspection-root">
			<input type="password" value="password-secret">
			<input type="hidden" value="hidden-token">
			<textarea>textarea-secret</textarea>
			<a href="/account?token=url-secret#private">Account</a>
			<img src="/avatar?signature=image-secret" alt="Avatar">
			<a href="https://user:user-password@example.com/private">Private</a>
			<a href="//user:relative-password@example.com/private">Relative</a>
			<a href=" //user:spaced-password@example.com/private">Spaced</a>
			<img src="DATA:image/png;base64,image-data-secret" alt="Embedded">
		</form>
	`;
	const result = inspect(
		document.querySelector("#inspection-root"),
		document,
		1,
		200,
	);

	for (const secret of [
		"password-secret",
		"hidden-token",
		"textarea-secret",
		"url-secret",
		"image-secret",
		"user-password",
		"relative-password",
		"spaced-password",
		"image-data-secret",
	]) {
		expect(result.html).not.toContain(secret);
	}
	expect(result.nearbyText).toBeUndefined();
	expect(result.html).toContain('href="/account"');
	expect(result.html).toContain('src="/avatar"');
});

it("returns navigable selectors through open shadow roots", () => {
	const host = document.createElement("div");
	host.id = "shadow-host";
	document.body.appendChild(host);
	host.attachShadow({ mode: "open" }).innerHTML = `
		<section><span></span><span id="nested-decoy"></span></section>
		<button id="shadow-action">Save</button>
	`;

	const hostSelector = "#shadow-host";
	const result = inspect(host, document, 2, 20, true, hostSelector);
	expect(inspect(host, document, 1, 20).html).not.toContain("shadow-action");
	const nestedSelector = `${hostSelector} >>> 1/2`;
	const buttonSelector = `${hostSelector} >>> 2`;

	for (const selector of [nestedSelector, buttonSelector]) {
		expect(result.html).toContain(`selector=${JSON.stringify(selector)}`);
	}
});
