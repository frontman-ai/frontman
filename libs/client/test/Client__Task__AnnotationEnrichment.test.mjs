/**
 * Integration tests for the FetchAnnotationDetails effect handler.
 *
 * Tests the async promise chain that enriches annotations with:
 *   - CSS selector (via @medv/finder)
 *   - Screenshot (via @zumer/snapdom)
 *   - Source location (via Client__SourceDetection)
 *
 * Uses vi.mock to stub external dependencies and captures dispatch calls
 * to verify the AnnotationDetailsResolved action payload.
 *
 * NOTE: Assertions reference ReScript's compiled variant representation
 * (TAG/Ok/Error/_0 fields). This couples tests to the compiler's output
 * format. If a compiler upgrade changes the encoding, these tests break —
 * but there's no typed alternative for testing the JS effect handler from
 * a plain .mjs test file. The reducer unit tests in Client__Task.test.res
 * cover the same logic with full type safety.
 */
import { beforeEach, describe, expect, it, vi } from "vitest";
import { inspect, utf8ByteSize } from "../src/Client__ElementInspector.res.mjs";
import { handleEffect } from "../src/state/Client__Task__Reducer.res.mjs";

vi.mock("@medv/finder", () => ({
	finder: vi.fn(() => "button.submit"),
}));

vi.mock("@zumer/snapdom", () => ({
	snapdom: vi.fn(() =>
		Promise.resolve({
			toJpg: () => Promise.resolve({ src: "data:image/jpeg;base64,abc123" }),
		}),
	),
}));

vi.mock("../src/Client__SourceDetection.res.mjs", () => ({
	getElementSourceLocation: vi.fn(() => Promise.resolve(undefined)),
}));

vi.mock("../src/Client__SourceLocationResolver.res.mjs", () => ({
	resolve: vi.fn((loc) => Promise.resolve({ TAG: "Ok", _0: loc })),
}));

vi.mock("../src/utils/Client__ImageLimits.res.mjs", () => ({
	conservative: { maxDimension: 7680, quality: 0.8 },
	computeScale: () => 1.0,
}));

import { finder } from "@medv/finder";
import { snapdom } from "@zumer/snapdom";
import { getElementSourceLocation } from "../src/Client__SourceDetection.res.mjs";
import { resolve as resolveSourceLocation } from "../src/Client__SourceLocationResolver.res.mjs";

function makeMockElement() {
	document.body.innerHTML = `
		<div id="form-actions">
			<button id="submit" class="btn-submit primary">
				Submit "now"
				<span class="button-overlay"></span>
			</button>
		</div>
	`;
	const element = document.querySelector("#submit");
	element.getBoundingClientRect = () => ({
		left: 10,
		top: 20,
		width: 100,
		height: 40,
	});
	return element;
}

function makeMockDocument() {
	return document;
}

/** Create the FetchAnnotationDetails effect object matching ReScript's compiled shape */
function makeEffect(overrides = {}) {
	return {
		TAG: "FetchAnnotationDetails",
		id: "ann-test-1",
		element: makeMockElement(),
		document: makeMockDocument(),
		contentWindow: undefined,
		...overrides,
	};
}

/**
 * Wait until the dispatch callback has been called at least once.
 * Uses vi.waitFor for deterministic async resolution instead of
 * a fragile fixed-count microtask loop.
 */
async function waitForDispatch(dispatched, { timeout = 1000 } = {}) {
	await vi.waitFor(
		() => {
			if (dispatched.length === 0) {
				throw new Error("dispatch not yet called");
			}
		},
		{ timeout },
	);
}

