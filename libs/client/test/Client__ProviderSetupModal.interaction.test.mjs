import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { make as ProviderSetupModal } from "../src/Client__ProviderSetupModal.res.mjs";

globalThis.IS_REACT_ACT_ENVIRONMENT = true;

let root;
let container;
let trackedEvents;

beforeEach(() => {
	trackedEvents = [];
	window.__frontmanRuntime = { framework: "nextjs" };
	window.heap = {
		track: (name) => trackedEvents.push(name),
	};
});

afterEach(() => {
	act(() => root?.unmount());
	container?.remove();
	delete window.__frontmanRuntime;
	delete window.heap;
});

describe("Client__ProviderSetupModal", () => {
	test("renders provider setup as a modal", async () => {
		container = document.createElement("div");
		document.body.append(container);
		root = createRoot(container);

		await act(async () => {
			root.render(
				React.createElement(ProviderSetupModal, {
					open_: true,
					onOpenSettings: () => {},
				}),
			);
		});

		let dialog = document.querySelector('[data-slot="dialog-content"]');
		expect(dialog).not.toBeNull();
		expect(dialog.textContent).toContain(
			"One last step, then you're ready to build",
		);
		expect(dialog.textContent).toContain(
			"Frontman uses an AI provider to understand your requests and generate code.",
		);
		expect(dialog.textContent).toContain("Connect AI provider");
		expect(dialog.querySelector('[data-slot="dialog-close"]')).toBeNull();
	});

	test("opens provider settings from the primary action", async () => {
		container = document.createElement("div");
		document.body.append(container);
		root = createRoot(container);
		let openCount = 0;

		await act(async () => {
			root.render(
				React.createElement(ProviderSetupModal, {
					open_: true,
					onOpenSettings: () => openCount++,
				}),
			);
		});

		await act(async () => {
			[...document.querySelectorAll("button")]
				.find((button) => button.textContent.includes("Connect AI provider"))
				.click();
		});

		expect(openCount).toBe(1);
	});

	test("stays open when Escape is pressed", async () => {
		container = document.createElement("div");
		document.body.append(container);
		root = createRoot(container);

		await act(async () => {
			root.render(
				React.createElement(ProviderSetupModal, {
					open_: true,
					onOpenSettings: () => {},
				}),
			);
		});

		await act(async () => {
			document.dispatchEvent(
				new KeyboardEvent("keydown", { key: "Escape", bubbles: true }),
			);
		});

		expect(
			document.querySelector('[data-slot="dialog-content"]'),
		).not.toBeNull();
	});

	test("tracks each hidden-to-visible transition once", async () => {
		container = document.createElement("div");
		document.body.append(container);
		root = createRoot(container);
		const modal = (open_) =>
			React.createElement(
				React.StrictMode,
				null,
				React.createElement(ProviderSetupModal, {
					open_,
					onOpenSettings: () => {},
				}),
			);
		const render = (open_) => act(async () => root.render(modal(open_)));

		await render(false);
		await render(true);
		await render(true);

		expect(trackedEvents).toEqual(["provider_setup_blocker_shown"]);

		await render(false);
		await render(true);

		expect(trackedEvents).toHaveLength(2);
	});
});
