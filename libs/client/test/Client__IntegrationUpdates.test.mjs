import * as Sentry from "@frontman-ai/frontman-client/src/FrontmanClient__Sentry.res.mjs";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, expect, it, vi } from "vitest";
import { make as UpdateBanner } from "../src/components/frontman/Client__UpdateBanner.res.mjs";

const selectedState = vi.hoisted(() => ({ current: undefined }));
vi.mock("../src/state/Client__State.res.mjs", async (importOriginal) => ({
	...(await importOriginal()),
	useSelector: (selector) => selector(selectedState.current),
}));

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
		target: "WordPressPlugin",
	};
	const [, effects] = next(defaultState, check);
	const dispatch = vi.fn();
	handleEffect(effects[0], defaultState, dispatch);
	await vi.waitFor(() =>
		expect(dispatch).toHaveBeenCalledWith({
			TAG: "WordPressUpdatesChecked",
			_0: undefined,
		}),
	);
	const [state] = next(defaultState, dispatch.mock.calls[0][0]);

	expect(fetch).toHaveBeenCalledWith(
		"http://localhost:3000/index.php/frontman/plugin-update",
	);
	expect(state.wordpressUpdates).toBe("Unsupported");
	selectedState.current = state;
	expect(renderToStaticMarkup(createElement(UpdateBanner))).toBe("");
	expect(next(state, check)[1]).toEqual([]);
	expect(Sentry.captureConnectionError).not.toHaveBeenCalled();
	expect(Sentry.captureException).not.toHaveBeenCalled();
});

it("refreshes the auto-update nudge independently of version updates and dismissal", async () => {
	window.__frontmanRuntime = {
		framework: "wordpress",
		relayBaseUrl: "http://localhost:3000",
		wordpressPluginsUrl: "http://localhost:3000/wp-admin/network/plugins.php",
	};
	let state = { ...defaultState, updateBannerDismissed: true };
	for (const enabled of [false, true, false]) {
		vi.stubGlobal(
			"fetch",
			vi.fn(
				async () =>
					new Response(
						JSON.stringify({
							installedVersion: "5.0.0",
							latestVersion: "5.0.0",
							autoUpdateEnabled: enabled,
						}),
					),
			),
		);
		const dispatch = vi.fn((action) => {
			[state] = next(state, action);
		});
		handleEffect(
			{
				TAG: "CheckForUpdateEffect",
				apiBaseUrl: "https://api.frontman.sh",
				installedVersion: "5.0.0",
				target: "WordPressPlugin",
			},
			state,
			dispatch,
		);
		await vi.waitFor(() => expect(dispatch).toHaveBeenCalledOnce());
		expect(state.wordpressUpdates).toEqual({
			TAG: "Available",
			autoUpdateEnabled: enabled,
		});
		expect(state.updateInfo).toBeUndefined();
		selectedState.current = state;
		const markup = renderToStaticMarkup(createElement(UpdateBanner));
		if (enabled === false) {
			expect(markup).toContain("Enable auto-updates for Frontman");
			expect(markup).toContain(
				'href="http://localhost:3000/wp-admin/network/plugins.php"',
			);
		} else {
			expect(markup).toBe("");
		}
	}
	expect(Sentry.captureConnectionError).not.toHaveBeenCalled();
	expect(Sentry.captureException).not.toHaveBeenCalled();
});

it("reads npm registry versions without WordPress fields", async () => {
	vi.stubGlobal(
		"fetch",
		vi.fn(
			async () =>
				new Response(
					JSON.stringify({
						versions: { "@frontman-ai/nextjs": "5.1.0" },
					}),
				),
		),
	);
	const dispatch = vi.fn();
	const target = { TAG: "NpmPackage", _0: "@frontman-ai/nextjs" };
	handleEffect(
		{
			TAG: "CheckForUpdateEffect",
			apiBaseUrl: "https://api.frontman.sh",
			installedVersion: "5.0.0",
			target,
		},
		defaultState,
		dispatch,
	);
	await vi.waitFor(() =>
		expect(dispatch).toHaveBeenCalledWith({
			TAG: "UpdateInfoChecked",
			_0: { target, installedVersion: "5.0.0", latestVersion: "5.1.0" },
		}),
	);
	expect(Sentry.captureException).not.toHaveBeenCalled();
});

it("rejects a WordPress response without its required auto-update setting", async () => {
	window.__frontmanRuntime = {
		framework: "wordpress",
		relayBaseUrl: "http://localhost:3000",
	};
	vi.stubGlobal(
		"fetch",
		vi.fn(
			async () =>
				new Response(
					JSON.stringify({
						installedVersion: "5.0.0",
						latestVersion: "5.1.0",
					}),
				),
		),
	);
	const dispatch = vi.fn();
	handleEffect(
		{
			TAG: "CheckForUpdateEffect",
			apiBaseUrl: "https://api.frontman.sh",
			installedVersion: "5.0.0",
			target: "WordPressPlugin",
		},
		defaultState,
		dispatch,
	);
	await vi.waitFor(() =>
		expect(Sentry.captureException).toHaveBeenCalledOnce(),
	);
	expect(dispatch).not.toHaveBeenCalled();
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
			target:
				target === "WordPressPlugin" ? target : { TAG: target, _0: "frontman" },
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
