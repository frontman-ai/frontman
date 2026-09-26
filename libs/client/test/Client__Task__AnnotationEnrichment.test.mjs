import { finder } from "@medv/finder";
import { snapdom } from "@zumer/snapdom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { getElementSourceLocation } from "../src/Client__SourceDetection.res.mjs";
import { resolve as resolveSourceLocation } from "../src/Client__SourceLocationResolver.res.mjs";
import * as Reducer from "../src/state/Client__State__StateReducer.res.mjs";

vi.mock("@medv/finder", () => ({ finder: vi.fn(() => "button.submit") }));
vi.mock("@zumer/snapdom", () => ({
	snapdom: vi.fn(async () => ({
		toJpg: async () => ({ src: "data:image/jpeg;base64,abc123" }),
	})),
}));
vi.mock("../src/Client__SourceDetection.res.mjs", () => ({
	getElementSourceLocation: vi.fn(async () => undefined),
}));
vi.mock("../src/Client__SourceLocationResolver.res.mjs", () => ({
	resolve: vi.fn(async (loc) => ({ TAG: "Ok", _0: loc })),
}));

const virtualLocation = {
	file: "about://React/Server/file:///app/.next/server/chunk.js",
	line: 1,
	column: 0,
};
const virtualContext = {
	definition: undefined,
	invocations: [virtualLocation],
};
const target = { TAG: "ForTask", _0: "task-1" };
let dispatch;
beforeEach(() => {
	vi.resetAllMocks();
	dispatch = vi.fn();
	window.__frontmanRuntime = { framework: "nextjs" };
	document.body.innerHTML = `
		<div id="form-actions">
			<button id="submit" class="btn-submit primary">
				Submit "now"
				<span class="button-overlay"></span>
			</button>
		</div>
	`;
	document.querySelector("#submit").getBoundingClientRect = () => ({
		left: 10,
		top: 20,
		width: 100,
		height: 40,
	});
});
afterEach(() => {
	vi.useRealTimers();
	delete window.__frontmanRuntime;
});
function start(overrides = {}) {
	Reducer.handleEffect(
		{
			TAG: "TaskEffect",
			target,
			effect: {
				TAG: "FetchAnnotationDetails",
				id: "ann-test-1",
				element: document.querySelector("#submit"),
				document,
				contentWindow: undefined,
				...overrides,
			},
		},
		Reducer.defaultState,
		(event) => {
			expect(event.target).toEqual(target);
			dispatch(event.action);
		},
	);
}
async function enrich(overrides) {
	start(overrides);
	await vi.waitFor(() => expect(dispatch).toHaveBeenCalledOnce());
	return dispatch.mock.calls[0][0];
}

