import { beforeEach, describe, expect, it, vi } from "vitest";
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
	return {
		tagName: "BUTTON",
		getAttribute: () => "btn-submit primary",
		closest: () => null,
		textContent: "Submit",
		getBoundingClientRect: () => ({
			left: 10,
			top: 20,
			width: 100,
			height: 40,
		}),
	};
}

function makeMockDocument() {
	return {
		documentElement: {},
		querySelector: () => null,
	};
}

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

	it("captures cssClasses, nearbyText, and boundingBox synchronously", async () => {
		handleEffect(makeEffect(), dispatch, delegate);
		await waitForDispatch(dispatched);

		const action = dispatched[0];
		expect(action.cssClasses).toBe("btn-submit primary");
		expect(action.nearbyText).toBe("Submit");
		expect(action.boundingBox.x).toBe(10);
		expect(action.boundingBox.y).toBe(20);
		expect(action.boundingBox.width).toBe(100);
		expect(action.boundingBox.height).toBe(40);
	});
});
