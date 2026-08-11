import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { afterEach, describe, expect, test } from "vitest";
import { make as ChatToggle } from "../src/Client__ChatToggle.res.mjs";

globalThis.IS_REACT_ACT_ENVIRONMENT = true;

let root;
let container;

afterEach(() => {
	act(() => root?.unmount());
	container?.remove();
});

describe("Client__ChatToggle interaction", () => {
	test("calls onToggle when clicked", async () => {
		container = document.createElement("div");
		document.body.append(container);
		root = createRoot(container);
		let toggleCount = 0;

		await act(async () => {
			root.render(
				React.createElement(ChatToggle, {
					chatOpen: true,
					onToggle: () => toggleCount++,
				}),
			);
		});

		await act(async () => {
			container.querySelector('button[aria-label="Close chat"]').click();
		});

		expect(toggleCount).toBe(1);
	});

	test("preserves keyboard focus when the state changes", async () => {
		let Harness = () => {
			let [chatOpen, setChatOpen] = React.useState(true);
			return React.createElement(ChatToggle, {
				chatOpen,
				onToggle: () => setChatOpen((open) => !open),
			});
		};
		container = document.createElement("div");
		document.body.append(container);
		root = createRoot(container);

		await act(async () => root.render(React.createElement(Harness)));
		let button = container.querySelector('button[aria-label="Close chat"]');
		button.focus();

		await act(async () => button.click());

		expect(container.querySelector('button[aria-label="Open chat"]')).toBe(
			button,
		);
		expect(document.activeElement).toBe(button);
	});
});
