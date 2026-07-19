import { JSDOM } from "jsdom";
import { describe, expect, it } from "vitest";
import { observeWindowLocation } from "../src/iframe-location-observer.mjs";

describe("observeWindowLocation", () => {
	it("reports SPA history changes and stops after cleanup", () => {
		const dom = new JSDOM("<!doctype html>", { url: "https://example.com/" });
		const locations = [];
		const cleanup = observeWindowLocation(dom.window, (location) =>
			locations.push(location),
		);

		dom.window.history.pushState({}, "", "/about/");
		dom.window.history.replaceState({}, "", "/docs/");
		dom.window.dispatchEvent(new dom.window.PopStateEvent("popstate"));
		dom.window.location.hash = "section";
		dom.window.dispatchEvent(new dom.window.HashChangeEvent("hashchange"));

		expect(locations).toEqual([
			"https://example.com/about/",
			"https://example.com/docs/",
			"https://example.com/docs/",
			"https://example.com/docs/#section",
		]);

		cleanup();
		dom.window.history.pushState({}, "", "/ignored/");
		expect(locations).toHaveLength(4);
		dom.window.close();
	});
});
