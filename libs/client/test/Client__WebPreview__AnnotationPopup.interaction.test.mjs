import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { afterEach, describe, expect, test } from "vitest";
import {
	make as PromptEditor,
	submit as submitPromptEditor,
} from "../src/components/frontman/Client__PromptEditor.res.mjs";
import { make as AnnotationPopup } from "../src/webpreview/Client__WebPreview__AnnotationPopup.res.mjs";

globalThis.IS_REACT_ACT_ENVIRONMENT = true;

let root;
let container;

afterEach(() => {
	act(() => root?.unmount());
	container?.remove();
});

const renderPopup = async () => {
	container = document.createElement("div");
	document.body.append(container);
	root = createRoot(container);
	const element = document.createElement("div");
	let executeCount = 0;
	let closeCount = 0;

	await act(async () => {
		root.render(
			React.createElement(AnnotationPopup, {
				annotation: { element, tagName: "div" },
				index: 0,
				scrollTimestamp: 0,
				mutationTimestamp: 0,
				onCommentChange: () => {},
				onClose: () => closeCount++,
				onExecute: () => executeCount++,
			}),
		);
	});

	return {
		input: container.querySelector("input"),
		executeButton: container.querySelector("button"),
		getExecuteCount: () => executeCount,
		getCloseCount: () => closeCount,
	};
};

describe("Client__WebPreview__AnnotationPopup interaction", () => {
	test("external submission uses active composer readiness", async () => {
		container = document.createElement("div");
		document.body.append(container);
		root = createRoot(container);
		let submitCount = 0;
		const renderEditor = (isEnrichingAnnotations) =>
			React.createElement(PromptEditor, {
				disabled: false,
				placeholder: "Prompt",
				isEnrichingAnnotations,
				hasAnnotations: true,
				submitSignal: 0,
				attachSignal: 0,
				dropFilesSignal: 0,
				droppedFiles: [],
				onHasContentChange: () => {},
				onSubmit: () => submitCount++,
				onPreviewImage: () => {},
				onFileSizeError: () => {},
			});

		await act(async () => root.render(renderEditor(false)));
		expect(submitPromptEditor()).toBe(true);
		expect(submitCount).toBe(1);

		await act(async () => root.render(renderEditor(true)));
		expect(submitPromptEditor()).toBe(false);
		expect(submitCount).toBe(1);

		act(() => root.unmount());
		root = undefined;
		expect(submitPromptEditor()).toBe(false);
	});

	test("executes from button and Cmd/Ctrl+Enter", async () => {
		const popup = await renderPopup();

		await act(async () => popup.executeButton.click());
		for (const modifier of [{ metaKey: true }, { ctrlKey: true }]) {
			await act(async () => {
				popup.input.dispatchEvent(
					new KeyboardEvent("keydown", {
						key: "Enter",
						...modifier,
						bubbles: true,
					}),
				);
			});
		}

		expect(popup.getExecuteCount()).toBe(3);
	});

	test("plain Enter and Escape close without executing", async () => {
		const popup = await renderPopup();

		for (const key of ["Enter", "Escape"]) {
			await act(async () => {
				popup.input.dispatchEvent(
					new KeyboardEvent("keydown", { key, bubbles: true }),
				);
			});
		}

		expect(popup.getCloseCount()).toBe(2);
		expect(popup.getExecuteCount()).toBe(0);
	});
});
