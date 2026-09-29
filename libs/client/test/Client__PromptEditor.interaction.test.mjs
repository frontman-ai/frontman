import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { afterEach, expect, test, vi } from "vitest";
import { make as PromptEditor } from "../src/components/frontman/Client__PromptEditor.res.mjs";

globalThis.IS_REACT_ACT_ENVIRONMENT = true;
let root;
let container;

afterEach(() => {
	act(() => root?.unmount());
	root = undefined;
	container?.remove();
});

test("editor commands run directly, respect current guards, and clear on unmount", async () => {
	container = document.createElement("div");
	document.body.append(container);
	root = createRoot(container);
	const commandsRef = React.createRef();
	const onSubmit = vi.fn();
	const onFileSizeError = vi.fn();
	const props = {
		commandsRef,
		disabled: false,
		isEnrichingAnnotations: false,
		hasAnnotations: false,
		placeholder: "Prompt",
		onHasContentChange: vi.fn(),
		onSubmit,
		onPreviewImage: vi.fn(),
		onFileSizeError,
	};
	const render = async (overrides = {}) => {
		await act(async () =>
			root.render(
				React.createElement(PromptEditor, { ...props, ...overrides }),
			),
		);
	};
	await render();
	const editor = container.querySelector('[role="textbox"]').editor;
	const picker = vi.spyOn(
		container.querySelector('input[type="file"]'),
		"click",
	);
	const oversized = new File(["image"], "large.png", { type: "image/png" });
	Object.defineProperty(oversized, "size", { value: 11 * 1024 * 1024 });

	for (const blocked of [
		{ disabled: true },
		{ isEnrichingAnnotations: true },
	]) {
		await act(async () => editor.commands.setContent("Keep this draft"));
		await render(blocked);
		await act(async () => {
			commandsRef.current.submit();
			commandsRef.current.attach();
			commandsRef.current.dropFiles([oversized]);
		});
		expect(onSubmit).not.toHaveBeenCalled();
		expect(picker).not.toHaveBeenCalled();
		expect(onFileSizeError).not.toHaveBeenCalled();
		expect(editor.getText()).toBe("Keep this draft");
	}

	await render();
	await act(async () => {
		commandsRef.current.attach();
		commandsRef.current.dropFiles([oversized]);
		commandsRef.current.submit();
		commandsRef.current.submit();
	});
	expect(picker).toHaveBeenCalledTimes(1);
	expect(onFileSizeError).toHaveBeenCalledWith("large.png exceeds 10MB limit");
	expect(onSubmit).toHaveBeenCalledExactlyOnceWith("Keep this draft", []);
	expect(editor.isEmpty).toBe(true);
	await act(async () => editor.commands.setContent("Second prompt"));
	await act(async () => commandsRef.current.submit());
	expect(onSubmit).toHaveBeenLastCalledWith("Second prompt", []);

	await act(async () => root.unmount());
	root = undefined;
	expect(commandsRef.current).toBeNull();
});
