import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { expect, onTestFinished, test, vi } from "vitest";
import { make as PromptEditor } from "../src/components/frontman/Client__PromptEditor.res.mjs";

const mock = vi.hoisted(() => ({ options: null, editor: null }));
vi.mock("@tiptap/react", async (original) => ({
	...(await original()),
	useEditor: (options) => {
		mock.options = options;
		return mock.editor;
	},
	EditorContent: () => null,
}));
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

test("submission preserves rejected drafts and newer edits, without duplicate sends", async () => {
	let text = "Draft";
	const pending = Promise.withResolvers();
	const onSubmit = vi
		.fn()
		.mockResolvedValueOnce({ TAG: "Error", _0: "Rejected" })
		.mockReturnValueOnce(pending.promise)
		.mockResolvedValueOnce({ TAG: "Ok" });
	const commandsRef = React.createRef();
	const clearContent = vi.fn();
	const onFileSizeError = vi.fn();
	mock.editor = {
		getJSON: () => ({
			type: "doc",
			content: [{ type: "paragraph", content: [{ type: "text", text }] }],
		}),
		isEmpty: false,
		setEditable: vi.fn(),
		commands: { clearContent },
	};
	const container = document.body.appendChild(document.createElement("div"));
	const root = createRoot(container);
	onTestFinished(() => {
		act(() => root.unmount());
		expect(commandsRef.current).toBeNull();
		container.remove();
	});
	const props = {
		disabled: false,
		placeholder: "Prompt",
		isEnrichingAnnotations: false,
		hasAnnotations: false,
		commandsRef,
		onHasContentChange: vi.fn(),
		onSubmit,
		onPreviewImage: vi.fn(),
		onFileSizeError,
	};
	const render = (overrides = {}) =>
		act(async () =>
			root.render(
				React.createElement(PromptEditor, { ...props, ...overrides }),
			),
		);
	await render();
	const submit = () => commandsRef.current.submit();
	await act(async () => {
		submit();
		submit();
	});
	expect(onSubmit).toHaveBeenCalledTimes(1);
	expect(onFileSizeError).toHaveBeenCalledWith("Rejected");
	expect(clearContent).not.toHaveBeenCalled();
	await act(async () => {
		submit();
		text = "New draft";
		pending.resolve({ TAG: "Ok" });
	});
	expect(clearContent).not.toHaveBeenCalled();
	await act(async () => {
		submit();
	});
	expect(clearContent).toHaveBeenCalledTimes(1);
	const picker = vi.spyOn(
		container.querySelector('input[type="file"]'),
		"click",
	);
	const oversized = new File(["image"], "large.png", { type: "image/png" });
	Object.defineProperty(oversized, "size", { value: 11 * 1024 * 1024 });
	onFileSizeError.mockClear();
	for (const blocked of [
		{ disabled: true },
		{ isEnrichingAnnotations: true },
	]) {
		await render(blocked);
		await act(async () => {
			commandsRef.current.submit();
			commandsRef.current.attach();
			commandsRef.current.dropFiles([oversized]);
		});
		expect(onSubmit).toHaveBeenCalledTimes(3);
		expect(picker).not.toHaveBeenCalled();
		expect(onFileSizeError).not.toHaveBeenCalled();
	}
	await render();
	await act(async () => {
		commandsRef.current.attach();
		commandsRef.current.dropFiles([oversized]);
	});
	expect(picker).toHaveBeenCalledTimes(1);
	expect(onFileSizeError).toHaveBeenCalledWith("large.png exceeds 10MB limit");
});
