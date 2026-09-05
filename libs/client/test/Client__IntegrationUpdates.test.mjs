import * as Sentry from "@frontman-ai/frontman-client/src/FrontmanClient__Sentry.res.mjs";
import { afterEach, expect, it, vi } from "vitest";
import {
	defaultState,
	handleEffect,
	next,
} from "../src/state/Client__State__StateReducer.res.mjs";

vi.mock(
	"@frontman-ai/frontman-client/src/FrontmanClient__Sentry.res.mjs",
	() => ({
		captureConnectionError: vi.fn(),
		captureException: vi.fn(),
	}),
);

afterEach(() => {
	vi.unstubAllGlobals();
	vi.clearAllMocks();
	delete window.__frontmanRuntime;
});

it("stops legacy WordPress update checks after a 404 without reporting an error", async () => {
	window.__frontmanRuntime = {
		framework: "wordpress",
		relayBaseUrl: "http://localhost:3000/index.php",
	};
	const fetch = vi.fn(async () => new Response("Not found", { status: 404 }));
	vi.stubGlobal("fetch", fetch);
	const check = {
		TAG: "CheckForUpdate",
		apiBaseUrl: "https://api.frontman.sh",
		installedVersion: "5.0.0",
		target: { TAG: "WordPressPlugin", _0: "frontman-agentic-ai-editor" },
	};
	const [, effects] = next(defaultState, check);
	const dispatch = vi.fn();
	handleEffect(effects[0], defaultState, dispatch);
	await vi.waitFor(() =>
		expect(dispatch).toHaveBeenCalledWith("WordPressUpdateUnsupported"),
	);
	const [state] = next(defaultState, dispatch.mock.calls[0][0]);

	expect(fetch).toHaveBeenCalledWith(
		"http://localhost:3000/index.php/frontman/plugin-update",
	);
	expect(state.wordpressUpdateUnsupported).toBe(true);
	expect(next(state, check)[1]).toEqual([]);
	expect(Sentry.captureConnectionError).not.toHaveBeenCalled();
	expect(Sentry.captureException).not.toHaveBeenCalled();
});

it.each([
	["WordPressPlugin", 500],
	["NpmPackage", 404],
])("still reports %s HTTP %s failures", async (target, status) => {
	window.__frontmanRuntime = {
		framework: "wordpress",
		relayBaseUrl: "http://localhost:3000",
	};
	vi.stubGlobal(
		"fetch",
		vi.fn(async () => new Response("Error", { status })),
	);
	const dispatch = vi.fn();
	handleEffect(
		{
			TAG: "CheckForUpdateEffect",
			apiBaseUrl: "https://api.frontman.sh",
			installedVersion: "5.0.0",
			target: { TAG: target, _0: "frontman" },
		},
		defaultState,
		dispatch,
	);
	await vi.waitFor(() =>
		expect(Sentry.captureConnectionError).toHaveBeenCalledOnce(),
	);
	expect(dispatch).not.toHaveBeenCalled();
	expect(Sentry.captureException).not.toHaveBeenCalled();
});
