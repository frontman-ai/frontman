/** Integration tests for FetchAnnotationDetails effect orchestration. */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
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

function makeEffect(overrides = {}) {
	return {
		TAG: "FetchAnnotationDetails",
		id: "ann-test-1",
		element: makeMockElement(),
		document,
		contentWindow: undefined,
		...overrides,
	};
}

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

	afterEach(() => {
		vi.useRealTimers();
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
		expect(action.elementContext._0).toContain('selected tag="button"');
	});

	it("dispatches Ok(None) sourceLocation when contentWindow is None", async () => {
		handleEffect(makeEffect({ contentWindow: undefined }), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.sourceLocation.TAG).toBe("Ok");
		expect(action.sourceLocation._0).toBeUndefined();
	});

	it("resolves a React virtual context with one server request", async () => {
		const mockLoc = {
			componentName: "Button",
			tagName: "button",
			file: "src/Button.tsx",
			line: 42,
			column: 5,
			parent: undefined,
			componentProps: undefined,
		};
		const mockContext = {
			definition: {
				...mockLoc,
				file: "about://React/Server/file:///app/.next/server/chunk.js",
			},
			invocations: [],
		};
		getElementSourceLocation.mockImplementation(() =>
			Promise.resolve(mockContext),
		);
		resolveSourceLocation.mockImplementation(() =>
			Promise.resolve({ TAG: "Ok", _0: mockLoc }),
		);

		handleEffect(makeEffect({ contentWindow: {} }), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.sourceLocation.TAG).toBe("Ok");
		expect(action.sourceLocation._0).toBeDefined();
		expect(action.sourceLocation._0.file).toBe("src/Button.tsx");
		expect(action.sourceLocation._0.line).toBe(42);
		expect(resolveSourceLocation).toHaveBeenCalledTimes(1);
	});

	it("dispatches an error when a React Server location cannot be resolved", async () => {
		const mockContext = {
			definition: undefined,
			invocations: [
				{
					componentName: "ServerPost",
					tagName: "article",
					file: "about://React/Server/file:///app/.next/server/chunk.js",
					line: 1,
					column: 0,
					componentProps: undefined,
				},
			],
		};
		getElementSourceLocation.mockImplementation(() =>
			Promise.resolve(mockContext),
		);
		resolveSourceLocation.mockImplementation(() =>
			Promise.resolve({ TAG: "Error", _0: "HTTP 422: Unprocessable Entity" }),
		);

		handleEffect(makeEffect({ contentWindow: {} }), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.sourceLocation.TAG).toBe("Error");
		expect(action.sourceLocation._0).toBe("HTTP 422: Unprocessable Entity");
	});

	it("uses ordinary context without a server request", async () => {
		const mockContext = {
			definition: {
				componentName: "Counter",
				tagName: "button",
				file: "src/Counter.vue",
				line: 8,
				column: 1,
				componentProps: { initial: 1 },
			},
			invocations: [],
		};
		getElementSourceLocation.mockResolvedValue(mockContext);
		resolveSourceLocation.mockClear();

		handleEffect(makeEffect({ contentWindow: {} }), dispatch, delegate);
		await waitForDispatch(dispatched);

		expect(dispatched[0].sourceLocation).toMatchObject({
			TAG: "Ok",
			_0: {
				componentName: "Counter",
				file: "src/Counter.vue",
				parent: undefined,
			},
		});
		expect(resolveSourceLocation).not.toHaveBeenCalled();
	});

	it("times out source detection after five seconds", async () => {
		vi.useFakeTimers();
		getElementSourceLocation.mockImplementation(() => new Promise(() => {}));

		handleEffect(makeEffect({ contentWindow: {} }), dispatch, delegate);
		await vi.advanceTimersByTimeAsync(5000);

		expect(dispatched).toHaveLength(1);
		expect(dispatched[0].sourceLocation).toEqual({ TAG: "Ok", _0: undefined });
	});

	it.each([
		{
			name: "selector",
			arrange: () =>
				finder.mockImplementation(() => {
					throw new Error("No unique selector found");
				}),
			field: "selector",
			error: "No unique selector found",
		},
		{
			name: "screenshot capture",
			arrange: () => snapdom.mockRejectedValue(new Error("Canvas tainted")),
			field: "screenshot",
			error: "Canvas tainted",
		},
		{
			name: "screenshot encoding",
			arrange: () =>
				snapdom.mockResolvedValue({
					toJpg: () => Promise.reject(new Error("JPEG conversion failed")),
				}),
			field: "screenshot",
			error: "JPEG conversion failed",
		},
		{
			name: "source detection",
			arrange: () =>
				getElementSourceLocation.mockRejectedValue(
					new Error("CORS blocked source map"),
				),
			field: "sourceLocation",
			error: "CORS blocked source map",
			contentWindow: {},
		},
	])("preserves enrichment when $name fails", async ({
		arrange,
		field,
		error,
		contentWindow,
	}) => {
		arrange();
		handleEffect(makeEffect({ contentWindow }), dispatch, delegate);
		await waitForDispatch(dispatched);

		expect(dispatched[0].enrichmentStatus).toBe("Enriched");
		expect(dispatched[0][field]).toEqual({ TAG: "Error", _0: error });
		for (const unaffected of [
			"selector",
			"screenshot",
			"sourceLocation",
		].filter((candidate) => candidate !== field)) {
			expect(dispatched[0][unaffected].TAG).toBe("Ok");
		}
	});

	it("dispatches Failed status when source location resolver throws synchronously", async () => {
		const mockLoc = {
			componentName: "App",
			tagName: "div",
			file: "about://React/Server/file:///app/.next/server/chunk.js",
			line: 1,
			column: 1,
			parent: undefined,
			componentProps: undefined,
		};
		getElementSourceLocation.mockImplementation(() =>
			Promise.resolve({ definition: mockLoc, invocations: [] }),
		);
		resolveSourceLocation.mockImplementation(() => {
			throw new Error("Resolver exploded");
		});

		handleEffect(makeEffect({ contentWindow: {} }), dispatch, delegate);
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