describe("FetchAnnotationDetails effect handler", () => {
	let dispatched;
	let dispatch;
	let delegate;

	beforeEach(() => {
		dispatched = [];
		dispatch = (action) => dispatched.push(action);
		delegate = () => {};
		vi.restoreAllMocks();

		finder.mockImplementation(() => "button.submit");
		snapdom.mockImplementation(() =>
			Promise.resolve({
				toJpg: () => Promise.resolve({ src: "data:image/jpeg;base64,abc123" }),
			}),
		);
		getElementSourceLocation.mockImplementation(() =>
			Promise.resolve(undefined),
		);
		resolveSourceLocation.mockImplementation((loc) =>
			Promise.resolve({ TAG: "Ok", _0: loc }),
		);
	});

	it("dispatches AnnotationDetailsResolved with Enriched when all promises succeed", async () => {
		handleEffect(makeEffect(), dispatch, delegate);
		await waitForDispatch(dispatched);

		expect(dispatched).toHaveLength(1);
		const action = dispatched[0];
		expect(action.TAG).toBe("AnnotationDetailsResolved");
		expect(action.enrichmentStatus).toBe("Enriched");
		expect(action.selector.TAG).toBe("Ok");
		expect(action.selector._0).toBe("button.submit");
		expect(action.screenshot.TAG).toBe("Ok");
		expect(action.screenshot._0).toBe("data:image/jpeg;base64,abc123");
		expect(action.elementContext.TAG).toBe("Ok");
		expect(action.elementContext._0).toContain(
			'parent tag="div" id="form-actions"',
		);
		expect(action.elementContext._0).toContain(
			'selected tag="button" id="submit"',
		);
		expect(action.elementContext._0).toContain('text="Submit \\"now\\""');
		expect(action.elementContext._0).toContain(
			'child tag="span" class="button-overlay"',
		);
		const capped = inspect(makeMockElement(), document, 2, 1);
		expect(capped).toMatchObject({ nodeCount: 1, truncated: true });
		expect(capped.html).toContain("truncated nodes=1");
		expect(inspect(makeMockElement(), document, 0, 20).html).not.toContain(
			"child tag",
		);
	});

	it("generates one selector and derives navigable child selectors", () => {
		document.body.innerHTML = `
			<div id="inspection-root">
				<span>First</span>
				<span>Second</span>
			</div>
		`;
		finder.mockImplementation(() => "#inspection-root");
		finder.mockClear();

		const result = inspect(
			document.querySelector("#inspection-root"),
			document,
			1,
			200,
		);

		expect(finder).toHaveBeenCalledTimes(1);
		expect(result.html).toContain(
			'selector="#inspection-root > :nth-child(1)"',
		);
		expect(
			document.querySelector("#inspection-root > :nth-child(1)").textContent,
		).toBe("First");
	});

	it("caps simplified context at 30 KB", () => {
		const repeated = "é".repeat(100);
		document.body.innerHTML = `<div id="large-context"></div>`;
		const root = document.querySelector("#large-context");
		for (let index = 0; index < 199; index += 1) {
			const child = document.createElement("div");
			for (const name of [
				"class",
				"data-testid",
				"href",
				"src",
				"type",
				"placeholder",
				"alt",
			]) {
				child.setAttribute(name, `${name}-${repeated}`);
			}
			child.textContent = repeated;
			root.appendChild(child);
		}
		finder.mockImplementation(() => "#large-context");

		const result = inspect(root, document, 1, 200);

		expect(
			new TextEncoder().encode(result.html).byteLength,
		).toBeLessThanOrEqual(30_000);
		expect(result.truncated).toBe(true);
		expect(result.byteTruncated).toBe(true);
		expect(utf8ByteSize("é")).toBe(2);
	});

	it("omits control values and URL credentials", () => {
		document.body.innerHTML = `
			<form id="credentials">
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
		finder.mockImplementation(() => "#credentials");

		const result = inspect(
			document.querySelector("#credentials"),
			document,
			1,
			200,
		);

		expect(result.html).not.toContain("password-secret");
		expect(result.html).not.toContain("hidden-token");
		expect(result.html).not.toContain("textarea-secret");
		expect(result.html).not.toContain("url-secret");
		expect(result.html).not.toContain("image-secret");
		expect(result.html).not.toContain("user-password");
		expect(result.html).not.toContain("relative-password");
		expect(result.html).not.toContain("spaced-password");
		expect(result.html).not.toContain("image-data-secret");
		expect(result.nearbyText).toBeUndefined();
		expect(result.html).toContain('href="/account"');
		expect(result.html).toContain('src="/avatar"');
	});

	it("dispatches Ok(None) sourceLocation when contentWindow is None", async () => {
		handleEffect(makeEffect({ contentWindow: undefined }), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.sourceLocation.TAG).toBe("Ok");
		expect(action.sourceLocation._0).toBeUndefined();
	});

	it("dispatches Ok(Some(loc)) sourceLocation when detection succeeds", async () => {
		const mockLoc = {
			componentName: "Button",
			tagName: "button",
			file: "src/Button.tsx",
			line: 42,
			column: 5,
			parent: undefined,
			componentProps: undefined,
		};
		getElementSourceLocation.mockImplementation(() => Promise.resolve(mockLoc));

		const mockWindow = {};
		handleEffect(makeEffect({ contentWindow: mockWindow }), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.sourceLocation.TAG).toBe("Ok");
		expect(action.sourceLocation._0).toBeDefined();
		expect(action.sourceLocation._0.file).toBe("src/Button.tsx");
		expect(action.sourceLocation._0.line).toBe(42);
	});

	it("selector Error when finder throws", async () => {
		finder.mockImplementation(() => {
			throw new Error("No unique selector found");
		});

		handleEffect(makeEffect(), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.TAG).toBe("AnnotationDetailsResolved");
		expect(action.enrichmentStatus).toBe("Enriched");
		expect(action.selector.TAG).toBe("Error");
		expect(action.selector._0).toBe("No unique selector found");
		expect(action.screenshot.TAG).toBe("Ok");
	});

	it("screenshot Error when snapdom rejects", async () => {
		snapdom.mockImplementation(() =>
			Promise.reject(new Error("Canvas tainted")),
		);

		handleEffect(makeEffect(), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.enrichmentStatus).toBe("Enriched");
		expect(action.screenshot.TAG).toBe("Error");
		expect(action.screenshot._0).toBe("Canvas tainted");
		expect(action.selector.TAG).toBe("Ok");
	});

	it("screenshot Error when toJpg rejects", async () => {
		snapdom.mockImplementation(() =>
			Promise.resolve({
				toJpg: () => Promise.reject(new Error("JPEG conversion failed")),
			}),
		);

		handleEffect(makeEffect(), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.enrichmentStatus).toBe("Enriched");
		expect(action.screenshot.TAG).toBe("Error");
		expect(action.screenshot._0).toBe("JPEG conversion failed");
	});

	it("sourceLocation Error when detection throws", async () => {
		getElementSourceLocation.mockImplementation(() =>
			Promise.reject(new Error("CORS blocked source map")),
		);

		const mockWindow = {};
		handleEffect(makeEffect({ contentWindow: mockWindow }), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.enrichmentStatus).toBe("Enriched");
		expect(action.sourceLocation.TAG).toBe("Error");
		expect(action.sourceLocation._0).toBe("CORS blocked source map");
	});

	it("dispatches Failed status when source location resolver throws synchronously", async () => {
		const mockLoc = {
			componentName: "App",
			tagName: "div",
			file: "src/App.tsx",
			line: 1,
			column: 1,
			parent: undefined,
			componentProps: undefined,
		};
		getElementSourceLocation.mockImplementation(() => Promise.resolve(mockLoc));
		resolveSourceLocation.mockImplementation(() => {
			throw new Error("Resolver exploded");
		});

		const mockWindow = {};
		handleEffect(makeEffect({ contentWindow: mockWindow }), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.TAG).toBe("AnnotationDetailsResolved");
		expect(action.enrichmentStatus.TAG).toBe("Failed");
		expect(action.enrichmentStatus.error).toBe("Resolver exploded");
		expect(action.selector.TAG).toBe("Error");
		expect(action.screenshot.TAG).toBe("Error");
		expect(action.sourceLocation.TAG).toBe("Error");
	});
});