describe("FetchAnnotationDetails effect handler", () => {
	it("dispatches successful enrichment and absent source without a window", async () => {
		const action = await enrich();
		expect(action).toMatchObject({
			TAG: "AnnotationDetailsResolved",
			enrichmentStatus: "Enriched",
			selector: { TAG: "Ok", _0: "button.submit" },
			screenshot: { TAG: "Ok", _0: "data:image/jpeg;base64,abc123" },
			elementContext: { TAG: "Ok" },
			sourceLocation: { TAG: "Ok" },
		});
		expect(action.elementContext._0).toContain('selected tag="button"');
		expect(action.sourceLocation._0).toBeUndefined();
	});
	it.each(["astro", "nextjs", "vite", "wordpress"])(
		"scopes persistence markers for %s",
		async (framework) => {
			window.__frontmanRuntime = { framework };
			document
				.querySelector("#submit")
				.setAttribute("data-astro-transition-persist", "submit-action");
			const { elementContext } = await enrich();
			expect(elementContext.TAG).toBe("Ok");
			expect(
				elementContext._0.includes(
					'data-astro-transition-persist="submit-action"',
				),
			).toBe(framework === "astro");
		},
	);
	it("resolves a React virtual definition with one server request", async () => {
		const location = {
			componentName: "Button",
			tagName: "button",
			file: "src/Button.tsx",
			line: 42,
			column: 5,
		};
		getElementSourceLocation.mockResolvedValue({
			definition: { ...location, file: virtualLocation.file },
			invocations: [],
		});
		resolveSourceLocation.mockResolvedValue({ TAG: "Ok", _0: location });
		const action = await enrich({ contentWindow: {} });
		expect(action.sourceLocation).toMatchObject({
			TAG: "Ok",
			_0: { file: "src/Button.tsx", line: 42 },
		});
		expect(resolveSourceLocation).toHaveBeenCalledTimes(1);
	});
	it("dispatches an error when a React Server location cannot be resolved", async () => {
		getElementSourceLocation.mockResolvedValue(virtualContext);
		resolveSourceLocation.mockResolvedValue({
			TAG: "Error",
			_0: "HTTP 422: Unprocessable Entity",
		});
		const action = await enrich({ contentWindow: {} });
		expect(action.sourceLocation).toEqual({
			TAG: "Error",
			_0: "HTTP 422: Unprocessable Entity",
		});
	});
	it("uses ordinary context without a server request", async () => {
		getElementSourceLocation.mockResolvedValue({
			definition: {
				componentName: "Counter",
				tagName: "button",
				file: "src/Counter.vue",
				line: 8,
				column: 1,
				componentProps: { initial: 1 },
			},
			invocations: [],
		});
		const action = await enrich({ contentWindow: {} });
		expect(action.sourceLocation).toMatchObject({
			TAG: "Ok",
			_0: {
				componentName: "Counter",
				file: "src/Counter.vue",
				parent: undefined,
			},
		});
		expect(resolveSourceLocation).not.toHaveBeenCalled();
	});
	it.each(["detection", "resolution"])(
		"times out source %s after five seconds",
		async (stage) => {
			vi.useFakeTimers();
			getElementSourceLocation.mockResolvedValue(virtualContext);
			(stage === "detection"
				? getElementSourceLocation
				: resolveSourceLocation
			).mockImplementation(() => new Promise(() => {}));
			start({ contentWindow: {} });
			await vi.advanceTimersByTimeAsync(5000);
			expect(dispatch).toHaveBeenCalledOnce();
			expect(dispatch.mock.calls[0][0].sourceLocation).toEqual({
				TAG: "Error",
				_0: "Source location detection or resolution timed out",
			});
		},
	);
	it.each([
		{
			name: "selector",
			field: "selector",
			error: "No unique selector found",
			arrange: () =>
				finder.mockImplementation(() => {
					throw new Error("No unique selector found");
				}),
		},
		{
			name: "screenshot capture",
			field: "screenshot",
			error: "Canvas tainted",
			arrange: () => snapdom.mockRejectedValue(new Error("Canvas tainted")),
		},
		{
			name: "screenshot encoding",
			field: "screenshot",
			error: "JPEG conversion failed",
			arrange: () =>
				snapdom.mockResolvedValue({
					toJpg: async () => {
						throw new Error("JPEG conversion failed");
					},
				}),
		},
		{
			name: "source detection",
			field: "sourceLocation",
			error: "CORS blocked source map",
			contentWindow: {},
			arrange: () =>
				getElementSourceLocation.mockRejectedValue(
					new Error("CORS blocked source map"),
				),
		},
	])(
		"preserves enrichment when $name fails",
		async ({ arrange, field, error, contentWindow }) => {
			arrange();
			const action = await enrich({ contentWindow });
			expect(action.enrichmentStatus).toBe("Enriched");
			expect(action[field]).toEqual({ TAG: "Error", _0: error });
			for (const unaffected of [
				"selector",
				"screenshot",
				"sourceLocation",
			].filter((candidate) => candidate !== field)) {
				expect(action[unaffected].TAG).toBe("Ok");
			}
		},
	);
	it("isolates a synchronous source resolver failure", async () => {
		getElementSourceLocation.mockResolvedValue({
			definition: {
				...virtualLocation,
				componentName: "App",
				tagName: "div",
				column: 1,
			},
			invocations: [],
		});
		resolveSourceLocation.mockImplementation(() => {
			throw new Error("Resolver exploded");
		});
		const action = await enrich({ contentWindow: {} });
		expect(action).toMatchObject({
			TAG: "AnnotationDetailsResolved",
			enrichmentStatus: "Enriched",
			sourceLocation: { TAG: "Error", _0: "Resolver exploded" },
			selector: { TAG: "Ok" },
			screenshot: { TAG: "Ok" },
		});
	});
});
