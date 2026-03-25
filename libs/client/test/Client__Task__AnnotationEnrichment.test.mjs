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
import { handleEffect } from "../src/state/Client__Task__Reducer.res.mjs";

// ============================================================================
// Mocks — stub the three async dependencies
// ============================================================================

// @medv/finder
vi.mock("@medv/finder", () => ({
	finder: vi.fn(() => "button.submit"),
}));

// @zumer/snapdom
vi.mock("@zumer/snapdom", () => ({
	snapdom: vi.fn(() =>
		Promise.resolve({
			toJpg: () => Promise.resolve({ src: "data:image/jpeg;base64,abc123" }),
		}),
	),
}));

// Source detection — the compiled module path
vi.mock("../src/Client__SourceDetection.res.mjs", () => ({
	getElementSourceLocation: vi.fn(() => Promise.resolve(undefined)),
}));

// Source location resolver — skip server resolution
vi.mock("../src/Client__SourceLocationResolver.res.mjs", () => ({
	resolve: vi.fn((loc) => Promise.resolve({ TAG: "Ok", _0: loc })),
}));

// Image limits — return simple values
vi.mock("../src/utils/Client__ImageLimits.res.mjs", () => ({
	conservative: { maxDimension: 7680, quality: 0.8 },
	computeScale: () => 1.0,
}));

// Import mocked modules so we can reconfigure per-test
import { finder } from "@medv/finder";
import { snapdom } from "@zumer/snapdom";
import { getElementSourceLocation } from "../src/Client__SourceDetection.res.mjs";
import { resolve as resolveSourceLocation } from "../src/Client__SourceLocationResolver.res.mjs";

// ============================================================================
// Test helpers
// ============================================================================

/** Create a minimal mock DOM element that satisfies the sync enrichment reads */
function makeMockElement() {
	return {
		tagName: "BUTTON",
		getAttribute: () => "btn-submit primary",
		// WebAPI.Element.asNode -> textContent
		textContent: "Submit",
		// getBoundingClientRect
		getBoundingClientRect: () => ({
			left: 10,
			top: 20,
			width: 100,
			height: 40,
		}),
	};
}

/** Create the FetchAnnotationDetails effect object matching ReScript's compiled shape */
function makeEffect(overrides = {}) {
	return {
		TAG: "FetchAnnotationDetails",
		id: "ann-test-1",
		element: makeMockElement(),
		document: undefined,
		contentWindow: undefined, // None → source detection gets Ok(None)
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

// ============================================================================
// Tests
// ============================================================================

describe("FetchAnnotationDetails effect handler", () => {
	let dispatched;
	let dispatch;
	let delegate;

	beforeEach(() => {
		dispatched = [];
		dispatch = (action) => dispatched.push(action);
		delegate = () => {};
		vi.restoreAllMocks();

		// Reset to happy-path defaults
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

	// ============================================================================
	// Happy path
	// ============================================================================

	it("dispatches AnnotationDetailsResolved with Enriched when all promises succeed", async () => {
		handleEffect(makeEffect(), dispatch, delegate);
		await waitForDispatch(dispatched);

		expect(dispatched).toHaveLength(1);
		const action = dispatched[0];
		expect(action.TAG).toBe("AnnotationDetailsResolved");
		expect(action.enrichmentStatus).toBe("Enriched");
		// selector: Ok(Some("button.submit"))
		expect(action.selector.TAG).toBe("Ok");
		expect(action.selector._0).toBe("button.submit");
		// screenshot: Ok(Some("data:image/jpeg;base64,abc123"))
		expect(action.screenshot.TAG).toBe("Ok");
		expect(action.screenshot._0).toBe("data:image/jpeg;base64,abc123");
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

		// Provide a contentWindow so source detection runs
		const mockWindow = {};
		handleEffect(makeEffect({ contentWindow: mockWindow }), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.sourceLocation.TAG).toBe("Ok");
		expect(action.sourceLocation._0).toBeDefined();
		expect(action.sourceLocation._0.file).toBe("src/Button.tsx");
		expect(action.sourceLocation._0.line).toBe(42);
	});

	// ============================================================================
	// Partial failures — individual sub-promise errors, status still Enriched
	// ============================================================================

	it("selector Error when finder throws", async () => {
		finder.mockImplementation(() => {
			throw new Error("No unique selector found");
		});

		handleEffect(makeEffect(), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.TAG).toBe("AnnotationDetailsResolved");
		expect(action.enrichmentStatus).toBe("Enriched");
		// selector should be Error
		expect(action.selector.TAG).toBe("Error");
		expect(action.selector._0).toBe("No unique selector found");
		// screenshot should still be Ok
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
		// selector should still be Ok
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

	// ============================================================================
	// Outer chain failure → Failed status
	// ============================================================================

	it("dispatches Failed status when source location resolver throws synchronously", async () => {
		// Make source detection succeed so we enter the resolver path
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
		// Make resolver throw (not reject — throw synchronously inside .then)
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
		// All three async fields should be Error
		expect(action.selector.TAG).toBe("Error");
		expect(action.screenshot.TAG).toBe("Error");
		expect(action.sourceLocation.TAG).toBe("Error");
	});

	// ============================================================================
	// Sync enrichment fields are always captured
	// ============================================================================

	it("captures cssClasses, nearbyText, and boundingBox synchronously", async () => {
		handleEffect(makeEffect(), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		// cssClasses extracted from getAttribute("class")
		expect(action.cssClasses).toBe("btn-submit primary");
		// nearbyText from textContent
		expect(action.nearbyText).toBe("Submit");
		// boundingBox from getBoundingClientRect
		expect(action.boundingBox.x).toBe(10);
		expect(action.boundingBox.y).toBe(20);
		expect(action.boundingBox.width).toBe(100);
		expect(action.boundingBox.height).toBe(40);
	});
});
